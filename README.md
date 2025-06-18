# Data Engineer test - TheirStack, 2025

This is the test for the [Data Engineer (up to 80k€)](https://theirstack.notion.site/Data-Engineer-at-TheirStack-com-1d0885e5e97b8085b4f0c9d22733464b) position at [TheirStack](https://theirstack.com).  

The goal of this test is to build an **entity resolution system** for a table with **company data**.   
In the table, companies may appear multiple times, with information coming from multiple sources, and the same company may have multiple names.  
Also, multiple companies may have the same name.  
Jump to the ["some considerations about the data"](#some-considerations-about-the-data) part to learn more.


## Input
This repo contains a Docker compose file to run a ClickHouse database. Run `docker compose up -d` to run it. Connect to it running `make ch`.

The data to populate it is at https://media.theirstack.com/ts-data-engineer-test-2025/company_landing.csv

The table where all the company into is has this schema:
```sql
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
)
ENGINE = ReplacingMergeTree()
ORDER BY (data_provider_origin_id, data_provider_company_id)
```

We provide a dataset with 5k records, another one with 50k records and another one with 500k records. You can populate the table with any of them with any of these commands:

```sql
-- Inserts the 5k records dataset
INSERT INTO company_landing 
SELECT * FROM s3('https://media.theirstack.com/ts-data-engineer-test-2025/company_landing_5k.csv', 'CSV');

-- Inserts the 50k records dataset
INSERT INTO company_landing 
SELECT * FROM s3('https://media.theirstack.com/ts-data-engineer-test-2025/company_landing_50k.csv', 'CSV');

-- Inserts the 500k records dataset
INSERT INTO company_landing 
SELECT * FROM s3('https://media.theirstack.com/ts-data-engineer-test-2025/company_landing_500k.csv', 'CSV');
```

### Some considerations about the data
There is not a common key to identify the same company across the different sources, but there are common attributes that can be used to identify the same company.  


For example, there may be 5 records about the same company, and:
- they all have different company names
- some records may have domain and host information
- some records may have the LinkedIn slug or URL of the company
- some records may have the company industry
- some records may have the same or similar company logos


The company name alone is not enough to identify the same company across the different sources. Using the company name alone, we may end up merging information from different companies that have the same name. And we'd fail to merge multiple records with different names that refer to the same company.  

Your job is to use common attributes to build these "clusters" of rows from the `company_landing` table that belong to the same company, as if they were the connected components of an undirected graph.

![connected components](img/connected%20components.gif)


## Output
Build an entity resolution system that will be able to merge records from multiple records from the company_landing table into a single record.  

You can create as many intermediate tables and migartions on the original table as you need.

This is the proposed schema for the output table:
```sql
CREATE TABLE company_final
(
    name String,
    possible_names Array(String),
    domain Nullable(String),
    possible_domains Array(Nullable(String)),
    linkedin_slug Nullable(String),
    possible_hostnames Array(Nullable(String)),
    ... (info here extracted from the `info` JSON column)
) ENGINE = MergeTree()
ORDER BY (name)
```

It is **not** necessary to extract information from the `info` JSON column such as employee count, industry, etc. - that's out of the scope of this test. But you can also use it if you want more attributes to find common patterns between companies.

Complete this README.md file explaining:
- the approach you took
- the assumptions you made
- the trade-offs you made
- the performance of the solution
- the limitations of the solution
- the alternatives you considered
- how you used Cursor, Windsurf, Claude, ChatGPT or other AI tools to help you
- the possible improvements you would make if you had more time

## FAQ

### How will we evaluate the test?

These are things that we will value positively in your solution:

1. Maintainability: 
   1. It's easy to build on the solution and extend it (using more fields to cluster companies by them, such as the logo for example)
   2. It's easy to maintain it - if we add new sources for companies, no or minimal changes have to be made
2. Performance: 
   1. Which datasets did you do this test with: 5k, 50k, or 500k records?
   2. Have you tested your solution with the other records? How long did it take?
   3. Does time scale linearly with the number of records? Or what is the time complexity of the solution?
   4. Would your solution work with 10x more data? 100x more data? 1000x more data?
3. Reproducibility: 
   1. The solution is broken down into multiple steps, and each step is easy to understand and debug
   2. It's easy to test that each step does what it's supposed to do
4. Simplicity: If you can solve 100% or 90% of the problem with a single tool, that's better than building a system with a lot of moving pieces.
5. Industrialization:
   1. Using frameworks like dbt (or similar tools) to orchestrate and organize your solution is valued positively, as it can improve maintainability, reproducibility, and clarity.
   2. If you made migrations to the original table, or added new tables, you ran them in a way that is easy to reproduce and understand, rather than as one-off commands on the terminal.

### Should I use ClickHouse?
Yes, solve as much as you can of the test in ClickHouse. We're betting on ClickHouse and on solving as much with it as possible. Systems with just a few moving pieces are easier to maintain and extend, and let us keep being a small, lean team.

### Useful links
These may be useful depending on the approach you take:

- [Finding connected components of a graph in ClickHouse](https://fiddle.clickhouse.com/b66efe27-439f-4315-878b-ee190b41cd7c) and [in Python](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.components.connected_components.html)
- [Recursive CTEs in ClickHouse](https://clickhouse.com/blog/clickhouse-release-24-04#recursive-ctes)
- [Running Python code in ClickHouse](https://www.youtube.com/watch?v=Fi6umysVP5w)

