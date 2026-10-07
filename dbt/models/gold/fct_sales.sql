{{ config(alias='FCT_SALES') }}
-- Wide intermediate: one row per transaction, all statuses, current dimension attributes.
select
    t.transaction_id,
    t.event_ts,
    t.event_ts::date                as order_date,
    hour(t.event_ts)                as order_hour,
    t.status,
    t.status = 'completed'          as is_completed,   -- business rule
    t.channel,
    t.payment_method,
    t.currency,
    t.customer_id,
    c.tier                          as customer_tier,
    c.state                         as customer_state,
    c.city                          as customer_city,
    t.product_id,
    p.sku,
    p.brand,
    p.category,
    p.subcategory,
    p.product_name,
    t.campaign_id,
    k.campaign_name,
    t.quantity,
    t.unit_price,
    t.unit_cost,
    t.discount_pct,
    t.gross_amount,
    t.net_amount,
    t.margin_amount,
    t._file_date,
    t._src_file
from {{ ref('slv_transaction') }} t
left join {{ ref('slv_customer') }} c on c.customer_id = t.customer_id
left join {{ ref('slv_product') }}  p on p.product_id  = t.product_id
left join {{ ref('slv_campaign') }} k on k.campaign_id = t.campaign_id
