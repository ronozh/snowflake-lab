{{ config(alias='AGG_DAILY_SALES') }}
-- Completed sales by day x channel x category.
select
    order_date,
    channel,
    category,
    count(*)            as orders,
    sum(quantity)       as units,
    sum(gross_amount)   as gross_revenue,
    sum(net_amount)     as net_revenue,
    sum(margin_amount)  as margin
from {{ ref('fct_sales') }}
where is_completed
group by all
