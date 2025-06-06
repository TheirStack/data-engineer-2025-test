
CREATE TABLE data_provider
(
    id UInt32,
    name String NOT NULL
) ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 8192;


CREATE TABLE company_data_origin
(
    id UInt32,
    data_provider_id UInt32 NOT NULL,
    name String NOT NULL
) ENGINE = MergeTree()
ORDER BY (data_provider_id, id)
SETTINGS index_granularity = 8192;


CREATE TABLE industry_mapping
(
    industry_id Nullable(UInt32),
    data_provider_id UInt32 NOT NULL,
    data_provider_industry_id String NOT NULL,
    data_provider_industry_name String NOT NULL,
    data_provider_hierarchy Nullable(String),
    data_provider_description Nullable(String),
    mapping_reason Nullable(String)
) ENGINE = MergeTree()
ORDER BY (data_provider_id, data_provider_industry_id)
SETTINGS index_granularity = 8192;

CREATE TABLE company_landing
(
    data_provider_origin_id UInt32,
    data_provider_company_id String,
    name String,
    domain Nullable(String),
    linkedin_slug Nullable(String),
    info String, -- JSON stored as String in ClickHouse
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    host Nullable(String),
    url Nullable(String)
) ENGINE = MergeTree()
ORDER BY (name)
