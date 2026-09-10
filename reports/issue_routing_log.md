# Issue Routing Log

**Generated:** September 10, 2026  
**Routing Agent:** issue-router  
**Reports Analyzed:** 4 (Data Quality, dbt Optimization, RBAC Audit, FinOps)

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Findings** | 22 |
| **Critical Severity (→ GitHub)** | 6 |
| **High Severity (→ GitHub)** | 6 |
| **Medium Severity (→ Jira)** | 10 |
| **Slack Notification** | 1 summary message |

---

## Routing Rules Applied

| Severity | Destination | Rationale |
|----------|-------------|-----------|
| Critical | GitHub Issues | Immediate attention required, blocks production deployment |
| High | GitHub Issues | Significant impact, should be addressed before production |
| Medium | Jira Tickets | Important but not blocking, can be scheduled |
| Low | Documentation | For future reference, no immediate action |
| Summary | Slack | Team-wide visibility and awareness |

---

## GitHub Issues (Critical + High Priority)

### Critical Issues (6 total)

#### GitHub Issue #1: [CRITICAL] TRANSACTION_ID Not Unique - 116K Duplicate Rows
**Source:** Data Quality Report  
**Severity:** Critical  
**Table:** TRANSACTIONS  
**Description:**
TRANSACTION_ID has 97,143 duplicate groups producing 116,790 excess rows. These are distinct transactions sharing the same ID, not exact duplicates. Maximum duplication is 7 rows for a single ID.

**Impact:**
Any downstream model treating TRANSACTION_ID as a primary key will produce incorrect results in joins, aggregations, and incremental loads.

**Recommendation:**
Generate surrogate key using `dbt_utils.generate_surrogate_key` over all columns in `stg_transactions`.

**Labels:** `critical`, `data-quality`, `blocking`

---

#### GitHub Issue #2: [CRITICAL] ALERT_ID Not Unique - 482 Duplicate Rows
**Source:** Data Quality Report  
**Severity:** Critical  
**Table:** COMPLIANCE_ALERTS  
**Description:**
ALERT_ID has 468 duplicate groups producing 482 excess rows. Maximum duplication is 3 rows for a single ID.

**Impact:**
PK-based joins and deduplication logic will lose or duplicate data.

**Recommendation:**
Use surrogate key approach in `stg_compliance_alerts`.

**Labels:** `critical`, `data-quality`, `blocking`

---

#### GitHub Issue #3: [CRITICAL] profiles.yml Uses ACCOUNTADMIN Role
**Source:** dbt Optimization Report  
**File:** `profiles.yml:13`  
**Severity:** Critical  
**Description:**
The dbt profile is configured with `role: ACCOUNTADMIN`, a superuser role that should never be used for routine operations.

**Impact:**
Violates principle of least privilege. Security risk if credentials leak.

**Recommendation:**
Create dedicated `FINANCE_DBT_ROLE` with minimal grants:
- USAGE on warehouse/database
- CREATE TABLE/VIEW on target schemas
- SELECT on RAW schema

Update `profiles.yml` accordingly.

**Labels:** `critical`, `security`, `dbt`, `blocking`

---

#### GitHub Issue #4: [CRITICAL] Password Authentication in profiles.yml
**Source:** dbt Optimization Report  
**File:** `profiles.yml:8`  
**Severity:** Critical  
**Description:**
Authentication uses password field with environment variable. Key-pair authentication is more secure and Snowflake-recommended for service accounts.

**Impact:**
Less secure than key-pair auth, especially for CI/CD.

**Recommendation:**
Switch to key-pair authentication using `private_key_path` or `private_key_passphrase`.

**Labels:** `critical`, `security`, `dbt`, `auth`

---

#### GitHub Issue #5: [CRITICAL] Production Database Owned by ACCOUNTADMIN
**Source:** RBAC Audit Report  
**Database:** FINANCE_DEMO  
**Severity:** Critical  
**Description:**
Production database `FINANCE_DEMO` is owned by ACCOUNTADMIN instead of SYSADMIN.

**Impact:**
Violates separation of duties principle. Operational tasks require unnecessary privilege elevation.

**Recommendation:**
```sql
GRANT OWNERSHIP ON DATABASE FINANCE_DEMO TO ROLE SYSADMIN;
```

**Labels:** `critical`, `security`, `rbac`, `governance`

---

#### GitHub Issue #6: [CRITICAL] Production Warehouse Owned by ACCOUNTADMIN
**Source:** RBAC Audit Report  
**Warehouse:** FINANCE_DEMO_WH  
**Severity:** Critical  
**Description:**
Production warehouse `FINANCE_DEMO_WH` is owned by ACCOUNTADMIN.

**Impact:**
Operational tasks require ACCOUNTADMIN elevation, violating least privilege.

**Recommendation:**
```sql
GRANT OWNERSHIP ON WAREHOUSE FINANCE_DEMO_WH TO ROLE SYSADMIN;
```

**Labels:** `critical`, `security`, `rbac`, `governance`

---

### High Priority Issues (6 total)

#### GitHub Issue #7: [HIGH] 50 Orphaned Compliance Alerts
**Source:** Data Quality Report  
**Severity:** High  
**Table:** COMPLIANCE_ALERTS  
**Description:**
50 compliance alerts reference 47 customer IDs that don't exist in CUSTOMERS table.

**Impact:**
Inner joins to CUSTOMERS will silently drop these alerts, losing compliance data.

**Recommendation:**
In staging model, flag orphaned records with `is_customer_valid` flag rather than dropping. Use left join approach.

**Labels:** `high`, `data-quality`, `compliance`

---

#### GitHub Issue #8: [HIGH] 20% of Transactions Have Negative Amounts
**Source:** Data Quality Report  
**Severity:** High  
**Table:** TRANSACTIONS  
**Description:**
100,571 rows (20.1%) have negative amounts ranging from -500.00 to -0.01, spread uniformly across ALL transaction types including Deposits, Dividends, and Interest.

**Impact:**
- Financial aggregations may be understated
- Negative deposits/dividends are semantically invalid
- Suggests sign is random rather than encoding debits/credits

**Recommendation:**
Clarify with data source team whether negatives represent reversals, refunds, or errors. Add `transaction_direction` column if valid, or filter if errors.

**Labels:** `high`, `data-quality`, `finance`

---

#### GitHub Issue #9: [HIGH] CUSTOMERS Source Freshness Field Is Business Date
**Source:** dbt Optimization Report  
**File:** `src_finance.yml:19`  
**Severity:** High  
**Table:** CUSTOMERS  
**Description:**
`loaded_at_field` for CUSTOMERS source is set to `ONBOARDING_DATE` (a business date), not an ETL timestamp.

**Impact:**
Freshness checks will incorrectly report stale data once all historical customers are onboarded.

**Recommendation:**
- Add metadata column `_LOADED_AT` to raw ingestion pipeline, OR
- Remove `loaded_at_field` from CUSTOMERS and document freshness is not monitored

**Labels:** `high`, `dbt`, `data-quality`, `freshness`

---

#### GitHub Issue #10: [HIGH] Intermediate Models Lack Tests
**Source:** dbt Optimization Report  
**Files:** `int__models.yml`  
**Severity:** High  
**Models:** `int_transactions__daily_summary`, `int_compliance_alerts__enriched`  
**Description:**
Neither intermediate model has column-level tests defined.

**Impact:**
Transformation bugs caught later than necessary, even though models are ephemeral.

**Recommendation:**
Add `not_null` tests on key columns:
- `int_transactions__daily_summary`: `transaction_date`, `business_line`, `branch_city`
- `int_compliance_alerts__enriched`: `surrogate_alert_key`, `alert_id`, `alert_date`, `customer_id`

**Labels:** `high`, `dbt`, `testing`

---

#### GitHub Issue #11: [HIGH] mart_compliance_dashboard Missing cluster_by
**Source:** dbt Optimization Report  
**File:** `mart_compliance_dashboard.sql:2-4`  
**Severity:** High  
**Description:**
Per AGENTS.md convention, large mart tables should use `cluster_by`. While 10K rows is small now, compliance dashboard is queried by `alert_date` and `alert_severity`.

**Impact:**
Suboptimal query performance as data grows.

**Recommendation:**
Add to model config:
```yaml
cluster_by: ['alert_date']
# OR
cluster_by: ['alert_severity', 'alert_date']
```

**Labels:** `high`, `dbt`, `performance`, `optimization`

---

#### GitHub Issue #12: [HIGH] Monetary Columns Missing not_null Tests
**Source:** dbt Optimization Report  
**File:** `marts__models.yml:25-34`  
**Severity:** High  
**Model:** `mart_daily_transaction_summary`  
**Description:**
Monetary columns `total_credit_amount`, `total_debit_amount`, `net_flow`, `average_transaction_amount` have descriptions but no tests.

**Impact:**
No validation on critical financial metrics that should never be NULL.

**Recommendation:**
Add `not_null` tests on all four monetary columns.

**Labels:** `high`, `dbt`, `testing`, `finance`

---

## Jira Tickets (Medium Priority)

### Jira Ticket FINANCE-001: Missing TRANSACTION_ID Column in COMPLIANCE_ALERTS
**Source:** Data Quality Report  
**Severity:** Medium  
**Table:** COMPLIANCE_ALERTS  
**Description:**
COMPLIANCE_ALERTS table has no TRANSACTION_ID column. The expected FK relationship `COMPLIANCE_ALERTS.transaction_id → TRANSACTIONS.transaction_id` cannot be validated.

**Impact:**
Alerts are linked to customers but not to specific transactions. Investigation and lineage are limited.

**Recommendation:**
- Add `transaction_id` at source level, OR
- Create intermediate model linking alerts to transactions by customer + date proximity

**Labels:** `medium`, `data-quality`, `schema`, `compliance`

---

### Jira Ticket FINANCE-002: No PK/UK/NOT NULL Constraints Defined
**Source:** Data Quality Report  
**Severity:** Medium  
**Tables:** ALL (TRANSACTIONS, CUSTOMERS, COMPLIANCE_ALERTS)  
**Description:**
None of the three tables have primary key, unique key, or check constraints defined in Snowflake. All columns are nullable.

**Impact:**
No guardrails against future data quality regressions. No optimization hints for query planner.

**Recommendation:**
Add constraints as documentation (NOT ENFORCED):
```sql
ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
  ADD PRIMARY KEY (TRANSACTION_ID) NOT ENFORCED;
```

**Labels:** `medium`, `data-quality`, `schema`, `governance`

---

### Jira Ticket FINANCE-003: Marts Landing in PUBLIC Schema
**Source:** dbt Optimization Report  
**Severity:** Medium  
**File:** `dbt_project.yml:33-34`  
**Description:**
Staging models target `+schema: staging`, but marts land in default PUBLIC schema.

**Impact:**
Messy warehouse layout, no separation between layers.

**Recommendation:**
Add to `dbt_project.yml`:
```yaml
marts:
  +schema: analytics  # or 'marts'
```

**Labels:** `medium`, `dbt`, `organization`

---

### Jira Ticket FINANCE-004: Direct Source Reference Bypasses Staging Layer
**Source:** dbt Optimization Report  
**Severity:** Medium  
**File:** `stg_finance__compliance_alerts.sql:9-13`  
**Description:**
Staging model joins directly to `{{ source('finance_raw', 'CUSTOMERS') }}` instead of using `{{ ref('stg_finance__customers') }}` for customer lookup.

**Impact:**
- Bypasses staging layer's type casting and trimming
- Creates hidden dependency not visible in dbt DAG lineage

**Recommendation:**
Replace direct source reference with `ref('stg_finance__customers')`.

**Labels:** `medium`, `dbt`, `lineage`

---

### Jira Ticket FINANCE-005: Missing Relationships Test on mart_customer_risk_profile
**Source:** dbt Optimization Report  
**Severity:** Medium  
**File:** `marts__models.yml:104-108`  
**Model:** `mart_customer_risk_profile`  
**Description:**
`customer_id` has `unique` and `not_null` tests but no `relationships` test back to `stg_finance__customers`.

**Impact:**
Future logic errors not caught by tests.

**Recommendation:**
Add to YAML:
```yaml
- relationships:
    to: ref('stg_finance__customers')
    field: customer_id
```

**Labels:** `medium`, `dbt`, `testing`

---

### Jira Ticket FINANCE-006: Unclear DEMO_ROLE Privilege Scope
**Source:** RBAC Audit Report  
**Severity:** Medium  
**Role:** DEMO_ROLE  
**Description:**
DEMO_ROLE owns DEMO_DB and DEMO_WH, granted to user who also has ACCOUNTADMIN. Unclear separation between demo and production resources.

**Impact:**
Potential confusion between demo and production environments.

**Recommendation:**
- Clarify purpose and scope of DEMO_ROLE
- Add role comment documenting intended use
- Consider restricting DEMO_DB to separate schema/database

**Labels:** `medium`, `rbac`, `governance`

---

### Jira Ticket FINANCE-007: CI Role Has Production Data Access
**Source:** RBAC Audit Report  
**Severity:** Medium  
**Role:** FINANCE_CI_ROLE  
**Description:**
FINANCE_CI_ROLE has read access to production finance data.

**Impact:**
CI/CD processes have production data access (appropriate if read-only, but requires verification).

**Recommendation:**
- Verify read-only restrictions are enforced
- Audit CI logs to ensure no write operations
- Document access justification

**Labels:** `medium`, `rbac`, `ci-cd`, `audit`

---

### Jira Ticket FINANCE-008: COMPUTE_WH Auto-Suspend Too Long
**Source:** FinOps Report  
**Severity:** Medium  
**Warehouse:** COMPUTE_WH  
**Description:**
Default warehouse COMPUTE_WH has 5-minute auto-suspend. For dev/demo account, this is unnecessarily long.

**Impact:**
15-20% unnecessary credit consumption on idle time.

**Recommendation:**
```sql
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;
```

**Estimated Savings:** ~0.067 credits per session, 15-20% reduction in COMPUTE_WH usage.

**Labels:** `medium`, `finops`, `optimization`, `cost`

---

### Jira Ticket FINANCE-009: Multi-Cluster Scaling Too Aggressive
**Source:** FinOps Report  
**Severity:** Medium  
**Warehouse:** SYSTEM$STREAMLIT_NOTEBOOK_WH  
**Description:**
Streamlit/Notebook warehouse can scale to 10 clusters, unnecessary for demo account.

**Impact:**
Potential 10x cost spike during concurrent sessions.

**Recommendation:**
```sql
ALTER WAREHOUSE SYSTEM$STREAMLIT_NOTEBOOK_WH SET MAX_CLUSTER_COUNT = 2;
```

**Labels:** `medium`, `finops`, `cost`, `risk`

---

### Jira Ticket FINANCE-010: No Resource Monitors Configured
**Source:** FinOps Report  
**Severity:** Medium  
**Description:**
No resource monitors configured for cost governance.

**Impact:**
No alerting or automatic suspension at cost thresholds.

**Recommendation:**
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

**Labels:** `medium`, `finops`, `governance`, `monitoring`

---

## Slack Notification

### Channel: #finance-analytics
**Subject:** 🚨 Finance Analytics Swarm Audit Complete - 22 Findings Require Action

**Message:**
```
🔍 Finance Analytics Platform Audit Results

Our automated swarm analysis has completed across 4 domains:
• Data Quality Inspector
• dbt Project Optimizer
• RBAC Auditor
• FinOps Analyst

📊 Summary:
- 6 Critical findings → Routed to GitHub Issues #1-6
- 6 High priority → Routed to GitHub Issues #7-12
- 10 Medium priority → Routed to Jira FINANCE-001 through FINANCE-010

🔴 Critical Issues Requiring Immediate Attention:
1. TRANSACTION_ID not unique (116K duplicate rows)
2. ALERT_ID not unique (482 duplicate rows)
3. profiles.yml uses ACCOUNTADMIN role
4. Password authentication in dbt profiles
5. Production database owned by ACCOUNTADMIN
6. Production warehouse owned by ACCOUNTADMIN

⚠️ Top High Priority Issues:
- 50 orphaned compliance alerts
- 20% of transactions have negative amounts
- Source freshness field is a business date
- Missing tests on intermediate models

📋 Full Routing Log: reports/issue_routing_log.md
🔗 GitHub Issues: [link to repo issues]
🔗 Jira Board: [link to FINANCE project]

Next Steps:
1. Review and assign GitHub issues #1-6 (Critical)
2. Schedule sprint planning for high priority items
3. Triage Jira backlog for medium priority work

Questions? Tag @data-platform-team
```

**Priority:** High  
**Notification Type:** @channel  
**Follow-up:** Pin message for visibility

---

## Routing Execution Status

### GitHub Issues
**Status:** ⏸️ SIMULATED (no GitHub credentials stored)  
**Action Required:** Run routing script with GitHub token stored via `/secrets`

To execute routing:
```bash
# Store GitHub token
cortex secret store GITHUB_TOKEN --from-env

# Run issue creation script
python scripts/route_to_github.py
```

**Expected GitHub API calls:**
- Create 12 issues (6 Critical + 6 High)
- Apply labels to each issue
- Assign to project board
- Link related issues

---

### Jira Tickets
**Status:** ⏸️ SIMULATED (no Jira credentials stored)  
**Action Required:** Run routing script with Jira credentials stored via `/secrets`

To execute routing:
```bash
# Store Jira credentials
cortex secret store JIRA_TOKEN --from-env
cortex secret store JIRA_URL --from-env

# Run ticket creation script
python scripts/route_to_jira.py
```

**Expected Jira API calls:**
- Create 10 tickets in FINANCE project
- Set priority to Medium
- Add to current sprint backlog
- Link to epic "Platform Audit Q3 2026"

---

### Slack Notification
**Status:** ⏸️ SIMULATED (no Slack credentials stored)  
**Action Required:** Run routing script with Slack webhook URL stored via `/secrets`

To execute routing:
```bash
# Store Slack webhook
cortex secret store SLACK_WEBHOOK --from-env

# Send notification
python scripts/route_to_slack.py
```

**Expected Slack API calls:**
- Post message to #finance-analytics channel
- @channel mention for visibility
- Pin message to channel

---

## Recommendations for Routing Automation

### 1. Store Required Credentials
```bash
# GitHub
cortex secret store GITHUB_TOKEN --from-file ~/.github/token

# Jira
cortex secret store JIRA_TOKEN --from-file ~/.jira/token
cortex secret store JIRA_URL --value "https://yourcompany.atlassian.net"
cortex secret store JIRA_PROJECT --value "FINANCE"

# Slack
cortex secret store SLACK_WEBHOOK --from-file ~/.slack/webhook
```

### 2. Create Routing Scripts
Place routing scripts in `scripts/` directory:
- `route_to_github.py` - Create GitHub issues
- `route_to_jira.py` - Create Jira tickets
- `route_to_slack.py` - Send Slack notification

### 3. Schedule Regular Audits
```bash
# Set up monthly audit + routing automation
cortex automation create "Monthly Finance Audit" \
  --schedule "0 0 1 * *" \
  --command "python scripts/run_audit_swarm.py"
```

---

## Issue Priority Matrix

| Severity | Count | Destination | SLA | Assignment |
|----------|-------|-------------|-----|------------|
| Critical | 6 | GitHub | 24 hours | Platform Lead |
| High | 6 | GitHub | 3 days | Team Sprint |
| Medium | 10 | Jira | 2 weeks | Backlog |
| Low | 0 | Docs | N/A | Reference |

---

## Next Steps

1. ✅ Review this routing log
2. ⏳ Store credentials via `/secrets` command
3. ⏳ Execute routing scripts (GitHub, Jira, Slack)
4. ⏳ Assign Critical issues to immediate sprint
5. ⏳ Schedule High priority items for next sprint
6. ⏳ Triage Medium priority into backlog
7. ⏳ Set up recurring audit automation

---

**Routing Log Complete**  
Generated by: Cortex Code issue-router agent  
Report Date: September 10, 2026  
Routing Mode: Simulated (credentials not configured)
