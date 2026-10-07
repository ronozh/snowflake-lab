{{ config(
    alias='DAILY_SALES_NARRATIVE',
    materialized='incremental',
    unique_key='order_date',
) }}
-- Cortex AI use case: a short manager-facing summary per day, written by AI_AGG.
-- All numbers are computed in SQL; the LLM only phrases them (LLMs get arithmetic wrong).
-- Incremental: each day is summarised once (LLM cost); --full-refresh regenerates.
-- (Trial accounts allow AI_AGG / AI_SUMMARIZE_AGG but not AI_COMPLETE.)
with days as (
    select distinct order_date
    from {{ ref('fct_sales') }}
    {% if is_incremental() %}
    -- days not yet summarised (not just later ones: days can land out of order)
    where order_date not in (select order_date from {{ this }})
    {% endif %}
),

day_totals as (
    select
        f.order_date,
        count_if(is_completed)                                     as orders,
        round(sum(iff(is_completed, net_amount, 0)), 2)            as net_revenue,
        round(sum(iff(is_completed, margin_amount, 0)) * 100
              / nullif(sum(iff(is_completed, net_amount, 0)), 0), 1) as margin_pct,
        round(count_if(status in ('refunded', 'cancelled')) * 100 / count(*), 1) as refund_cancel_pct
    from {{ ref('fct_sales') }} f
    join days d on d.order_date = f.order_date
    group by f.order_date
),

ranked as (
    select
        order_date, 'channel' as dim, channel as val, sum(net_revenue) as net, sum(orders) as orders
    from {{ ref('agg_daily_sales') }} group by 1, 2, 3
    union all
    select order_date, 'category', category, sum(net_revenue), sum(orders)
    from {{ ref('agg_daily_sales') }} group by 1, 2, 3
),

top as (
    select order_date, dim, val, round(net, 2) as net,
           round(net / nullif(orders, 0), 2) as aov
    from ranked
    qualify row_number() over (partition by order_date, dim order by net desc) = 1
),

facts as (
    select order_date, 'Total: net revenue ' || net_revenue || ' AUD from ' || orders
                       || ' completed orders; margin ' || margin_pct || '%.' as line
    from day_totals
    union all
    select order_date, 'Refunded or cancelled: ' || refund_cancel_pct || '% of all transactions.'
    from day_totals
    union all
    select t.order_date, 'Top ' || t.dim || ': ' || t.val || ' with ' || t.net
                         || ' AUD net revenue (average order ' || t.aov || ' AUD).'
    from top t join days d on d.order_date = t.order_date
)

select
    order_date,
    ai_agg(
        line,
        'These are verified sales facts for one day. Write a 3-sentence summary for a retail store '
        || 'manager. Use ONLY the numbers given, exactly as written; do not calculate or invent numbers. No preamble.'
    ) as summary,
    current_timestamp() as generated_at
from facts
group by order_date
