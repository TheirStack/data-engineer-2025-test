# Data Engineer test - TheirStack, 2025

The goal of this test is to build an entity resolution system for a table with company data. 
In the table, companies may appear multiple times, with information coming from multiple sources.
There is not a common key to identify the same company across the different sources, but there are common attributes that can be used to identify the same company.
For example, there may be 5 records about the same company, with:
- different names
- some records may have domain information
- some records may have the LinkedIn slug or URL of the company
- some records may have the company industry
- some records may have a company logo

The company name alone is not enough to identify the same company across the different sources. Using the company name alone, we may end up merging information from different companies that have the same name. And we'd fail to merge multiple records with different names that refer to the same company.



## Input
This repo contains:
- a Docker compose file to run a ClickHouse database
- a SQL file to create the initial schema and seed the database

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
) ENGINE = MergeTree()
ORDER BY (name)
```

## Output
Build an entity resolution system that will be able to merge records from multiple records from the company_landing table into a single record.
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

Add a README.md file explaining
- the approach you took
- the assumptions you made
- the trade-offs you made
- the performance of the solution
- the limitations of the solution
- the alternatives you considered
- the possible improvements you would make if you had more time

## FAQ

### How will we evaluate the test?

We'll value very possitively things like:

1. Maintainability: how easy is it to build on, maintain and extend the solution? If we add company data from a new source, how easy is it to add it to the solution?
2. Performance: The test data is just 50k records. Our production DB includes data about 5M companies. And there are probably ~50M companies in the world we want to be in our database at some point. How does your solution work with 10x more data? 1000x more data? Have you tested the performance of your solution?
3. Reproducibility: the easier it is to reproduce, debug and understand the solution and its intermediate steps, the better.
4. Simplicity: if you can solve 100% or 90% of the problem with a single tool, that's better than building a system with a lot of moving pieces. We made the change to ClickHouse recently and want to keep building as much as possible in it. Systems with just a few moving pieces are easier to maintain and extend, and let us keep being a small, lean team.


### Should I use ClickHouse?
Yes, solve as much as you can of the test in ClickHouse.

### Can I use AI/ML?
Yes.

### Useful links

These may be useful depending on the approach you take:

- [Finding connected components of a graph in ClickHouse](https://fiddle.clickhouse.com/b66efe27-439f-4315-878b-ee190b41cd7c) and [in Python](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.components.connected_components.html)
- [Recursive CTEs in ClickHouse](https://clickhouse.com/blog/clickhouse-release-24-04#recursive-ctes)
- [Running Python code in ClickHouse](https://www.youtube.com/watch?v=Fi6umysVP5w)

