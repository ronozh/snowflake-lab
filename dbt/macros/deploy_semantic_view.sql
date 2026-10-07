{#
  Semantic view over GOLD.FCT_SALES for Cortex Analyst (+ SEMANTIC_VIEW() queries).
  Deployed after `dbt build`:  dbt run-operation deploy_semantic_view
  Owned by TRANSFORMER; ANALYST gets SELECT/REFERENCES.
#}
{% macro deploy_semantic_view() %}
  {% set sv = target.database ~ '.GOLD.SALES_SV' %}
  {% set fct = target.database ~ '.GOLD.FCT_SALES' %}
  {% set analyst = target.role | replace('_TRANSFORMER', '_ANALYST') %}
  {% set ddl %}
    CREATE OR REPLACE SEMANTIC VIEW {{ sv }}
      TABLES (
        sales AS {{ fct }}
          PRIMARY KEY (transaction_id)
          COMMENT = 'One row per e-commerce transaction (AUD), all statuses'
      )
      FACTS (
        sales.net_amount_f AS net_amount COMMENT = 'Amount paid after discount, AUD',
        sales.margin_amount_f AS margin_amount COMMENT = 'Net amount minus cost, AUD',
        sales.quantity_f AS quantity COMMENT = 'Units in the transaction'
      )
      DIMENSIONS (
        sales.order_date AS order_date WITH SYNONYMS = ('date', 'day') COMMENT = 'Transaction date',
        sales.order_hour AS order_hour WITH SYNONYMS = ('hour') COMMENT = 'Hour of day 0-23',
        sales.status AS status COMMENT = 'completed | cancelled | refunded | pending',
        sales.channel AS channel WITH SYNONYMS = ('sales channel') COMMENT = 'web | mobile_app | marketplace | in_store | phone',
        sales.payment_method AS payment_method COMMENT = 'credit_card | debit_card | paypal | buy_now_pay_later | bank_transfer | gift_card',
        sales.customer_tier AS customer_tier WITH SYNONYMS = ('loyalty tier', 'membership tier') COMMENT = 'Customer loyalty tier: bronze | silver | gold | platinum (not data layers)',
        sales.customer_state AS customer_state WITH SYNONYMS = ('state') COMMENT = 'Australian state code',
        sales.category AS category WITH SYNONYMS = ('product category') COMMENT = 'Product category',
        sales.brand AS brand COMMENT = 'Product brand',
        sales.product_name AS product_name WITH SYNONYMS = ('product') COMMENT = 'Product name',
        sales.campaign_name AS campaign_name WITH SYNONYMS = ('campaign', 'promotion') COMMENT = 'Marketing campaign; null if none'
      )
      METRICS (
        sales.net_revenue AS SUM(CASE WHEN sales.status = 'completed' THEN sales.net_amount_f END)
          WITH SYNONYMS = ('revenue', 'sales', 'turnover') COMMENT = 'Net revenue from completed transactions only',
        sales.order_count AS COUNT_IF(sales.status = 'completed')
          WITH SYNONYMS = ('orders', 'number of orders') COMMENT = 'Completed transactions',
        sales.total_margin AS SUM(CASE WHEN sales.status = 'completed' THEN sales.margin_amount_f END)
          COMMENT = 'Margin from completed transactions',
        sales.transaction_count AS COUNT(sales.transaction_id) COMMENT = 'All transactions, any status'
      )
      COMMENT = 'E-commerce sales for Cortex Analyst. Revenue metrics count completed transactions only.'
  {% endset %}
  {% do run_query(ddl) %}
  {% do run_query('GRANT SELECT, REFERENCES ON SEMANTIC VIEW ' ~ sv ~ ' TO ROLE ' ~ analyst) %}
  {{ log('deployed ' ~ sv ~ ' (granted to ' ~ analyst ~ ')', info=True) }}
{% endmacro %}
