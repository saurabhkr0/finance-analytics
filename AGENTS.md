## Project Context
This is a dbt project for a finance data warehouse on Snowflake.
Source data is in FINANCE_DEMO.RAW with three tables:
TRANSACTIONS, CUSTOMERS, COMPLIANCE_ALERTS.

## Conventions
- Use snake_case for all column names
- Staging models prefix: stg_
- Intermediate models prefix: int_
- Mart models prefix: mart_
- All models must have primary key tests (unique + not_null)
- Use dbt_utils.generate_surrogate_key for surrogate keys
- Monetary amounts: DECIMAL(18,2)
- Dates: cast to DATE type
- Timestamps: cast to TIMESTAMP_NTZ

## Materializations
- Staging: view
- Intermediate: ephemeral
- Marts: table (or incremental for tables > 1M rows)

## Snowflake-Specific
- Use cluster_by for large mart tables
- Target warehouse: FINANCE_DEMO_WH
- Target database: FINANCE_DEMO