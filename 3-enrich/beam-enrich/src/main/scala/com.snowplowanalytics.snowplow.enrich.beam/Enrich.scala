package com.snowplowanalytics
package snowplow
package enrich
package beam

import java.nio.charset.StandardCharsets.UTF_8

import com.spotify.scio._
import com.spotify.scio.values.SCollection
import org.apache.commons.codec.binary.Base64
import org.joda.time.DateTime
import org.slf4j.LoggerFactory
import scalaz._
import Scalaz._

import common.EtlPipeline
import common.enrichments.EnrichmentRegistry
import common.loaders.ThriftLoader
import common.outputs.{EnrichedEvent, BadRow}
import config._
import utils._
import iglu.client.Resolver

/*
sbt "runMain com.snowplowanalytics.snowplow.enrich.beam.Enrich
  --project=[PROJECT] --runner=DataflowRunner --zone=[ZONE] --streaming=true
  --input=[INPUT TOPIC]
  --output=[OUTPUT TOPIC]
  --bad=[BAD TOPIC]
  --resolver=[RESOLVER FILE PATH]
  --enrichments=[ENRICHMENTS DIR PATH]"
*/
object Enrich {

  private val logger = LoggerFactory.getLogger(this.getClass)
  // the maximum record size in Google PubSub is 10Mb
  private val MaxRecordSize = 10000000

  implicit def enrichSCollection[T](collection: SCollection[T]) = new RichSCollection[T](collection)

  def main(cmdlineArgs: Array[String]): Unit = {
    val (sc, args) = ContextAndArgs(cmdlineArgs)
    val parsedConfig = for {
      config <- EnrichConfig(args)
      resolver <- parseResolver(config.resolver)
      enrichmentRegistry <- parseEnrichmentRegistry(config.enrichments)(resolver)
    } yield ParsedEnrichConfig(config.input, config.output, config.bad, resolver, enrichmentRegistry)

    parsedConfig match {
      case Failure(e) =>
        System.err.println(s"An error occured: $e")
        System.exit(1)
      case Success(config) =>
        run(sc, config)
        sc.close()
    }
  }

  def run(sc: ScioContext, config: ParsedEnrichConfig): Unit = {
    implicit val resolver = config.resolver

    val input: SCollection[Array[Byte]] = sc.pubsubTopic(config.input).withName("input")
    val enriched: SCollection[Validation[BadRow, EnrichedEvent]] = input
      .map(enrich(_, config.enrichmentRegistry))
      .flatten
      .withName("enriched")

    val (successes, failures) = enriched.partition2(_.isSuccess)
    val (tooBigSuccesses, properlySizedsuccesses) = successes
      .collect { case Success(enrichedEvent) =>
        val formattedEnrichedEvent = tabSeparatedEnrichedEvent(enrichedEvent)
        (formattedEnrichedEvent, getStringSize(formattedEnrichedEvent))
      }
      .partition2(_._2 >= MaxRecordSize)
    properlySizedsuccesses.map(_._1).withName("enriched-good").saveAsPubsub(config.output)

    val failureCollection: SCollection[BadRow] =
      failures.collect { case Failure(badRow) => resizeBadRow(badRow, MaxRecordSize) } ++
      tooBigSuccesses.map { case (event, size) => resizeEnrichedEvent(event, size, MaxRecordSize) }
    failureCollection.map(_.toCompactJson).withName("enriched-bad").saveAsPubsub(config.bad)
  }

  def enrich(data: Array[Byte], enrichmentRegistry: EnrichmentRegistry)(
      implicit r: Resolver): List[Validation[BadRow, EnrichedEvent]] = {
    val collectorPayload = ThriftLoader.toCollectorPayload(data)
    val processedEvents = EtlPipeline.processEvents(
      enrichmentRegistry,
      s"beam-enrich-${generated.BuildInfo.version}",
      new DateTime(System.currentTimeMillis),
      collectorPayload
    )
    processedEvents.map {
      case Success(enrichedEvent) => enrichedEvent.success
      case Failure(errors) =>
        val line = new String(Base64.encodeBase64(data), UTF_8)
        BadRow(line, errors).failure
    }
  }
}
