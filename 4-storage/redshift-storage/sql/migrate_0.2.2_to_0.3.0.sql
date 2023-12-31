-- Copyright (c) 2013-2022 Snowplow Analytics Ltd. All rights reserved.
--
-- This program is licensed to you under the Apache License Version 2.0,
-- and you may not use this file except in compliance with the Apache License Version 2.0.
-- You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
--
-- Unless required by applicable law or agreed to in writing,
-- software distributed under the Apache License Version 2.0 is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.
--
-- Version:     Ports version 0.2.2 to version 0.3.0
-- URL:         -
--
-- Authors:     Alex Dean
-- Copyright:   Copyright (c) 2014-2022 Snowplow Analytics Ltd
-- License:     Apache License Version 2.0

-- First rename the existing table (don't delete it)
ALTER TABLE atomic.events RENAME TO events_022;

-- Create new events table
CREATE TABLE atomic.events (
	-- App
	app_id varchar(255) encode text255,
	platform varchar(255) encode text255,
	-- Date/time
	collector_tstamp timestamp not null,
	dvce_tstamp timestamp,
	-- Event
	event varchar(128) encode text255,
	event_vendor varchar(128) encode text32k,          -- Removed not null constraint in 0.3.0
	event_id char(36) not null unique,                 -- Changed from varchar(38) in 0.3.0
	txn_id int,
	-- Namespacing and versioning
	name_tracker varchar(128) encode text255,          -- Added in 0.3.0
	v_tracker varchar(100) encode text255,
	v_collector varchar(100) encode text255 not null,
	v_etl varchar(100) encode text255 not null,
	-- User and visit
	user_id varchar(255) encode runlength,
	user_ipaddress varchar(19) encode runlength,
	user_fingerprint varchar(50) encode runlength,
	domain_userid varchar(16),
	domain_sessionidx smallint,
	network_userid varchar(38),
	-- Location
	geo_country char(2),
	geo_region char(2),
	geo_city varchar(75),
	geo_zipcode varchar(15),
	geo_latitude double precision,
	geo_longitude double precision,
	-- Page
	page_url varchar(4096),                            -- Added in 0.3.0
	page_title varchar(2000),
	page_referrer varchar(4096),                       -- Added in 0.3.0
	-- Page URL components
	page_urlscheme varchar(16) encode text255,
	page_urlhost varchar(255) encode text255,
	page_urlport int,
	page_urlpath varchar(1000) encode text32k,
	page_urlquery varchar(3000),
	page_urlfragment varchar(255),
	-- Referrer URL components
	refr_urlscheme varchar(16) encode text255,
	refr_urlhost varchar(255) encode text255,
	refr_urlport int,
	refr_urlpath varchar(1000) encode text32k,
	refr_urlquery varchar(3000),
	refr_urlfragment varchar(255),
	-- Referrer details
	refr_medium varchar(25) encode text255,
	refr_source varchar(50) encode text255,
	refr_term varchar(255) encode raw,
	-- Marketing
	mkt_medium varchar(255) encode text255,
	mkt_source varchar(255) encode text255,
	mkt_term varchar(255) encode raw,
	mkt_content varchar(500) encode raw,
	mkt_campaign varchar(255) encode text32k,
	-- Custom contexts
	contexts varchar(10000) encode raw,                -- Added in 0.3.0
	-- Custom structured event
	se_category varchar(255) encode text255,
	se_action varchar(255) encode text255,
	se_label varchar(255) encode text32k,
	se_property varchar(255) encode text32k,
	se_value double precision,
	-- Custom unstructured event
	ue_name varchar(255) encode text255,               -- Added in 0.3.0
	ue_properties varchar(10000) encode raw,           -- Added in 0.3.0
	-- Ecommerce
	tr_orderid varchar(255) encode raw,
	tr_affiliation varchar(255) encode text255,
	tr_total dec(18,2),
	tr_tax dec(18,2),
	tr_shipping dec(18,2),
	tr_city varchar(255) encode text32k,
	tr_state varchar(255) encode text32k,
	tr_country varchar(255) encode text32k,
	ti_orderid varchar(255) encode raw,
	ti_sku varchar(255) encode text32k,
	ti_name varchar(255) encode text32k,
	ti_category varchar(255) encode text255,
	ti_price dec(18,2),
	ti_quantity int,
	-- Page ping
	pp_xoffset_min integer,
	pp_xoffset_max integer,
	pp_yoffset_min integer,
	pp_yoffset_max integer,
	-- User Agent
	useragent varchar(1000) encode text32k,
	-- Browser
	br_name varchar(50) encode text255,
	br_family varchar(50) encode text255,
	br_version varchar(50) encode text255,
	br_type varchar(50) encode text255,
	br_renderengine varchar(50) encode text255,
	br_lang varchar(255) encode text255,
	br_features_pdf boolean,
	br_features_flash boolean,
	br_features_java boolean,
	br_features_director boolean,
	br_features_quicktime boolean,
	br_features_realplayer boolean,
	br_features_windowsmedia boolean,
	br_features_gears boolean ,
	br_features_silverlight boolean,
	br_cookies boolean,
	br_colordepth varchar(12) encode text255,
	br_viewwidth integer,
	br_viewheight integer,
	-- Operating System
	os_name varchar(50) encode text255,
	os_family varchar(50)  encode text255,
	os_manufacturer varchar(50)  encode text255,
	os_timezone varchar(255)  encode text255,
	-- Device/Hardware
	dvce_type varchar(50)  encode text255,
	dvce_ismobile boolean,
	dvce_screenwidth integer,
	dvce_screenheight integer,
	-- Document
	doc_charset varchar(128) encode text255,
	doc_width integer,
	doc_height integer,
	CONSTRAINT event_id_030_pk PRIMARY KEY(event_id)   -- Made constraint version-specific in 0.3.0
)
DISTSTYLE KEY
DISTKEY (event_id)                                     -- Changed from domain_userid in 0.3.0
SORTKEY (collector_tstamp);

-- Now copy into new from events_old
INSERT INTO atomic.events
	SELECT
	app_id,
	platform,
	collector_tstamp,
	dvce_tstamp,
	event,
	event_vendor,
	event_id,                                          -- Changed from varchar(38) in 0.2.0
	txn_id,
	NULL AS name_tracker,                              --  Added in 0.2.0
	v_tracker,
	v_collector,
	v_etl,
	user_id,
	user_ipaddress,
	user_fingerprint,
	domain_userid,
	domain_sessionidx,
	network_userid,
	geo_country,
	geo_region,
	geo_city,
	geo_zipcode,
	geo_latitude,
	geo_longitude,
	NULL AS page_url,                                  -- Added in 0.2.0
	page_title,
	NULL AS page_referrer,                             -- Added in 0.2.0
	page_urlscheme,
	page_urlhost,
	page_urlport,
	page_urlpath,
	page_urlquery,
	page_urlfragment,
	refr_urlscheme,
	refr_urlhost,
	refr_urlport,
	refr_urlpath,
	refr_urlquery,
	refr_urlfragment,
	refr_medium,
	refr_source,
	refr_term,
	mkt_medium,
	mkt_source,
	mkt_term,
	mkt_content,
	mkt_campaign,
	NULL AS contexts,                                  -- Added in 0.2.0
	se_category,
	se_action,
	se_label,
	se_property,
	se_value,
	NULL AS ue_name,                                   -- Added in 0.2.0
	NULL AS ue_properties,                             -- Added in 0.2.0
	tr_orderid,
	tr_affiliation,
	tr_total,
	tr_tax,
	tr_shipping,
	tr_city,
	tr_state,
	tr_country,
	ti_orderid,
	ti_sku,
	ti_name,
	ti_category,
	ti_price,
	ti_quantity,
	pp_xoffset_min,
	pp_xoffset_max,
	pp_yoffset_min,
	pp_yoffset_max,
	useragent,
	br_name,
	br_family,
	br_version,
	br_type,
	br_renderengine,
	br_lang,
	br_features_pdf,
	br_features_flash,
	br_features_java,
	br_features_director,
	br_features_quicktime,
	br_features_realplayer,
	br_features_windowsmedia,
	br_features_gears,
	br_features_silverlight,
	br_cookies,
	br_colordepth,
	br_viewwidth,
	br_viewheight,
	os_name,
	os_family,
	os_manufacturer,
	os_timezone,
	dvce_type,
	dvce_ismobile,
	dvce_screenwidth,
	dvce_screenheight,
	doc_charset,
	doc_width,
	doc_height
	FROM atomic.events_022;
