{{ config(alias='TRANSACTION') }}
-- Daily event feed: all days; per business date, rows from the latest file.
with src as (
    select
        *,
        to_date(regexp_substr(_src_file, '[0-9]{4}-[0-9]{2}-[0-9]{2}')) as _file_date
    from {{ source('bronze', 'transaction') }}
)
select *
from src
-- Latest file per day, and latest load per file (a pipe reload of an overwritten file
-- can briefly coexist with RELOAD_FILES' load).
qualify dense_rank() over (partition by _file_date order by _src_file desc) = 1
    and dense_rank() over (partition by _src_file order by _loaded_at desc) = 1
