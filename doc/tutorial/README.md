# Tutorial

How this project works, from the big picture down to the code. Read in order the first time.

| # | Topic | You'll learn |
|---|---|---|
| 1 | [Architecture](01-architecture/README.md) | The end-to-end flow, the medallion layers, the infrastructure, who does what |
| 2 | [Terraform](02-terraform/README.md) | How infrastructure as code works here, what each stack manages, how to check it |
| 3 | [dbt](03-dbt/README.md) | How bronze becomes silver and gold, model by model |
| 4 | [Cortex AI](04-cortex-ai/README.md) | Semantic view, Cortex Analyst (questions → SQL), AI SQL functions |
| 5 | [Streamlit](05-streamlit/README.md) | The dashboard + chat app, how it runs inside Snowflake |
| 6 | [Snowflake walkthrough](06-snowflake-walkthrough/README.md) | Snowsight UI tour, with the AI & ML features step by step |

Conventions: `SNOWLAB_DEV` is the DEV database. `<org>-<account>`, `<account_id>` and `<bucket>` are placeholders (never committed).
