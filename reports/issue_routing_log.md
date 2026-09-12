# Issue Routing Log

**Generated:** September 12, 2026  
**Routing Status:** BLOCKED - Missing MCP Credentials  
**Reports Analyzed:** 4 (Data Quality, dbt Optimization, FinOps, RBAC Audit)

---

## Executive Summary

This log documents the routing of findings from all report files to appropriate channels based on severity:
- **Critical** findings → GitHub Issues
- **High** findings → Jira Tickets
- **Medium** findings → Slack Notifications

**Total Findings Identified:** 18
- Critical: 6
- High: 5
- Medium: 7

---

## Prerequisites - Action Required

**⚠️ ROUTING BLOCKED:** The following secrets must be stored before routing can proceed:

```bash
# Store GitHub Personal Access Token
cortex secret store github-token --from-file /path/to/token.txt

# Store Jira API credentials (format: email:api_token)
cortex secret store jira-credentials --from-file /path/to/jira-creds.txt

# Store Slack Bot Token
cortex secret store slack-token --from-file /path/to/slack-token.txt
```

Once secrets are stored, re-run this routing workflow.

---

## Findings Summary

### CRITICAL Findings (→ GitHub Issues)

#### From Data Quality Report

1. **TRANSACTION_ID Duplicates**
   - **Severity:** Critical
   - **Description:** 97,143 duplicate TRANSACTION_ID groups producing 116,790 excess rows
   - **Impact:** Any downstream model treating TRANSACTION_ID as PK will produce incorrect results
   - **Table:** FINANCE_DEMO.RAW.TRANSACTIONS
   - **Recommended Action:** Generate surrogate key using dbt_utils.generate_surrogate_key
   - **Target:** GitHub Issue (High Priority Bug)

2. **ALERT_ID Duplicates**
   - **Severity:** Critical
   - **Description:** 468 duplicate ALERT_ID groups producing 482 excess rows
   - **Impact:** PK-based joins and deduplication will lose or duplicate data
   - **Table:** FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
   - **Recommended Action:** Implement surrogate key in stg_compliance_alerts
   - **Target:** GitHub Issue (High Priority Bug)

#### From dbt Optimization Report

3. **Missing Incremental Materialization**
   - **Severity:** Critical
   - **Description:** mart_customer_summary (500K rows) uses table materialization causing full refresh on every run
   - **Impact:** Wasted compute, slow builds, unnecessary costs
   - **Recommended Action:** Convert to incremental with unique_key = 'customer_id'
   - **Target:** GitHub Issue (Performance/Cost)

4. **Cartesian Join Pattern**
   - **Severity:** Critical
   - **Description:** Multiple CTEs with cross joins or incomplete join conditions
   - **Impact:** Exponential row explosion, query failures, excessive compute
   - **Location:** Multiple dbt models
   - **Target:** GitHub Issue (Bug/Critical)

#### From RBAC Audit Report

5. **Production Database Ownership**
   - **Severity:** Critical
   - **Description:** FINANCE_DEMO database owned by ACCOUNTADMIN instead of SYSADMIN
   - **Impact:** Violates separation of duties principle
   - **Recommended Action:** Transfer ownership to SYSADMIN role
   - **Target:** GitHub Issue (Security/Governance)

6. **Production Warehouse Ownership**
   - **Severity:** Critical
   - **Description:** FINANCE_DEMO_WH warehouse owned by ACCOUNTADMIN
   - **Impact:** Operational tasks require ACCOUNTADMIN elevation
   - **Recommended Action:** Transfer ownership to SYSADMIN role
   - **Target:** GitHub Issue (Security/Governance)

---

### HIGH Findings (→ Jira Tickets)

#### From Data Quality Report

1. **Orphan Compliance Alerts**
   - **Severity:** High
   - **Description:** 50 compliance alerts reference 47 customer IDs not in CUSTOMERS table
   - **Impact:** Inner joins to CUSTOMERS will silently drop these alerts
   - **Table:** FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
   - **Recommended Action:** Flag or filter invalid CUSTOMER_IDs in staging model
   - **Target:** Jira Ticket (Data Quality)

2. **Invalid Negative Amounts**
   - **Severity:** High
   - **Description:** 20.1% of transactions have negative amounts, spread uniformly across all types including Deposits
   - **Impact:** Financial aggregations may be understated; semantically invalid
   - **Table:** FINANCE_DEMO.RAW.TRANSACTIONS
   - **Recommended Action:** Clarify negative amount semantics with source team
   - **Target:** Jira Ticket (Data Quality)

#### From dbt Optimization Report

3. **Inefficient CTE Chain**
   - **Severity:** High
   - **Description:** Deep CTE nesting causing redundant scanning and poor query optimization
   - **Impact:** Query execution time 3-5x slower than optimal
   - **Models Affected:** Multiple marts
   - **Recommended Action:** Flatten CTEs or use intermediate ephemeral models
   - **Target:** Jira Ticket (Performance)

#### From FinOps Report

4. **Slow CALL Statements**
   - **Severity:** High
   - **Description:** 7,943 CALL statements averaging 5.23 seconds each
   - **Impact:** 20-30% potential reduction in execution time
   - **Recommended Action:** Review and optimize stored procedures
   - **Target:** Jira Ticket (Performance/Cost)

5. **DEMO_WH Inefficiency**
   - **Severity:** High
   - **Description:** DEMO_WH costs 0.3459 credits/query vs 0.0820 for FINANCE_DEMO_WH
   - **Impact:** 58% improvement potential, 0.20 credits savings over 30 days
   - **Recommended Action:** Right-size or consolidate to FINANCE_DEMO_WH
   - **Target:** Jira Ticket (Cost Optimization)

---

### MEDIUM Findings (→ Slack Notifications)

#### From Data Quality Report

1. **Missing TRANSACTION_ID Column**
   - **Severity:** Medium
   - **Description:** COMPLIANCE_ALERTS has no TRANSACTION_ID column
   - **Impact:** Cannot link alerts to specific transactions
   - **Recommended Action:** Add transaction_id at source level or create linking intermediate model
   - **Channel:** #data-engineering

2. **No Primary Key Constraints**
   - **Severity:** Medium
   - **Description:** No PK/UK/NOT NULL constraints defined on any table
   - **Impact:** No guardrails against future data quality regressions
   - **Recommended Action:** Add constraints as documentation with NOT ENFORCED flag
   - **Channel:** #data-engineering

#### From dbt Optimization Report

3. **Missing Schema Tests**
   - **Severity:** Medium
   - **Description:** Multiple models lack comprehensive schema tests
   - **Impact:** Data quality issues may go undetected
   - **Recommended Action:** Add unique, not_null, and relationships tests
   - **Channel:** #data-quality

#### From FinOps Report

4. **Sporadic Workload Pattern**
   - **Severity:** Medium
   - **Description:** 21 days with zero activity in 30-day period
   - **Impact:** Unpredictable cost patterns
   - **Recommended Action:** Schedule batch jobs on specific days
   - **Channel:** #finops

5. **CoCo CLI High Usage**
   - **Severity:** Medium
   - **Description:** CoCo CLI accounts for 51% of total costs
   - **Impact:** 10-20% savings potential through better session management
   - **Recommended Action:** Audit and consolidate CoCo CLI operations
   - **Channel:** #finops

#### From RBAC Audit Report

6. **DEMO_ROLE Privilege Scope**
   - **Severity:** Medium
   - **Description:** DEMO_ROLE owns DEMO_DB and DEMO_WH with unclear separation from production
   - **Impact:** Potential confusion between demo and production resources
   - **Recommended Action:** Clarify purpose and scope of DEMO_ROLE
   - **Channel:** #security

7. **FINANCE_CI_ROLE Access**
   - **Severity:** Medium
   - **Description:** CI/CD role has read access to production finance data
   - **Impact:** CI logs may contain production data
   - **Recommended Action:** Verify read-only restrictions and audit CI logs
   - **Channel:** #security

---

## Routing Plan (To Execute After Secrets Are Configured)

### Phase 1: GitHub Issues (Critical)

```bash
# Will execute after github-token is stored:
# - Create 6 GitHub Issues with priority labels
# - Tag with appropriate labels: bug, security, performance, cost
# - Assign to relevant teams
# - Link related issues
```

**Issues to Create:**
1. [BUG] Fix TRANSACTION_ID duplicates in RAW.TRANSACTIONS
2. [BUG] Fix ALERT_ID duplicates in RAW.COMPLIANCE_ALERTS
3. [PERFORMANCE] Convert mart_customer_summary to incremental materialization
4. [BUG] Fix cartesian join patterns in dbt models
5. [SECURITY] Transfer FINANCE_DEMO database ownership to SYSADMIN
6. [SECURITY] Transfer FINANCE_DEMO_WH warehouse ownership to SYSADMIN

### Phase 2: Jira Tickets (High)

```bash
# Will execute after jira-credentials are stored:
# - Create 5 Jira tickets in appropriate projects
# - Set priority to High
# - Include detailed descriptions and acceptance criteria
# - Link to relevant documentation
```

**Tickets to Create:**
1. [DATA-QUALITY] Resolve 50 orphan compliance alerts
2. [DATA-QUALITY] Investigate and fix negative transaction amounts
3. [PERFORMANCE] Optimize CTE chains in dbt models
4. [PERFORMANCE] Optimize slow stored procedure CALL statements
5. [FINOPS] Right-size or consolidate DEMO_WH warehouse

### Phase 3: Slack Notifications (Medium)

```bash
# Will execute after slack-token is stored:
# - Post formatted messages to appropriate channels
# - Include actionable recommendations
# - Tag relevant team members
# - Provide links to full reports
```

**Channels and Messages:**
- `#data-engineering`: 2 messages (missing columns, constraints)
- `#data-quality`: 1 message (schema tests)
- `#finops`: 2 messages (sporadic workload, CoCo usage)
- `#security`: 2 messages (DEMO_ROLE scope, CI role access)

---

## Routing Metrics

| Channel | Severity | Count | Status |
|---------|----------|-------|--------|
| GitHub Issues | Critical | 6 | PENDING (secrets required) |
| Jira Tickets | High | 5 | PENDING (secrets required) |
| Slack Notifications | Medium | 7 | PENDING (secrets required) |

**Total Findings Routed:** 0/18 (awaiting credentials)

---

## Next Steps

1. **Immediate:** Store required secrets using the commands in the Prerequisites section
2. **Re-run routing:** Execute the issue-router workflow again after secrets are configured
3. **Monitor:** Track issue resolution in GitHub Projects and Jira dashboards
4. **Follow-up:** Schedule 30-day follow-up to verify critical issues are resolved

---

## Appendix: Routing Logic

### Severity Classification

- **Critical:** Data integrity issues, security violations, major performance blockers
- **High:** Significant data quality issues, performance degradation, cost inefficiencies
- **Medium:** Improvement opportunities, documentation gaps, monitoring needs

### Channel Selection

- **GitHub Issues:** Bugs and features requiring code changes, version control, PR workflows
- **Jira Tickets:** Process-driven work, cross-team coordination, sprint planning
- **Slack Notifications:** FYI items, awareness, quick wins, non-blocking improvements

### Priority Mapping

| Report Severity | GitHub Label | Jira Priority | Slack Urgency |
|----------------|--------------|---------------|---------------|
| Critical | P0, critical | Highest | @channel |
| High | P1, high | High | @here |
| Medium | P2, medium | Medium | Standard mention |

---

**Report Status:** READY FOR EXECUTION (pending secrets)  
**Last Updated:** September 12, 2026  
**Next Review:** After routing completion
