-- ClickHouse DDL for migrated PostgreSQL tables with S3 data loading
-- Note: ClickHouse doesn't support foreign key constraints, sequences, or traditional ACID transactions

-- Data Provider Table
CREATE TABLE data_provider
(
    id UInt32,
    name String NOT NULL
) ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 8192;

-- Company Data Origin Table
CREATE TABLE company_data_origin
(
    id UInt32,
    data_provider_id UInt32 NOT NULL,
    name String NOT NULL
) ENGINE = MergeTree()
ORDER BY (data_provider_id, id)
SETTINGS index_granularity = 8192;

-- Company Landing Table
CREATE TABLE company_landing
(
    id UInt32,
    data_provider_origin_id UInt32 NOT NULL,
    data_provider_company_id String NOT NULL,
    name String NOT NULL,
    domain Nullable(String),
    linkedin_slug Nullable(String),
    info String, -- JSON stored as String in ClickHouse
    created_at DateTime DEFAULT now(),
    updated_at DateTime DEFAULT now(),
    host Nullable(String),
    url Nullable(String)
) ENGINE = MergeTree()
ORDER BY (data_provider_origin_id, id)
SETTINGS index_granularity = 8192;

-- Industry Mapping Table
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

-- INSERT data from S3 CSV files
-- Method 1: Direct INSERT from S3 URL (if ClickHouse has access to the S3 bucket)

-- Load data_provider.csv
INSERT INTO data_provider
SELECT 
    toUInt32(id),
    name
FROM s3(
    'https://media.theirstack.com/ts-data-engineer-test-2025/data_provider.csv',
    'CSV',
    'id UInt32, name String'
) SETTINGS input_format_skip_unknown_fields = 1;

-- Load company_data_origin.csv
INSERT INTO company_data_origin
SELECT 
    toUInt32(id),
    toUInt32(data_provider_id),
    name
FROM s3(
    'https://media.theirstack.com/ts-data-engineer-test-2025/company_data_origin.csv',
    'CSV',
    'id UInt32, data_provider_id UInt32, name String'
) SETTINGS input_format_skip_unknown_fields = 1;

-- Load company_landing.csv (assuming it exists)
INSERT INTO company_landing
SELECT 
    toUInt32(id),
    toUInt32(data_provider_origin_id),
    data_provider_company_id,
    name,
    domain,
    linkedin_slug,
    info,
    created_at,
    updated_at,
    host,
    url
FROM s3(
    'https://media.theirstack.com/ts-data-engineer-test-2025/company_landing.csv',
    'CSV',
    'id UInt32, data_provider_origin_id UInt32, data_provider_company_id String, name String, domain Nullable(String), linkedin_slug Nullable(String), info String, created_at DateTime, updated_at DateTime, host Nullable(String), url Nullable(String)'
) SETTINGS input_format_skip_unknown_fields = 1;

-- Method 2: Alternative approach using URL table function with explicit CSV parsing

-- For company_data_origin with explicit CSV handling
INSERT INTO company_data_origin
SELECT 
    toUInt32(splitByChar(',', line)[1]),
    toUInt32(splitByChar(',', line)[2]),
    splitByChar(',', line)[3]
FROM (
    SELECT line FROM url(
        'https://media.theirstack.com/ts-data-engineer-test-2025/company_data_origin.csv',
        'LineAsString'
    )
    WHERE line NOT LIKE 'id,data_provider_id,name%' -- Skip header
);

-- Method 3: Using file() function if files are downloaded locally
-- First download the files, then:

-- INSERT INTO data_provider
-- SELECT 
--     toUInt32(id),
--     name
-- FROM file('data_provider.csv', 'CSV', 'id UInt32, name String')
-- SETTINGS input_format_skip_unknown_fields = 1;

-- INSERT INTO company_data_origin  
-- SELECT 
--     toUInt32(id),
--     toUInt32(data_provider_id),
--     name
-- FROM file('company_data_origin.csv', 'CSV', 'id UInt32, data_provider_id UInt32, name String')
-- SETTINGS input_format_skip_unknown_fields = 1;

-- Method 4: Using clickhouse-client command line (run from terminal)
-- clickhouse-client --query="INSERT INTO data_provider FORMAT CSV" < data_provider.csv
-- clickhouse-client --query="INSERT INTO company_data_origin FORMAT CSV" < company_data_origin.csv

-- Verification queries
-- SELECT count() FROM data_provider;
-- SELECT count() FROM company_data_origin;
-- SELECT * FROM company_data_origin LIMIT 10;

-- Notes:
-- 1. Ensure ClickHouse server has network access to the S3 URLs
-- 2. You may need to configure S3 credentials if the bucket requires authentication
-- 3. The CSV format assumes no quotes around strings - adjust if needed
-- 4. Consider using OPTIMIZE TABLE after bulk inserts for better performance
-- 5. For production, consider using Kafka or other streaming solutions for real-time data ingestion 