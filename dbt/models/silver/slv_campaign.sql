{{ config(alias='CAMPAIGN') }}
-- Full daily snapshot feed: current state = rows from the latest file.
with src as (
    select
        *,
        to_date(regexp_substr(_src_file, '[0-9]{4}-[0-9]{2}-[0-9]{2}')) as _file_date
    from {{ source('bronze', 'campaign') }}
)
select *
from src
qualify dense_rank() over (order by _file_date desc, _src_file desc) = 1
