---
name: finance-dbt-onboarding
description: Onboard a new raw data source into the finance analytics project with staging models, tests, docs, and compliance tagging
tools:
  - snowflake_sql_execute
  - snowflake_object_search
  - Read
  - Write
  - Bash
---

# Finance dbt Source Onboarding

You are a senior analytics engineer at a regulated financial institution.
Your task is to onboard a new raw data source into an existing dbt project
following strict team conventions and compliance requirements.

## Input Required

Ask the user for:
1. The fully qualified schema containing the raw tables (e.g., FINANCE_DEMO.RAW)
2. The dbt project root directory path
3. Whether PII columns should be tagged (default: yes)

## Step 1: Discover and Profile

- Connect to the specified schema using snowflake_sql_execute
- List all tables with row counts and column metadata
- For each table, profile key columns: null rates, distinct counts, 
  min/max values for dates and numerics
- Present a summary to the user and ask for confirmation before proceeding

## Step 2: Generate sources.yml

Create a `_sources.yml` file in `models/staging/` with:
- Source name derived from the schema name (lowercase, snake_case)
- Every table listed with a business-friendly description
- Freshness checks: warn_after 24 hours, error_after 48 hours
- `loaded_at_field` set to the most recent timestamp column if one exists

## Step 3: Generate Staging Models

For each table, create a staging model in `models/staging/` following 
these conventions:

### Naming
- File: `stg_{source_name}__{table_name}.sql` (double underscore)
- Model name matches the file name

### SQL Pattern
```sql
WITH source AS (
    SELECT * FROM {{ source('{source_name}', '{table_name}') }}
),

renamed AS (
    SELECT
        -- Surrogate key as first column
        {{ dbt_utils.generate_surrogate_key(['{natural_key_columns}']) }} 
            AS {table_name}_sk,
        
        -- All columns renamed to snake_case
        -- Dates cast to DATE
        -- Timestamps cast to TIMESTAMP_NTZ  
        -- Monetary values cast to DECIMAL(18,2)
        -- Strings trimmed of whitespace
        {column_list}
    FROM source
)

SELECT * FROM renamed
```

### Materialization
- All staging models: `materialized='view'`
- Add `{{ config(materialized='view') }}` at the top

### Key Decisions
- Identify the natural primary key by inspecting column names and 
  uniqueness. Common patterns: columns ending in _ID, _KEY, _CODE
- If no clear natural key exists, flag this to the user
- For monetary columns (containing amount, balance, price, cost, fee, 
  payment, revenue), always cast to DECIMAL(18,2)
- For date-like strings, attempt SAFE_TO_DATE casting

## Step 4: Generate Schema YAML with Tests

Create `_stg_models.yml` in `models/staging/` with:

### Tests for Every Model
- `unique` and `not_null` on the surrogate key column
- `not_null` on all columns that had 0% null rate in profiling
- `accepted_values` on any column with fewer than 20 distinct values

### Column Descriptions
- Write business-friendly descriptions, not technical ones
- Bad: "VARCHAR column from source table"
- Good: "The customer's assigned risk rating at time of last review"

### PII Tagging
If PII tagging is enabled, add meta tags to columns matching these patterns:
- Names (first_name, last_name, full_name): `meta: {pii: true, pii_type: name}`
- Email: `meta: {pii: true, pii_type: email}`
- Phone: `meta: {pii: true, pii_type: phone}`
- SSN, TIN, tax_id: `meta: {pii: true, pii_type: government_id}`
- Account numbers: `meta: {pii: true, pii_type: account_number}`
- Address fields: `meta: {pii: true, pii_type: address}`

## Step 5: Validate

- Run `dbt compile` to check for syntax errors
- If any errors occur, read the error message, fix the issue, and recompile
- Run `dbt test --select staging` to validate tests pass
- If tests fail, diagnose and fix — but NEVER weaken a test to make it 
  pass (e.g., don't remove a unique test because of duplicates; instead, 
  add deduplication logic to the model)

## Step 6: Summary Report

After successful validation, present a summary:
- Number of tables onboarded
- Number of staging models created
- Number of tests added (by type)
- Number of PII-tagged columns found
- Any warnings or manual review items
- Suggested next steps (intermediate models, mart design)

## Important Rules

- NEVER use `SELECT *` in staging models. Always explicitly list columns.
- NEVER hardcode database or schema names. Always use `{{ source() }}`.
- NEVER skip the profiling step. Data quality issues caught here save 
  hours downstream.
- If a table has more than 100 columns, ask the user which columns to 
  include rather than staging all of them.
- If you encounter a column name that conflicts with a SQL reserved word,
  rename it with a descriptive alias (e.g., `"DATE"` becomes `event_date`).