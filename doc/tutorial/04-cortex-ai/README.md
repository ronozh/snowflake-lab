# 4. Cortex AI and the semantic view

## Mental model

Two different AI capabilities, both on gold:

| | **Cortex Analyst** | **Cortex AI SQL functions** |
|---|---|---|
| Does | Plain-English question → SQL → answer | LLM inside a SQL query |
| Needs | A **semantic view** (business meaning of columns) | Just SQL |
| Here | "Ask the data" tab, `scripts/ask.sh`, Snowsight playground | `AI_AGG` writes `GOLD.DAILY_SALES_NARRATIVE` |
| Answers are | Computed by Snowflake from generated SQL (exact) | Text written by an LLM (must be grounded) |

## Cortex Analyst flow

```mermaid
sequenceDiagram
  participant U as User
  participant A as App / ask.sh
  participant CA as Cortex Analyst (REST)
  participant SV as SALES_SV
  participant WH as Warehouse
  U->>A: "What was net revenue by channel?"
  A->>CA: POST /api/v2/cortex/analyst/message {messages, semantic_view}
  CA->>SV: read dimensions, metrics, synonyms, comments
  CA-->>A: interpretation + SQL (SELECT ... FROM SEMANTIC_VIEW(...))
  A->>WH: run the SQL (app: owner role TRANSFORMER; ask.sh: not executed)
  WH-->>U: table / chart
```

Analyst writes SQL; it does not see or invent the numbers. Accuracy depends on how well the semantic view describes the data.

## The semantic view

A schema object that tells Analyst what the columns *mean*. Defined in `dbt/macros/deploy_semantic_view.sql`:

| Part | Example in `SALES_SV` | Meaning |
|---|---|---|
| `TABLES` | `sales AS GOLD.FCT_SALES PRIMARY KEY (transaction_id)` | Logical table |
| `FACTS` | `sales.net_amount_f AS net_amount` | Row-level numbers |
| `DIMENSIONS` | `sales.channel ... WITH SYNONYMS = ('sales channel')` | Group/filter by |
| `METRICS` | `sales.net_revenue AS SUM(CASE WHEN status = 'completed' THEN net_amount_f END)` | Aggregations, **with business rules baked in** |
| `COMMENT` / `SYNONYMS` | `customer_tier`: "bronze/silver/gold/platinum (not data layers)" | Disambiguate words users type |

Query it directly, no LLM:

```sql
SELECT * FROM SEMANTIC_VIEW(SNOWLAB_DEV.GOLD.SALES_SV
  DIMENSIONS sales.channel METRICS sales.net_revenue, sales.order_count);
```

Deployed by `dbt run-operation deploy_semantic_view` (in `pipeline.yml`), owned by `TRANSFORMER`, `SELECT`/`REFERENCES` granted to `ANALYST`.

## Ask questions (3 ways)

| Way | How |
|---|---|
| App | Streamlit → **Ask the data** tab |
| Snowsight | **AI & ML → Cortex Analyst** → open `SNOWLAB_DEV.GOLD.SALES_SV` (role `SNOWLAB_DEV_ANALYST`) |
| Terminal | `scripts/ask.sh "What was net revenue by channel?"` (key-pair JWT + `curl`; prints interpretation + SQL). Needs the `snowlab_dev_deploy` connection ([setup](../03-dbt/README.md#setup-deploy-key-and-connection)) |

Data covers **2026-01-01..07** only; other dates return empty (correct).

## Improving answers

1. Wrong column or meaning → add a `SYNONYMS` / `COMMENT` in the macro, push.
2. Good answer to keep → a **verified query** (example that steers future answers). Try it in the playground, but persist it in the macro: `CREATE OR REPLACE` on every pipeline run wipes UI-added ones (not implemented yet).
3. Check the generated SQL, not just the answer.

## AI SQL: the daily narrative

```sql
-- facts: one line per day computed in SQL (totals, margin %, top channel/category, refund share)
select order_date,
       ai_agg(line, 'These are verified sales facts for one day. Write a 3-sentence summary ...
                     Use ONLY the numbers given, exactly as written; do not calculate.') as summary
from facts group by order_date
```

**Rule learned the hard way:** the first version let the LLM add up rows and it reported wrong totals. Compute every number in SQL; let the LLM only phrase.

## Limits and settings

| Topic | Detail |
|---|---|
| Trial account | Only `AI_AGG` / `AI_SUMMARIZE_AGG` (and Cortex Analyst) work. `AI_COMPLETE`, `AI_CLASSIFY`, `SENTIMENT`, `SUMMARIZE`, `TRANSLATE`, `AI_EXTRACT`, `AI_FILTER` return "not available for trial accounts" |
| Access | Role needs `SNOWFLAKE.CORTEX_USER` (granted to `ANALYST`) |
| Region | `CORTEX_ENABLED_CROSS_REGION = ANY_REGION` (account stack): prompts may be processed outside AU. Fine for synthetic data; reconsider for real data |
| Cost | Billed per token / message, serverless; **not** capped by warehouse resource monitors. Narrative is incremental to call the LLM once per day |
