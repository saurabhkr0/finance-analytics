# dbt Project Optimization Report

**Project:** `finance_warehouse`
**Database:** `FINANCE_DEMO`
**Warehouse:** `FINANCE_DEMO_WH`
**Audit Date:** 2026-04-25

---

## Executive Summary

The `finance_warehouse` dbt project is **well-structured** and follows most conventions defined in `AGENTS.md`. The project has strong test coverage, thorough documentation, and correct use of `ref()` / `source()` throughout. However, there are several areas — from security to performance to minor convention gaps — that should be addressed. Findings are prioritized below by severity.

---

## Source Table Sizes (from Snowflake)

| Schema | Table               | Row Count | Size (MB) |
|--------|---------------------|-----------|-----------|
| RAW    | COMPLIANCE_ALERTS   | 10,000    | 0.12      |
| RAW    | CUSTOMERS           | 89,621    | 1.08      |
| RAW    | TRANSACTIONS        | 500,000   | 4.77      |

All tables are well under the 1M-row threshold for incremental materialization. Current `table` materialization for marts is appropriate.

---

## Findings

### P0 — Critical

#### 1. `profiles.yml` uses `ACCOUNTADMIN` role
**File:** `profiles.yml:13`
**Issue:** The profile is configured with `role: ACCOUNTADMIN`. This is a superuser role that should never be used for routine dbt runs. It violates the principle of least privilege and poses a security risk if credentials leak.
**Recommendation:** Create a dedicated role (e.g., `FINANCE_DBT_ROLE`) with only the grants needed: `USAGE` on warehouse/database, `CREATE TABLE`/`CREATE VIEW` on target schemas, and `SELECT` on `RAW` schema. Update `profiles.yml` accordingly.

#### 2. `profiles.yml` uses password authentication
**File:** `profiles.yml:8`
**Issue:** Authentication is via `password` field with an environment variable. Key-pair authentication is more secure and is the Snowflake-recommended approach for service accounts and CI/CD.
**Recommendation:** Switch to key-pair authentication (`private_key_path` or `private_key_passphrase`) for non-interactive runs.

---

### P1 — High

#### 3. Source freshness `loaded_at_field` on `CUSTOMERS` is misleading
**File:** `src_finance.yml:19`
**Issue:** The `loaded_at_field` for the `CUSTOMERS` source is set to `ONBOARDING_DATE`. This is a business date (when the customer was onboarded), not a data-loading timestamp. Source freshness checks against this field will report stale data once all customers have been onboarded historically, even if the table was refreshed minutes ago.
**Recommendation:** If no true ingestion timestamp column exists (e.g., `_LOADED_AT`, `_ETL_UPDATED_AT`), either:
- Add a metadata column to the raw ingestion pipeline, or
- Remove `loaded_at_field` from the `CUSTOMERS` table to avoid misleading freshness alerts, and document that freshness is not monitored for this source.

#### 4. Intermediate models lack tests
**Files:** `int__models.yml`
**Issue:** Neither `int_transactions__daily_summary` nor `int_compliance_alerts__enriched` have any column-level tests defined. While intermediate models are ephemeral and tested implicitly via their downstream marts, adding at least `not_null` on key columns catches transformation bugs earlier during `dbt test`.
**Recommendation:** Add `not_null` tests on:
- `int_transactions__daily_summary`: `transaction_date`, `business_line`, `branch_city`
- `int_compliance_alerts__enriched`: `surrogate_alert_key`, `alert_id`, `alert_date`, `customer_id`

#### 5. `mart_compliance_dashboard` missing `cluster_by`
**File:** `mart_compliance_dashboard.sql:2-4`
**Issue:** Per `AGENTS.md`, large mart tables should use `cluster_by`. While 10,000 rows is small today, the compliance dashboard is likely queried by `alert_date`, `alert_severity`, or `client_segment`. Adding a clustering key now establishes the pattern for when data grows.
**Recommendation:** Add `cluster_by: ['alert_date']` or `cluster_by: ['alert_severity', 'alert_date']` to the model config.

#### 6. `mart_daily_transaction_summary` missing `not_null` tests on monetary columns
**File:** `marts__models.yml:25-34`
**Issue:** The columns `total_credit_amount`, `total_debit_amount`, `net_flow`, and `average_transaction_amount` have descriptions but no tests. Since these are aggregated monetary values that should never be NULL (they default to 0 in the SQL), `not_null` tests should be added.
**Recommendation:** Add `not_null` tests on all four monetary columns.

---

### P2 — Medium

#### 7. No `+schema` override for marts
**File:** `dbt_project.yml:33-34`
**Issue:** Staging models are written to `+schema: staging`, but marts land in the default schema (`PUBLIC`). For a clean warehouse layout, marts should target their own schema (e.g., `ANALYTICS` or `MARTS`).
**Recommendation:** Add `+schema: analytics` (or `marts`) under the `marts:` key in `dbt_project.yml`.

#### 8. `stg_finance__compliance_alerts` references source directly for customer lookup
**File:** `stg_finance__compliance_alerts.sql:9-13`
**Issue:** The staging model joins directly to `{{ source('finance_raw', 'CUSTOMERS') }}` to compute the `is_orphan_customer` flag instead of using `{{ ref('stg_finance__customers') }}`. This bypasses the staging layer's type casting and trimming, and creates a hidden dependency not visible in the dbt DAG lineage.
**Recommendation:** Replace:
```sql
select distinct customer_id
from {{ source('finance_raw', 'CUSTOMERS') }}
```
with:
```sql
select distinct customer_id
from {{ ref('stg_finance__customers') }}
```
This is a minor concern since only `customer_id` is used (no transformation difference), but it improves lineage accuracy and follows the convention that staging models should only reference their own source.

#### 9. No `relationships` test on `mart_customer_risk_profile.customer_id`
**File:** `marts__models.yml:104-108`
**Issue:** `mart_customer_risk_profile.customer_id` has `unique` and `not_null` tests but no `relationships` test back to `stg_finance__customers`. While the model is built from customers as the driving table, a relationship test would catch any future logic errors.
**Recommendation:** Add:
```yaml
- relationships:
    to: ref('stg_finance__customers')
    field: customer_id
```

#### 10. `stg_finance__compliance_alerts.customer_id` missing `relationships` test
**File:** `stg_finance__models.yml:138-144`
**Issue:** The compliance alerts staging model documents 40 orphaned customer_ids but does not have a `relationships` test (even a warned one). While the `is_orphan_customer` flag handles this in logic, a `relationships` test with `severity: warn` would surface changes in orphan count.
**Recommendation:** Add:
```yaml
- relationships:
    to: ref('stg_finance__customers')
    field: customer_id
    config:
      severity: warn
```

---

### P3 — Low

#### 11. No `dbt_project.yml` `query-comment` or `persist_docs` config
**File:** `dbt_project.yml`
**Issue:** The project does not set `query-comment` (which tags Snowflake query history with dbt metadata) or `persist_docs` (which pushes dbt descriptions into Snowflake `COMMENT` fields). Both are valuable for observability and data catalog integration.
**Recommendation:** Add to `dbt_project.yml`:
```yaml
query-comment:
  comment: "dbt: {{ node.unique_id }}"
  append: true

models:
  +persist_docs:
    relation: true
    columns: true
```

#### 12. `threads: 4` may be conservative
**File:** `profiles.yml:14`
**Issue:** With only 8 models (3 staging, 2 intermediate, 3 marts), 4 threads is adequate. However, if the project grows, consider increasing to 8 for the `dev` target.
**Recommendation:** No action needed now. Revisit if model count exceeds 20.

#### 13. No `on-run-start` / `on-run-end` hooks for grant management
**File:** `dbt_project.yml`
**Issue:** There are no hooks to grant `SELECT` to downstream roles after models are built. If consumers (dashboards, analysts) read from the mart schema, permissions must be managed manually.
**Recommendation:** Add an `on-run-end` hook for automated grants, e.g.:
```yaml
on-run-end:
  - "GRANT SELECT ON ALL TABLES IN SCHEMA {{ target.database }}.ANALYTICS TO ROLE FINANCE_READER"
  - "GRANT SELECT ON ALL VIEWS IN SCHEMA {{ target.database }}.STAGING TO ROLE FINANCE_READER"
```

#### 14. `packages.yml` version range is very broad
**File:** `packages.yml:2-3`
**Issue:** `dbt_utils` is pinned to `[">=1.0.0", "<2.0.0"]`. While functional, this allows major minor-version jumps that could introduce breaking changes.
**Recommendation:** Pin to a tighter range, e.g., `[">=1.3.0", "<1.4.0"]` matching the currently installed version. Use `package-lock.yml` (already present) to ensure reproducibility.

#### 15. Monetary columns in intermediate models not explicitly cast to `DECIMAL(18,2)`
**Files:** `int_transactions__daily_summary.sql`
**Issue:** The `AGENTS.md` convention requires monetary amounts as `DECIMAL(18,2)`. While `stg_finance__transactions` casts `transaction_amount` correctly, the aggregations in `int_transactions__daily_summary` (`total_credit_amount`, `total_debit_amount`, `net_flow`, `average_transaction_amount`) do not explicitly cast their results. Snowflake will infer the type from the aggregation, which may widen precision.
**Recommendation:** Add explicit casts in the intermediate model:
```sql
sum(...)::decimal(18, 2) as total_credit_amount,
```

---

## Scorecard

| Category                     | Score | Notes                                                      |
|------------------------------|-------|------------------------------------------------------------|
| **Materialization**          | 9/10  | Correct for all layers. No incremental needed at current scale. |
| **Clustering**               | 7/10  | Applied on 2 of 3 marts. Missing on `mart_compliance_dashboard`. |
| **Test Coverage**            | 7/10  | Strong on staging and marts. Missing on intermediates and some mart monetary columns. |
| **Documentation**            | 9/10  | Descriptions on all models and nearly all columns. `persist_docs` not enabled. |
| **Source Freshness**         | 6/10  | Configured, but `CUSTOMERS.loaded_at_field` is a business date, not an ETL timestamp. |
| **Naming Conventions**       | 10/10 | All prefixes (`stg_`, `int_`, `mart_`) correct. snake_case throughout. |
| **ref/source Usage**         | 8/10  | One direct source reference in `stg_finance__compliance_alerts` bypasses staging. |
| **Surrogate Keys**           | 10/10 | `dbt_utils.generate_surrogate_key` used correctly on all models. |
| **Type Casting**             | 8/10  | Correct in staging. Intermediate aggregations lack explicit `DECIMAL(18,2)` casts. |
| **Security**                 | 3/10  | `ACCOUNTADMIN` role + password auth. No grant management. |
| **Observability**            | 5/10  | No `query-comment`, no `persist_docs`, no hooks. |
| **Overall**                  | **7.5/10** | Solid foundation. Security and observability are the primary gaps. |

---

## Recommended Action Order

1. **Switch away from `ACCOUNTADMIN`** — create a dedicated dbt role with minimal grants (P0)
2. **Adopt key-pair authentication** for CI/CD and service accounts (P0)
3. **Fix `CUSTOMERS` source freshness** — replace `ONBOARDING_DATE` with a true ETL timestamp or remove (P1)
4. **Add tests on intermediate models** and monetary mart columns (P1)
5. **Add `cluster_by` to `mart_compliance_dashboard`** (P1)
6. **Add `+schema: analytics` for marts** to separate from `PUBLIC` (P2)
7. **Fix direct source reference** in `stg_finance__compliance_alerts` (P2)
8. **Add relationship tests** on mart and staging customer_id columns (P2)
9. **Enable `query-comment` and `persist_docs`** (P3)
10. **Add grant management hooks** (P3)
11. **Tighten `dbt_utils` version pin** (P3)
12. **Add explicit `DECIMAL(18,2)` casts** in intermediate aggregations (P3)

---

*Report generated by Cortex Code dbt audit.*
