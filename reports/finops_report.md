# Snowflake FinOps Report - 30-Day Analysis

**Account:** HQ84620
**Report Period:** March 26, 2026 - April 25, 2026
**Generated:** April 25, 2026

---

## Executive Summary

| Metric | Value |
|---|---|
| **Total Credits Consumed** | 0.431 |
| **Compute Credits** | 0.428 |
| **Cloud Services Credits** | 0.003 |
| **Active Warehouses** | 3 |
| **Active Days (with usage)** | 7 out of 30 |
| **Estimated Monthly Cost (@$3/credit)** | ~$1.29 |

This is a low-usage development/demo account. Usage is highly intermittent (active only 7 of 30 days), which is appropriate for a PoC environment. However, there are still optimization opportunities.

---

## 1. Credit Consumption by Warehouse

| Warehouse | Credits Used | % of Total |
|---|---|---|
| COMPUTE_WH | 0.371 | 86.1% |
| FINANCE_DEMO_WH | 0.060 | 13.9% |
| CLOUD_SERVICES_ONLY | 0.000058 | <0.1% |

**Key Finding:** `COMPUTE_WH` is the dominant consumer at 86% of all credits. This is the default warehouse and handles the bulk of workloads.

---

## 2. Warehouse Configuration Audit

| Warehouse | Size | Auto-Suspend | Auto-Resume | Scaling | Gen |
|---|---|---|---|---|---|
| COMPUTE_WH | X-Small | 300s (5 min) | Yes | 1-1 (Standard) | Gen2 |
| FINANCE_DEMO_WH | X-Small | 60s (1 min) | Yes | 1-1 (Standard) | Gen2 |
| SYSTEM$STREAMLIT_NOTEBOOK_WH | X-Small | 60s (1 min) | Yes | 1-10 (Standard) | Gen1 |

**Issues Identified:**

- **COMPUTE_WH auto-suspend is 300 seconds (5 min).** For a dev/demo account, this is unnecessarily long. Each idle minute on an X-Small warehouse costs ~0.0167 credits.
- **SYSTEM$STREAMLIT_NOTEBOOK_WH** has multi-cluster scaling (1-10) enabled, which is unnecessary for a demo account and could cause unexpected costs if many sessions open concurrently.

---

## 3. Daily Credit Trend

| Date | Credits | Anomaly? |
|---|---|---|
| Apr 15 | 0.114 | No |
| Apr 18 | 0.176 | **YES (2.85x avg)** |
| Apr 19 | 0.000133 | No |
| Apr 21 | 0.000049 | No |
| Apr 23 | 0.141 | **YES (2.28x avg)** |
| Apr 24 | 0.000426 | No |
| Apr 25 | 0.000042 | No |

**Daily Average:** 0.062 credits/day (active days only)

### Anomaly Analysis

Two days exceeded 2x the daily average:

1. **April 18 (2.85x avg):** 0.176 credits - likely initial setup/data loading for FINANCE_DEMO project. The FINANCE_DEMO_WH was created on this date.
2. **April 23 (2.28x avg):** 0.141 credits - a significant work session on COMPUTE_WH.

These spikes are consistent with interactive development sessions rather than runaway processes.

---

## 4. Top Consuming Queries

All top 20 longest-running queries executed on `COMPUTE_SERVICE_WH_USER_TASKS_POOL_XSMALL_0` (a system-managed compute pool), with elapsed times ranging from **31 to 342 seconds**. These are internal Snowflake system tasks, not user-initiated queries.

| Rank | Elapsed (sec) | Warehouse | Status |
|---|---|---|---|
| 1 | 342 | COMPUTE_SERVICE_WH (system) | SUCCESS |
| 2 | 287 | COMPUTE_SERVICE_WH (system) | SUCCESS |
| 3 | 274 | COMPUTE_SERVICE_WH (system) | SUCCESS |
| 4 | 264 | COMPUTE_SERVICE_WH (system) | SUCCESS |
| 5 | 241 | COMPUTE_SERVICE_WH (system) | SUCCESS |

**Key Finding:** The longest queries are all system-level tasks running on Snowflake's internal compute service pool. No user-initiated queries appear in the top 20 longest-running, which means user queries are running efficiently.

---

## 5. Usage by User

| User | Query Count | Total Elapsed (sec) | % of Total Time |
|---|---|---|---|
| SYSTEM | 5,856 | 6,913 | 98.9% |
| SAURABH120A | 706 | 80 | 1.1% |
| FIRST_USER | 4 | 0.4 | <0.1% |

**Key Finding:** 98.9% of query elapsed time is from the `SYSTEM` user (internal background tasks). Actual user queries (SAURABH120A) are lightweight at 80 seconds total across 706 queries, averaging 0.11 seconds per query.

---

## 6. Serverless & Managed Services

| Service | Activity |
|---|---|
| Serverless Tasks | None |
| Snowpipe | None |
| Materialized Views | None |

No serverless credit consumption detected. This is expected for a development/demo account.

---

## 7. Storage Usage

| Date | Storage (MB) | Stage (KB) | Failsafe (MB) |
|---|---|---|---|
| Apr 25 | 6.57 | 9.6 | 1.35 |
| Apr 23 | 6.66 | 9.6 | 1.23 |
| Apr 21 | 7.84 | 9.6 | 0.01 |
| Apr 18 | 5.57 | 4.3 | 0.01 |
| Apr 15 | 0.95 | 0.0 | 0.00 |

**Storage Trend:** Total storage grew from 0 MB to ~6.6 MB over the period, consistent with initial project setup. Failsafe storage increased to 1.35 MB after data changes (DML operations on Apr 22-24). Storage costs are negligible at this scale (~$23/TB/month = effectively $0.00).

---

## 8. Cost Optimization Recommendations

### Recommendation 1: Reduce COMPUTE_WH Auto-Suspend to 60 Seconds
**Impact: ~15-20% credit savings on COMPUTE_WH**

The default `COMPUTE_WH` has a 5-minute auto-suspend. For interactive development, 60 seconds is sufficient.

```sql
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;
```

**Estimated Savings:** With intermittent dev usage, reducing idle time from 5 min to 1 min per session saves ~0.067 credits per resume cycle. Across multiple sessions, this could reduce COMPUTE_WH usage by 15-20%.

### Recommendation 2: Cap Multi-Cluster on SYSTEM$STREAMLIT_NOTEBOOK_WH
**Impact: Prevents unexpected cost spikes**

The Streamlit/Notebook warehouse can scale to 10 clusters. For a demo account, cap it at 1-2.

```sql
ALTER WAREHOUSE SYSTEM$STREAMLIT_NOTEBOOK_WH SET MAX_CLUSTER_COUNT = 2;
```

**Estimated Savings:** Prevents potential 10x cost multiplier during concurrent sessions.

### Recommendation 3: Set Up a Resource Monitor
**Impact: Cost governance / alerting**

No resource monitors are configured. Add one to get notified and suspend at a threshold.

```sql
CREATE RESOURCE MONITOR demo_monitor
  WITH CREDIT_QUOTA = 10
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = demo_monitor;
ALTER WAREHOUSE FINANCE_DEMO_WH SET RESOURCE_MONITOR = demo_monitor;
```

### Recommendation 4: Use FINANCE_DEMO_WH Consistently for Project Work
**Impact: Better cost attribution**

Currently, 86% of credits are on `COMPUTE_WH` (the default). Routing dbt/project workloads to `FINANCE_DEMO_WH` improves cost attribution and allows independent monitoring.

```sql
-- In dbt profiles.yml, ensure:
-- warehouse: FINANCE_DEMO_WH
```

### Recommendation 5: Suspend Unused Warehouses When Idle for Extended Periods
**Impact: Prevents accidental credit burn**

While auto-suspend is configured, consider suspending warehouses at end-of-day for a demo account:

```sql
ALTER WAREHOUSE COMPUTE_WH SUSPEND;
ALTER WAREHOUSE FINANCE_DEMO_WH SUSPEND;
```

---

## Summary of Savings Potential

| Recommendation | Estimated Savings | Priority |
|---|---|---|
| Reduce COMPUTE_WH auto-suspend to 60s | 15-20% of warehouse credits | High |
| Cap multi-cluster to 2 | Prevents up to 10x cost spikes | Medium |
| Add resource monitor | Cost governance (no direct savings) | High |
| Use FINANCE_DEMO_WH for project work | Better attribution | Low |
| Suspend warehouses when not in use | Prevents idle burn | Low |

**Overall Assessment:** This account is well within normal bounds for a development/demo environment. Total 30-day cost is ~$1.29. The recommendations above are primarily about establishing good FinOps hygiene now so these practices scale when workloads grow to production volumes.

---

*Report generated by Cortex Code FinOps Analysis*
