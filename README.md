# Senior Data Engineer test - TheirStack, 2025

This is the test for the [Senior Data Engineer (up to 80k€)](https://theirstack.notion.site/Data-Engineer-at-TheirStack-com-1d0885e5e97b8085b4f0c9d22733464b) position at [TheirStack](https://theirstack.com).  

The goal of this test is to build an **entity resolution system** for a table with **company data**.   
In the table, companies may appear multiple times, with information coming from multiple sources, and the same company may have multiple names.  
Also, multiple companies may have the same name.  
Jump to the ["some considerations about the data"](#some-considerations-about-the-data) part to learn more.


## Input
This repo contains a Docker Compose file to run a ClickHouse database. Run `docker compose up -d` to run it. Connect to it running `make ch`.

The data to populate it is at https://media.theirstack.com/ts-data-engineer-test-2025/company_landing.csv

The table where all the company into is has this schema:
```sql
CREATE TABLE company_landing
(
    data_provider_origin_id UInt32 COMMENT 'The ID of the data provider where this company information was pulled from (1, 2, 3...)',
    data_provider_company_id String COMMENT 'The ID of the company in the data provider (such as "99e969521edc4d32", "firmenich", "Canva", ...). This is the ID that uniquely identifies the company in the data provider. For some data providers where we were unable to find a unique ID, we used the company name instead.',
    name String COMMENT 'The name of the company',
    domain Nullable(String) COMMENT 'The domain of the URL of the company (e.g. "google.com")',
    linkedin_slug Nullable(String) COMMENT 'The LinkedIn slug of the company (e.g. "google")',
    info String COMMENT 'JSON stored as String in ClickHouse, contains information about the company such as the industry, employee count, etc. The format of this column is different for each data provider.',
    created_at DateTime64(3) DEFAULT now() COMMENT 'The date and time the record was created',
    updated_at DateTime64(3) DEFAULT now() COMMENT 'The date and time the record was updated',
    host Nullable(String) COMMENT 'The full hostname of the URL of the company (e.g. "careers.google.com")',
    url Nullable(String) COMMENT 'The full URL of the company (e.g. "https://careers.google.com")'
)
ENGINE = ReplacingMergeTree()
ORDER BY (data_provider_origin_id, data_provider_company_id)
```

The combination of `data_provider_origin_id` and `data_provider_company_id` is unique, no two rows with the same value of these two columns exists in the `company_landing` table.  

In some cases, the `domain` field can uniquely identify a company. However, this is not always reliable. For example, when the URL comes from an ATS (Applicant Tracking System) provider, each company may have a different subdomain (e.g., `bluserena.zohorecruit.eu`), but the `domain` (`zohorecruit.eu`) is shared by many unrelated companies.

In all cases, we provide the `host` field, which is the full hostname of the URL of the company (e.g. "careers.google.com"). This field can be used to uniquely identify a company. But if you only use the host to find groups, you wouldn't be able to match `jobs.google.com` with `careers.google.com` or with `google.com`, so additional logic may be necessary there in a production solution.

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


The company name alone is not enough to identify the same company across the different sources. Using the company name alone, we may end up merging information from different companies that have the same name. And we'd fail to merge multiple records with different names that refer to the same company.  

Your job is to use common attributes to build these "clusters" of rows from the `company_landing` table that belong to the same company, as if they were the connected components of an undirected graph.

![connected components](img/connected%20components.gif)

Also, note that:
- within the same data provider, the same company may have different values for `data_provider_company_id`
- within the same data provider, the same company may have different values for `name`
- within the same data provider, the same company may have different values for `domain`
- within the same data provider, the same company may have different values for `host`
- within the same data provider, the same company may have different values for `url`

You don't need to cover all these edge cases, but you should be aware of them.

Also, there may be cases where all of domain, host and linkedin_slug are null for a company where other records have a value for one of those fields. In those cases, treat it as a different company because if the only field in common is the name we may end up merging information from other different companies that have the same name.


## Output
Build an entity resolution system that will be able to merge records from multiple records from the company_landing table into a single record.  

You can create as many intermediate tables and migrationsmigartions on the original table as you need.

This is the proposed schema for the output table:
```sql
CREATE TABLE company_final
(
   name String, -- choose one
   data_providers_and_company_ids Array(Tuple(UInt32, String)) COMMENT 'The combinations of data_provider_origin_id and data_provider_company_id that belong to the same company, e.g. [(1, "99e969521edc4d32"), (2, "google")]',
   possible_names Array(String) COMMENT 'The unique possible names of the company, e.g. "Google", "YouTube", "Alphabet"',
   possible_domains Array(Nullable(String)) COMMENT 'The unique possible domains of the company, e.g. "google.com", "youtube.com"',
   linkedin_slug Nullable(String) COMMENT 'The LinkedIn slug of the company, e.g. "google"',
   possible_hostnames Array(Nullable(String)) COMMENT 'The unique possible hostnames of the company, e.g. "careers.google.com", "google.com", "careers.youtube.com"'
   -- more columns could be added here to extract details about each company, but this is out of the scope of this test
) ENGINE = MergeTree()
ORDER BY (name)
```

### Examples

For an input like this:
| data\_provider\_origin\_id | data\_provider\_company\_id | name | domain | linkedin\_slug | host | url |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 5f2987132c142600daf44da0 | Amazon Web Services \(AWS\) | null | amazon-web-services | null | null |
| 3 | amazon-web-services | Amazon Web Services \(AWS\) | amazon.com | amazon-web-services | aws.amazon.com | http://aws.amazon.com |
| 2 | 1a7417cbcd7e0e0d | American Airlines | aa.com | null | aa.com | http://jobs.aa.com |
| 1 | 5da65de01eafc200013d00e0 | American Airlines | aa.com | american-airlines | aa.com | http://www.aa.com |
| 3 | american-airlines | American Airlines | aa.com | american-airlines | aa.com | http://jobs.aa.com |


Your process should be able to identify that those 5 records belong only to 2 different companies, AWS and American Airlines, and return the combinations of `data_provider_origin_id` and `data_provider_company_id` that belong to the same company, e.g. `[(1, "5f2987132c142600daf44da0"), (2, "1a7417cbcd7e0e0d"), (3, "american-airlines")]`.

Producing a result like this:  

| name | data_providers_and_company_ids | possible_names | possible_domains | linkedin_slug | possible_hostnames |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Amazon Web Services \(AWS\) | [(1, "5f2987132c142600daf44da0"), (3, "amazon-web-services")] | ["Amazon Web Services \(AWS\)"] | ["amazon.com"] | "amazon-web-services" | ["aws.amazon.com"] |
| American Airlines | [(2, "1a7417cbcd7e0e0d"), (1, "5da65de01eafc200013d00e0"), (3, "american-airlines")] | ["American Airlines"] | ["aa.com"] | "american-airlines" | ["aa.com", "jobs.aa.com"] |

### A possible approach

A path that we see promising is dividing the problem into smaller steps, such as:
1. Grouping by certain attributes to produce intermediate tables:
   1. one grouping by domain
   2. one grouping by linkedin_slug
   3. one grouping by host (sometimes the domain will be too broad and other times the host will be too specific, more logic may be necessary there)
2. In those intermediate tables, store the combinations of `data_provider_origin_id` and `data_provider_company_id` that belong to the same company that have that attribute in common (domain, linkedin_slug...)
3. Treating companies as node of a graph, and the fact that they belong to some of those intermediate tables as edges, we can find the connected components of the graph, which are the clusters of companies that belong to the same company.
4. For each connected component, we can extract the possible names, domains, hostnames, etc. of the companies that belong to it.
5. We can then merge the information from the intermediate tables into the final table.


### About this test

Don't invest more than 4-5 hours into this test. We're aware many things will be missing and can be improved, and even if you don't finish it, we'll value your thought process and how you think of next steps, handling edge cases, etc.

This may look like a classic ML classification problem, but it's not because we don't have a pre-defined master list of companies - that has to be built from the data. And if more companies appear in the `company_landing` table, some of those will be new, so classifying them according to the set of companies we had before will fail to classify new companies correctly.

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
We have recently migrated to ClickHouse, and we're betting hard that many parts of our data processing stack will run on it, so if you join us you'd be using it every day.  
But if you feel more comfortable with another tool, you can use it if it'll allow you to solve the test faster.

### Useful links
These may be useful depending on the approach you take:

- [Finding connected components of a graph in ClickHouse](https://fiddle.clickhouse.com/b66efe27-439f-4315-878b-ee190b41cd7c) and [in Python](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.components.connected_components.html)
- [Recursive CTEs in ClickHouse](https://clickhouse.com/blog/clickhouse-release-24-04#recursive-ctes)
- [Running Python code in ClickHouse](https://www.youtube.com/watch?v=Fi6umysVP5w)

