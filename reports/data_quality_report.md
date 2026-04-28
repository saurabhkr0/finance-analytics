# Data Quality Report: FINANCE_DEMO.RAW

**Generated:** 2026-04-25
**Connection:** HQ84620
**Schema:** FINANCE_DEMO.RAW
**Tables Profiled:** TRANSACTIONS, CUSTOMERS, COMPLIANCE_ALERTS

---

## Executive Summary

| Finding | Severity | Table |
|---------|----------|-------|
| TRANSACTION_ID is not unique (116,790 excess rows across 97,143 duplicate groups) | **Critical** | TRANSACTIONS |
| ALERT_ID is not unique (482 excess rows across 468 duplicate groups) | **Critical** | COMPLIANCE_ALERTS |
| 50 compliance alerts reference non-existent customer IDs | **High** | COMPLIANCE_ALERTS |
| Negative amounts spread uniformly across all transaction types including Deposits | **High** | TRANSACTIONS |
| COMPLIANCE_ALERTS has no TRANSACTION_ID column (cannot enforce FK to TRANSACTIONS) | **Medium** | COMPLIANCE_ALERTS |
| No primary key / unique constraints enforced on any table | **Medium** | ALL |
| All columns are nullable | **Medium** | ALL |
| ~75% of customers are non-Active (Inactive/Dormant/Closed) | **Low** | CUSTOMERS |

**Overall Data Quality Score: 6/10** - Critical primary key issues must be resolved before downstream modeling.

---

## 1. TRANSACTIONS

### 1.1 Table Overview

| Metric | Value |
|--------|-------|
| Row Count | 500,000 |
| Columns | 9 |
| Storage | ~5 MB |
| Date Range | 2024-04-18 to 2026-04-18 |

### 1.2 Column Profile

| Column | Type | Nulls | Null % | Distinct | Min | Max | Avg |
|--------|------|-------|--------|----------|-----|-----|-----|
| TRANSACTION_ID | NUMBER(6,0) | 0 | 0% | 383,210 | 100,000 | 999,995 | - |
| TRANSACTION_DATE | DATE | 0 | 0% | 731 | 2024-04-18 | 2026-04-18 | - |
| ACCOUNT_TYPE | VARCHAR | 0 | 0% | 5 | - | - | - |
| TRANSACTION_TYPE | VARCHAR | 0 | 0% | 10 | - | - | - |
| AMOUNT | NUMBER(13,2) | 0 | 0% | 216,368 | -500.00 | 2,000.00 | 747.27 |
| CURRENCY | VARCHAR | 0 | 0% | 5 | - | - | - |
| BRANCH_CITY | VARCHAR | 0 | 0% | 8 | - | - | - |
| BUSINESS_LINE | VARCHAR | 0 | 0% | 4 | - | - | - |
| CUSTOMER_ID | NUMBER(5,0) | 0 | 0% | 89,621 | 10,000 | 99,999 | - |

### 1.3 Primary Key Uniqueness -- CRITICAL

**TRANSACTION_ID is NOT unique.** 97,143 IDs appear more than once, producing 116,790 excess rows. The maximum duplication is 7 rows for a single ID.

These are **not** exact row duplicates -- rows sharing the same TRANSACTION_ID have different dates, amounts, customers, and other attributes. This means `TRANSACTION_ID` is being reused or generated with collisions.

```
Sample: TRANSACTION_ID = 540424 appears 7 times with different customers, dates, and amounts.
```

**Impact:** Any downstream model that treats TRANSACTION_ID as a primary key (joins, deduplication, incremental loads) will produce incorrect results.

### 1.4 Negative Amounts -- HIGH

100,571 rows (20.1%) have negative AMOUNT values ranging from -500.00 to -0.01.

| Transaction Type | Negative Count | Avg Negative |
|------------------|---------------|--------------|
| Check | 10,293 | -249.06 |
| Transfer | 10,185 | -249.11 |
| Interest | 10,136 | -249.66 |
| ATM | 10,095 | -250.25 |
| Dividend | 10,041 | -251.37 |
| Fee | 10,003 | -249.81 |
| Wire | 9,982 | -251.08 |
| Deposit | 9,965 | -250.14 |
| Withdrawal | 9,938 | -250.50 |
| ACH | 9,933 | -251.93 |

Negative amounts are spread **uniformly** across all transaction types including types where negatives are semantically suspicious (e.g., Deposit, Dividend, Interest). This suggests the sign is random rather than encoding debits/credits.

### 1.5 Categorical Distributions

**ACCOUNT_TYPE** (5 values, evenly distributed ~100K each):
Checking, Savings, Credit Card, Loan, Brokerage

**TRANSACTION_TYPE** (10 values, evenly distributed ~50K each):
ATM, Check, Transfer, Dividend, Interest, Wire, ACH, Withdrawal, Fee, Deposit

**CURRENCY** (5 values, evenly distributed ~100K each):
EUR, USD, JPY, GBP, CHF

**BRANCH_CITY** (8 values, evenly distributed ~62K each):
Singapore, New York, Toronto, San Francisco, Chicago, Hong Kong, London, Zurich

**BUSINESS_LINE** (4 values, evenly distributed ~125K each):
Private Banking, Retail, Wealth Mgmt, Institutional

All categorical columns show near-uniform distributions, which may indicate synthetic/generated data.

### 1.6 Outlier Analysis

No statistical outliers detected (no AMOUNT values beyond 3 standard deviations from mean).
- Mean: 747.27, Std Dev: 722.06, Range: [-500.00, 2000.00]

### 1.7 Future Dates

No future dates found in TRANSACTION_DATE. Date range is 2024-04-18 to 2026-04-18.

### 1.8 Referential Integrity -- PASS

All 500,000 TRANSACTIONS.CUSTOMER_ID values map to a valid CUSTOMERS.CUSTOMER_ID. Zero orphan records. Every customer in CUSTOMERS has at least one transaction.

---

## 2. CUSTOMERS

### 2.1 Table Overview

| Metric | Value |
|--------|-------|
| Row Count | 89,621 |
| Columns | 6 |
| Storage | ~1.1 MB |
| Onboarding Date Range | 2006-04-23 to 2025-04-18 |

### 2.2 Column Profile

| Column | Type | Nulls | Null % | Distinct | Min | Max | Avg |
|--------|------|-------|--------|----------|-----|-----|-----|
| CUSTOMER_ID | NUMBER(5,0) | 0 | 0% | 89,621 | 10,000 | 99,999 | - |
| RISK_RATING | VARCHAR | 0 | 0% | 3 | - | - | - |
| ACCOUNT_STATUS | VARCHAR | 0 | 0% | 4 | - | - | - |
| ONBOARDING_DATE | DATE | 0 | 0% | 6,936 | 2006-04-23 | 2025-04-18 | - |
| TOTAL_AUM | NUMBER(15,2) | 0 | 0% | 89,540 | 22.50 | 499,992.71 | 249,869.75 |
| CLIENT_SEGMENT | VARCHAR | 0 | 0% | 4 | - | - | - |

### 2.3 Primary Key Uniqueness -- PASS

CUSTOMER_ID is fully unique (89,621 distinct values = 89,621 rows). No duplicates.

### 2.4 Categorical Distributions

**RISK_RATING** (3 values):
| Value | Count | % |
|-------|-------|---|
| High | 29,973 | 33.4% |
| Low | 29,908 | 33.4% |
| Medium | 29,740 | 33.2% |

**ACCOUNT_STATUS** (4 values):
| Value | Count | % |
|-------|-------|---|
| Inactive | 22,625 | 25.2% |
| Dormant | 22,473 | 25.1% |
| Closed | 22,315 | 24.9% |
| Active | 22,208 | 24.8% |

**CLIENT_SEGMENT** (4 values):
| Value | Count | % |
|-------|-------|---|
| Institutional | 22,604 | 25.2% |
| HNWI | 22,461 | 25.1% |
| UHNWI | 22,293 | 24.9% |
| Retail | 22,263 | 24.8% |

Note: Only 24.8% of customers are Active. 75.2% are Inactive/Dormant/Closed, yet all have transactions. This may warrant a business logic review.

### 2.5 Outlier Analysis

No statistical outliers detected in TOTAL_AUM (all values within 3 std dev).
- Mean: 249,869.75, Std Dev: 144,516.51, Range: [22.50, 499,992.71]

### 2.6 Future Dates

No future dates found in ONBOARDING_DATE.

---

## 3. COMPLIANCE_ALERTS

### 3.1 Table Overview

| Metric | Value |
|--------|-------|
| Row Count | 10,000 |
| Columns | 6 |
| Storage | ~126 KB |
| Alert Date Range | 2025-04-18 to 2026-04-18 |

### 3.2 Column Profile

| Column | Type | Nulls | Null % | Distinct | Min | Max | Avg |
|--------|------|-------|--------|----------|-----|-----|-----|
| ALERT_ID | NUMBER(5,0) | 0 | 0% | 9,518 | 16 | 99,997 | - |
| ALERT_DATE | DATE | 0 | 0% | 366 | 2025-04-18 | 2026-04-18 | - |
| CUSTOMER_ID | NUMBER(5,0) | 0 | 0% | 9,467 | 10,019 | 99,980 | - |
| ALERT_TYPE | VARCHAR | 0 | 0% | 6 | - | - | - |
| STATUS | VARCHAR | 0 | 0% | 5 | - | - | - |
| SEVERITY | VARCHAR | 0 | 0% | 4 | - | - | - |

### 3.3 Primary Key Uniqueness -- CRITICAL

**ALERT_ID is NOT unique.** 468 IDs appear more than once, producing 482 excess rows. The maximum duplication is 3 rows for a single ID.

### 3.4 Referential Integrity -- HIGH

**50 alerts** (across 47 distinct CUSTOMER_IDs) reference customers that do not exist in the CUSTOMERS table. These are orphan records that will be lost in any inner join to CUSTOMERS.

### 3.5 Missing TRANSACTION_ID Column -- MEDIUM

The COMPLIANCE_ALERTS table has **no TRANSACTION_ID column**. The expected FK relationship `COMPLIANCE_ALERTS.transaction_id -> TRANSACTIONS.transaction_id` cannot be validated because the column does not exist. Alerts are linked to customers but not to specific transactions.

### 3.6 Categorical Distributions

**ALERT_TYPE** (6 values):
| Value | Count | % |
|-------|-------|---|
| Structuring | 1,717 | 17.2% |
| Geo Anomaly | 1,675 | 16.8% |
| Unusual Pattern | 1,660 | 16.6% |
| Sanctions Match | 1,658 | 16.6% |
| Large Cash | 1,646 | 16.5% |
| Velocity | 1,644 | 16.4% |

**STATUS** (5 values):
| Value | Count | % |
|-------|-------|---|
| Closed - SAR Filed | 2,030 | 20.3% |
| Escalated | 2,022 | 20.2% |
| Closed - No Action | 1,986 | 19.9% |
| Under Review | 1,985 | 19.9% |
| Open | 1,977 | 19.8% |

**SEVERITY** (4 values):
| Value | Count | % |
|-------|-------|---|
| Medium | 2,531 | 25.3% |
| Critical | 2,522 | 25.2% |
| Low | 2,487 | 24.9% |
| High | 2,460 | 24.6% |

### 3.7 Future Dates

No future dates found in ALERT_DATE.

---

## 4. Cross-Table Analysis

### 4.1 Referential Integrity Summary

| Relationship | Status | Orphan Count |
|-------------|--------|-------------|
| TRANSACTIONS.CUSTOMER_ID -> CUSTOMERS.CUSTOMER_ID | PASS | 0 |
| COMPLIANCE_ALERTS.CUSTOMER_ID -> CUSTOMERS.CUSTOMER_ID | **FAIL** | 50 |
| COMPLIANCE_ALERTS.TRANSACTION_ID -> TRANSACTIONS.TRANSACTION_ID | **N/A** | Column missing |

### 4.2 Coverage

- All 89,621 customers have at least 1 transaction.
- 9,467 distinct customers (10.6%) have compliance alerts.

---

## 5. Schema-Level Concerns

### 5.1 No Constraints Defined -- MEDIUM

None of the three tables have any primary key, unique key, or check constraints defined in Snowflake. All columns are nullable. While Snowflake doesn't enforce most constraints at write time, defining them aids query optimization and documentation.

### 5.2 VARCHAR Columns Are Unbounded -- LOW

All VARCHAR columns use the default `VARCHAR(16777216)`. While this has no storage impact in Snowflake (storage is based on actual data), it provides no schema documentation of expected lengths.

---

## 6. Findings Summary

### Critical

| # | Finding | Table | Impact |
|---|---------|-------|--------|
| 1 | TRANSACTION_ID has 97,143 duplicate groups (116,790 excess rows, max 7 per ID). These are distinct transactions sharing the same ID. | TRANSACTIONS | Any model using TRANSACTION_ID as PK will produce wrong aggregations, incorrect joins, and broken incremental loads. |
| 2 | ALERT_ID has 468 duplicate groups (482 excess rows, max 3 per ID). | COMPLIANCE_ALERTS | PK-based joins and deduplication will lose or duplicate data. |

### High

| # | Finding | Table | Impact |
|---|---------|-------|--------|
| 3 | 50 compliance alerts reference 47 customer IDs not in CUSTOMERS. | COMPLIANCE_ALERTS | Inner joins to CUSTOMERS will silently drop these alerts. |
| 4 | 20.1% of transactions have negative amounts, spread uniformly across all types including Deposits and Dividends. | TRANSACTIONS | Financial aggregations (revenue, volume) may be understated. Negative deposits are semantically invalid. |

### Medium

| # | Finding | Table | Impact |
|---|---------|-------|--------|
| 5 | COMPLIANCE_ALERTS has no TRANSACTION_ID column. | COMPLIANCE_ALERTS | Cannot link alerts to specific transactions for investigation or lineage. |
| 6 | No PK/UK/NOT NULL constraints on any table. | ALL | No guardrails against future data quality regressions. |

### Low

| # | Finding | Table | Impact |
|---|---------|-------|--------|
| 7 | Only 24.8% of customers are Active; all have transactions. | CUSTOMERS | May need business validation -- should Closed/Dormant customers still transact? |
| 8 | All categorical distributions are near-uniform. | ALL | Suggests synthetic data; real-world skew should be expected in production. |

---

## 7. Recommendations

### Immediate (Pre-Modeling)

1. **Resolve TRANSACTION_ID duplicates.** Generate a surrogate key using `dbt_utils.generate_surrogate_key` over all columns (or a meaningful business composite key) in the staging model `stg_transactions`. Do not rely on TRANSACTION_ID alone as PK.

2. **Resolve ALERT_ID duplicates.** Same approach -- use a surrogate key in `stg_compliance_alerts`.

3. **Handle orphan alerts.** In the staging model, flag or filter the 50 alerts with invalid CUSTOMER_IDs. Consider a left-join approach with a `is_customer_valid` flag rather than silently dropping rows.

4. **Clarify negative amount semantics.** Confirm with the data source team whether negative amounts represent reversals, refunds, or data errors. If they are valid debits, add a `transaction_direction` column in staging. If errors, filter them out.

### Short-Term (Modeling Phase)

5. **Add dbt tests for all primary keys:**
   ```yaml
   - unique
   - not_null
   - relationships (customer_id -> customers)
   ```

6. **Add `transaction_id` to COMPLIANCE_ALERTS** at the source level, or create an intermediate model that links alerts to transactions by customer + date proximity.

7. **Add accepted_values tests** for all categorical columns to catch unexpected values in future loads.

### Ongoing

8. **Implement freshness checks** via `dbt source freshness` to detect stale data.

9. **Add constraints as documentation** in Snowflake (`ALTER TABLE ... ADD PRIMARY KEY ... NOT ENFORCED`) to support query optimization and serve as schema documentation.

---

## Appendix: Query Inventory

All profiling queries were executed via `sql_execute` against connection `HQ84620` on 2026-04-25. Queries covered:
- INFORMATION_SCHEMA metadata
- DESCRIBE TABLE
- NULL rate analysis (COUNT + CASE WHEN)
- Distinct value counts (COUNT DISTINCT)
- Numeric statistics (MIN, MAX, AVG, MEDIAN, STDDEV)
- Primary key duplicate detection (GROUP BY + HAVING)
- Outlier detection (3 std dev threshold)
- Categorical value distributions (GROUP BY + COUNT)
- Future date checks (WHERE date > CURRENT_DATE)
- Referential integrity (LEFT JOIN + NULL check)
- Negative amount analysis by transaction type
