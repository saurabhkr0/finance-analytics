# Snowflake FinOps Report - Last 30 Days
**Report Generated:** September 10, 2026  
**Analysis Period:** August 11, 2026 - September 10, 2026

---

## Executive Summary

**Total Credits Consumed:** 15.20 credits  
**Active Days:** 9 days with measurable activity  
**Active Warehouses:** 4 warehouses  
**Primary Cost Driver:** Snowflake CoCo CLI (51.03% of total consumption)

---

## 1. Credit Consumption by Service Type

| Service Type | Credits Used | % of Total |
|--------------|-------------|------------|
| Snowflake CoCo CLI | 7.75 | 51.03% |
| Warehouse Metering | 4.07 | 26.76% |
| Snowflake CoCo Desktop | 2.87 | 18.90% |
| Snowflake CoCo Snowsight | 0.42 | 2.79% |
| Trust Center | 0.08 | 0.52% |
| Telemetry Data Ingest | 0.00 | 0.01% |
| Pipe | 0.00 | 0.00% |

**Key Findings:**
- CoCo services (CLI, Desktop, Snowsight) account for **72.72%** of total credits
- Traditional warehouse compute represents only 26.76%
- Minimal serverless feature usage (Trust Center, Pipes)

---

## 2. Warehouse-Level Analysis

### Credit Usage by Warehouse

| Warehouse | Total Credits | Days Used | Avg Credits/Day |
|-----------|--------------|-----------|-----------------|
| COMPUTE_WH | 3.64 | 9 | 0.40 |
| DEMO_WH | 0.35 | 1 | 0.35 |
| FINANCE_DEMO_WH | 0.08 | 1 | 0.08 |
| CLOUD_SERVICES_ONLY | 0.00 | 3 | 0.00 |

### Warehouse Efficiency Metrics

| Warehouse | Total Credits | Total Queries | Credits/Query | Avg Query Time (sec) |
|-----------|--------------|---------------|---------------|---------------------|
| COMPUTE_WH | 1,456.10 | 2,679 | 0.5435 | 0.25 |
| DEMO_WH | 13.49 | 39 | 0.3459 | 0.61 |
| FINANCE_DEMO_WH | 3.20 | 39 | 0.0820 | 0.23 |

**Key Findings:**
- **COMPUTE_WH** is the primary warehouse with highest usage (89.7% of warehouse credits)
- **FINANCE_DEMO_WH** shows excellent efficiency at 0.082 credits/query
- **DEMO_WH** has higher per-query cost and slower execution times

---

## 3. Daily Credit Trend

| Date | Daily Credits | Active Warehouses |
|------|--------------|-------------------|
| 2026-08-18 | 0.0001 | 2 |
| 2026-08-19 | 1.2507 | 3 |
| 2026-09-03 | 0.2261 | 1 |
| 2026-09-04 | 0.2438 | 2 |
| 2026-09-05 | 1.3562 | 2 |
| 2026-09-06 | 0.2260 | 1 |
| 2026-09-08 | 0.0004 | 1 |
| 2026-09-09 | 0.0001 | 1 |
| 2026-09-10 | 0.7634 | 1 |

**Key Findings:**
- Peak usage days: Aug 19 (1.25 credits) and Sep 5 (1.36 credits)
- 21 days with zero activity in the 30-day period
- Sporadic usage pattern suggests development/testing workload

---

## 4. User Activity Analysis

### Top Users by Query Volume

| User | Total Queries | Cloud Services Credits | Avg Execution (sec) |
|------|--------------|----------------------|---------------------|
| SYSTEM | 45,637 | 0.000000 | 0.96 |
| SAURABH120S | 2,673 | 0.011277 | 0.04 |
| FINANCE_CI_USER | 122 | 0.013311 | 0.81 |
| FIRST_USER | 5 | 0.000091 | 0.02 |

**Key Findings:**
- SYSTEM account dominates query volume (94.5% of queries)
- SAURABH120S is the primary human user with efficient query patterns (0.04s avg)
- FINANCE_CI_USER shows higher execution times, likely running integration tests

---

## 5. Query Pattern Analysis

### Query Types by Volume

| Query Type | Count | Avg Execution (sec) | Avg MB Scanned | Cloud Credits |
|------------|-------|---------------------|----------------|---------------|
| SELECT | 23,914 | 0.08 | 2.40 | 0.017614 |
| GRANT | 8,984 | 0.01 | 0.00 | 0.000493 |
| CALL | 7,943 | 5.23 | 0.00 | 0.000000 |
| CREATE | 4,509 | 0.03 | 0.00 | 0.000462 |
| ALTER | 773 | 0.06 | 0.00 | 0.000052 |
| SHOW | 372 | 0.11 | 0.00 | 0.001610 |
| MERGE | 305 | 0.36 | 0.01 | 0.000000 |
| BEGIN_TRANSACTION | 252 | 0.06 | 0.00 | 0.000000 |
| COMMIT | 252 | 0.45 | 0.00 | 0.000000 |
| UPDATE | 219 | 0.32 | 0.10 | 0.000279 |

**Key Findings:**
- **CALL** statements are the slowest (5.23s avg) - investigate stored procedures
- SELECTs are efficient at 0.08s average
- Heavy DDL activity (CREATE, ALTER) suggests development environment
- Low data scanning volumes indicate good query optimization

---

## 6. Cost Optimization Recommendations

### High Priority (Immediate Action)

1. **Optimize CALL Statement Performance**
   - **Impact:** High - 7,943 calls averaging 5.23 seconds
   - **Action:** Review and optimize stored procedures, consider breaking into smaller units
   - **Estimated Savings:** 20-30% reduction in execution time

2. **Right-size DEMO_WH**
   - **Impact:** Medium - 0.3459 credits/query vs 0.0820 for FINANCE_DEMO_WH
   - **Action:** Reduce DEMO_WH size or consolidate workloads to FINANCE_DEMO_WH
   - **Estimated Savings:** 0.20 credits over 30 days (potential 58% improvement)

3. **Implement Auto-Suspend for COMPUTE_WH**
   - **Impact:** Medium - Primary warehouse consuming 89.7% of warehouse credits
   - **Action:** Set auto-suspend to 60 seconds if not already configured
   - **Estimated Savings:** 10-15% on warehouse costs

### Medium Priority (Within 30 Days)

4. **Consolidate Sporadic Workloads**
   - **Impact:** Medium - 21 days with zero activity
   - **Action:** Schedule batch jobs to run on specific days, use task scheduling
   - **Estimated Savings:** Improved cost predictability

5. **Review CoCo CLI Usage**
   - **Impact:** Medium - 51% of total costs
   - **Action:** Audit CoCo CLI operations, consider consolidating development sessions
   - **Estimated Savings:** 10-20% through better session management

6. **Monitor FINANCE_CI_USER Execution Times**
   - **Impact:** Low-Medium - 0.81s avg vs 0.04s for main user
   - **Action:** Optimize CI/CD pipeline queries, implement query result caching
   - **Estimated Savings:** Faster builds, reduced pipeline costs

### Low Priority (Continuous Improvement)

7. **Implement Query Result Caching**
   - **Impact:** Low - SELECTs already efficient at 0.08s
   - **Action:** Enable result cache for frequently-run queries
   - **Estimated Savings:** 5-10% on SELECT operations

8. **Set Up Resource Monitors**
   - **Impact:** Preventative
   - **Action:** Create budget alerts at 80% and 100% of monthly target
   - **Estimated Savings:** Avoid unexpected overspend

---

## 7. Projected Monthly Costs

Based on 30-day analysis:
- **Current Run Rate:** 15.20 credits/30 days
- **Monthly Projection:** ~15.20 credits/month
- **With Optimizations:** 11-13 credits/month (20-30% savings potential)

---

## 8. Next Steps

1. **Week 1:** Investigate and optimize CALL statements (stored procedures)
2. **Week 2:** Right-size or consolidate DEMO_WH workloads
3. **Week 3:** Implement auto-suspend policies and resource monitors
4. **Week 4:** Review CoCo CLI usage patterns and consolidate sessions
5. **Ongoing:** Monitor daily credit consumption and track against targets

---

## Appendix: Methodology

This analysis is based on:
- `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY` (warehouse credits)
- `SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY` (service-level credits)
- `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` (query patterns and efficiency)

All data covers the period from August 11, 2026 to September 10, 2026 (30 days).

---

**Report prepared by Cortex Code FinOps Analyst**
