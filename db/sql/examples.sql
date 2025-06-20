-- @block
-- exploring some data
WITH s0 AS (
    SELECT
        data_provider_origin_id
      , data_provider_company_id
      , name
      , domain
      , linkedin_slug
--       , '{...}' as info
--       , created_at
--       , updated_at
      , host
      , url
      , count() OVER (PARTITION BY name) AS count_name
    --       , * EXCEPT info
--     , COALESCE(nullIf(info, ''), '{}') AS info
    FROM company_landing
    WHERE
--         domain <> HOST -- order by rand()
        domain IS NOT NULL
      OR "host" IS NOT NULL
      OR linkedin_slug IS NOT NULL
    ORDER BY "name"
    )
SELECT * except count_name
FROM s0
-- ORDER BY name
WHERE
      TRUE
  AND count_name > 1
-- limit 100
    SETTINGS enable_json_type = 1



-- @block
-- simpler version of company_landing
SELECT * FROM company_landing
WHERE
    domain IS NOT NULL
    OR "host" IS NOT NULL
    OR linkedin_slug IS NOT NULL
ORDER BY "name"
