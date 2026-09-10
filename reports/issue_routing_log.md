# Issue Routing Log
**Generated:** September 10, 2026  
**Source Reports:** data_quality_report.md, dbt_optimization_report.md, finops_report.md, rbac_audit_report.md  
**Routing Status:** READY FOR EXECUTION

---

## Executive Summary

This log documents the routing of **22 critical findings** from 4 data platform audit reports to external issue tracking and notification systems based on severity-based routing rules.

### Routing Overview

| Severity | Count | Destination | Issues Created |
|----------|-------|-------------|----------------|
| **Critical** | 6 | GitHub Issues | #1-6 (Pending) |
| **High** | 6 | GitHub Issues | #7-12 (Pending) |
| **Medium** | 10 | Jira Tickets | FINANCE-001 to FINANCE-010 (Pending) |
| **Low** | 0 | Slack #data-platform (N/A - informational only) |

**Total Issues to Create:** 22 (12 GitHub + 10 Jira)

---

## Routing Rules

### Rule 1: Critical Severity → GitHub Issues + Slack Alert
- **Criteria:** Data corruption, security violations, primary key failures, production outages
- **SLA:** 24 hours
- **Labels:** `severity:critical`, `priority:p0`
- **Assignee:** Platform Lead
- **Notification:** Immediate Slack alert to #data-platform-alerts

### Rule 2: High Severity → GitHub Issues + Slack Notification
- **Criteria:** Data integrity issues, performance degradation, cost optimization opportunities
- **SLA:** 3 business days
- **Labels:** `severity:high`, `priority:p1`
- **Assignee:** Team Lead
- **Notification:** Daily digest to #data-platform

### Rule 3: Medium Severity → Jira Tickets
- **Criteria:** Technical debt, best practice violations, optimization suggestions
- **SLA:** 2 weeks
- **Labels:** `type:improvement`, `priority:p2`
- **Assignee:** Sprint Planning (unassigned until prioritization)
- **Notification:** Weekly digest to #data-platform

### Rule 4: Low Severity → Slack Only
- **Criteria:** Informational findings, observations, questions for investigation
- **SLA:** No SLA (informational)
- **Notification:** Include in weekly digest to #data-platform

---

## Prerequisites for Execution

### Required Credentials

To execute this routing plan, the following credentials must be stored via `cortex secret store`:

#### 1. GitHub Personal Access Token
```bash
cortex secret store github_token --from-file ~/.github/token
```
**Required Scopes:** `repo` (full control of private repositories)

#### 2. Jira API Token
```bash
cortex secret store jira_token --from-file ~/.jira/token
```
**Required:** Jira Cloud API token from https://id.atlassian.com/manage-profile/security/api-tokens

#### 3. Jira Configuration
```bash
# Store Jira base URL
cortex secret store jira_base_url --value "https://your-domain.atlassian.net"

# Store Jira user email
cortex secret store jira_email --value "your-email@company.com"

# Store Jira project key
cortex secret store jira_project_key --value "FINANCE"
```

#### 4. Slack Bot Token
```bash
cortex secret store slack_token --from-file ~/.slack/bot_token
```
**Required Scopes:** `chat:write`, `channels:read`

#### 5. Repository Configuration
```bash
# GitHub repository owner
cortex secret store github_owner --value "your-org"

# GitHub repository name
cortex secret store github_repo --value "finance-analytics"
```

### Verification
After storing credentials, verify:
```bash
cortex secret list
```

Expected output:
```
- github_token
- github_owner
- github_repo
- jira_token
- jira_base_url
- jira_email
- jira_project_key
- slack_token
```

---

## Critical Issues (GitHub Issues #1-6)

### Issue #1: TRANSACTION_ID Not Unique - 116,790 Duplicate Rows
**Source:** data_quality_report.md  
**Severity:** Critical  
**Impact:** Data corruption - downstream analytics producing incorrect results  
**SLA:** 24 hours

**Description:**
The `FINANCE_DEMO.RAW.TRANSACTIONS` table has 97,143 transaction IDs that appear multiple times, generating 116,790 excess rows. These are NOT exact duplicates - rows sharing the same TRANSACTION_ID have different dates, amounts, customers, and transaction types. This indicates TRANSACTION_ID is being reused or generated with collisions.

**Impact:**
- Any dbt model using TRANSACTION_ID as a primary key will produce incorrect aggregations
- Incremental loads will fail or produce unpredictable results
- Join operations will create cartesian products
- Compliance reports are unreliable

**Sample Evidence:**
```sql
-- TRANSACTION_ID = 540424 appears 7 times with different customers and amounts
SELECT TRANSACTION_ID, COUNT(*) as duplicate_count
FROM FINANCE_DEMO.RAW.TRANSACTIONS
GROUP BY TRANSACTION_ID
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;
```

**Recommended Remediation:**
```sql
-- Generate surrogate key in staging model
{{ dbt_utils.generate_surrogate_key([
    'transaction_id',
    'transaction_date',
    'customer_id',
    'amount'
]) }} as transaction_sk
```

**dbt Test to Add:**
```yaml
version: 2
models:
  - name: stg_transactions
    columns:
      - name: transaction_sk
        tests:
          - unique
          - not_null
```

**Labels:** `severity:critical`, `data-quality`, `blocking`, `dbt`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 45 (Current)

---

### Issue #2: ALERT_ID Not Unique - 482 Duplicate Rows in Compliance Data
**Source:** data_quality_report.md  
**Severity:** Critical  
**Impact:** Compliance data integrity failure  
**SLA:** 24 hours

**Description:**
The `FINANCE_DEMO.RAW.COMPLIANCE_ALERTS` table has 468 alert IDs that appear 2-3 times, generating 482 excess rows. This violates the expected primary key constraint.

**Impact:**
- Compliance reports may double-count alerts
- Alert status tracking is unreliable
- Regulatory reporting could be inaccurate
- Cannot safely join to other tables on ALERT_ID

**Sample Evidence:**
```sql
SELECT ALERT_ID, COUNT(*) as duplicate_count
FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
GROUP BY ALERT_ID
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 5;
```

**Recommended Remediation:**
```sql
-- In stg_compliance_alerts.sql
WITH deduplicated AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY alert_id 
      ORDER BY alert_date DESC
    ) as rn
  FROM {{ source('raw', 'compliance_alerts') }}
)
SELECT * EXCEPT (rn)
FROM deduplicated
WHERE rn = 1
```

**dbt Test to Add:**
```yaml
version: 2
models:
  - name: stg_compliance_alerts
    columns:
      - name: alert_id
        tests:
          - unique
          - not_null
```

**Labels:** `severity:critical`, `compliance`, `data-quality`, `blocking`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 45 (Current)

---

### Issue #3: ACCOUNTADMIN Role Used in dbt Profiles (Security Violation)
**Source:** dbt_optimization_report.md  
**Severity:** Critical  
**Impact:** Major security violation - overprivileged dbt execution  
**SLA:** 24 hours

**Description:**
The dbt profile `profiles.yml` is configured to use the `ACCOUNTADMIN` role for all environments (dev, CI/CD, production). This violates the principle of least privilege and creates significant security and operational risks.

**Security Risks:**
- dbt models can accidentally drop/alter production databases
- dbt tests run with superuser privileges
- CI/CD pipeline has full account control
- No separation of duties between dev and admin operations
- Audit logs show all activity under ACCOUNTADMIN (poor forensics)

**Current Configuration:**
```yaml
finance_demo:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: FP99918
      role: ACCOUNTADMIN  # ❌ CRITICAL SECURITY ISSUE
      warehouse: FINANCE_DEMO_WH
```

**Recommended Fix:**
```yaml
finance_demo:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: FP99918
      role: TRANSFORMER  # ✅ Least privilege role
      warehouse: FINANCE_DEMO_WH
    prod:
      type: snowflake
      account: FP99918
      role: TRANSFORMER_PROD  # ✅ Production-scoped role
      warehouse: FINANCE_DEMO_WH
```

**Create Appropriate Roles:**
```sql
-- Create least-privilege roles for dbt
USE ROLE SECURITYADMIN;

CREATE ROLE TRANSFORMER COMMENT = 'dbt development role - read/write in DEV schema only';
CREATE ROLE TRANSFORMER_PROD COMMENT = 'dbt production role - read/write in PROD schema only';

GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER_PROD TO ROLE SYSADMIN;

-- Grant necessary privileges
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE FINANCE_DEMO TO ROLE TRANSFORMER;
GRANT USAGE ON WAREHOUSE FINANCE_DEMO_WH TO ROLE TRANSFORMER;
GRANT CREATE SCHEMA ON DATABASE FINANCE_DEMO TO ROLE TRANSFORMER;

-- Grant production access
GRANT USAGE ON DATABASE FINANCE_DEMO TO ROLE TRANSFORMER_PROD;
GRANT USAGE ON WAREHOUSE FINANCE_DEMO_WH TO ROLE TRANSFORMER_PROD;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA FINANCE_DEMO.PROD TO ROLE TRANSFORMER_PROD;
```

**Verification:**
```bash
# Test dbt with new role
dbt run --target dev
dbt test --target dev
```

**Labels:** `severity:critical`, `security`, `compliance`, `dbt`, `rbac`  
**Assignee:** @security-lead  
**Milestone:** Sprint 45 (Current)  
**Related:** Issue #4 (key-pair authentication)

---

### Issue #4: Password Authentication Instead of Key-Pair (Security Risk)
**Source:** dbt_optimization_report.md  
**Severity:** Critical  
**Impact:** Authentication security weakness  
**SLA:** 24 hours

**Description:**
The dbt profile uses password-based authentication instead of key-pair authentication. This is a security vulnerability for automated processes like CI/CD.

**Security Risks:**
- Passwords can be accidentally committed to version control
- No automatic rotation mechanism
- Passwords stored in environment variables are less secure than key files
- Cannot enforce MFA on password-based service accounts
- Does not support OAuth or federated authentication

**Current Configuration:**
```yaml
finance_demo:
  outputs:
    dev:
      authenticator: snowflake  # ❌ Password-based auth
      user: FINANCE_USER
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"  # ❌ Password in env var
```

**Recommended Fix (Key-Pair Authentication):**

**Step 1: Generate Key Pair**
```bash
# Generate private key
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# Generate public key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

**Step 2: Assign Public Key to User**
```sql
USE ROLE ACCOUNTADMIN;

ALTER USER FINANCE_USER SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...';
```

**Step 3: Update dbt Profile**
```yaml
finance_demo:
  outputs:
    dev:
      type: snowflake
      account: FP99918
      user: FINANCE_USER
      private_key_path: /secure/path/rsa_key.p8  # ✅ Key-based auth
      role: TRANSFORMER
      warehouse: FINANCE_DEMO_WH
```

**Step 4: Secure Private Key Storage**
```bash
# Store private key with restricted permissions
chmod 600 /secure/path/rsa_key.p8
chown $USER:$USER /secure/path/rsa_key.p8

# For CI/CD, store as encrypted secret in GitHub/GitLab
```

**Verification:**
```bash
# Test connection with key-pair auth
dbt debug --target dev
```

**Labels:** `severity:critical`, `security`, `authentication`, `dbt`, `ci-cd`  
**Assignee:** @security-lead  
**Milestone:** Sprint 45 (Current)  
**Related:** Issue #3 (ACCOUNTADMIN role)

---

### Issue #5: FINANCE_DEMO Database Owned by ACCOUNTADMIN (RBAC Violation)
**Source:** rbac_audit_report.md  
**Severity:** Critical  
**Impact:** Separation of duties violation  
**SLA:** 24 hours

**Description:**
The production database `FINANCE_DEMO` is owned by the `ACCOUNTADMIN` role instead of `SYSADMIN`. This violates Snowflake's recommended role hierarchy and creates operational and security risks.

**Impact:**
- Operational database tasks (creating schemas, tables) require ACCOUNTADMIN elevation
- No separation between administrative and operational duties
- Increased blast radius for accidental changes
- Audit logs show excessive ACCOUNTADMIN usage
- Violates principle of least privilege

**Current State:**
```sql
SHOW DATABASES LIKE 'FINANCE_DEMO';
-- Owner: ACCOUNTADMIN ❌
```

**Recommended Remediation:**
```sql
USE ROLE ACCOUNTADMIN;

-- Transfer database ownership to SYSADMIN
GRANT OWNERSHIP ON DATABASE FINANCE_DEMO TO ROLE SYSADMIN COPY CURRENT GRANTS;

-- Verify transfer
SHOW DATABASES LIKE 'FINANCE_DEMO';
-- Owner: SYSADMIN ✅
```

**Verification:**
```sql
-- Test that operational tasks work without ACCOUNTADMIN
USE ROLE SYSADMIN;
CREATE SCHEMA FINANCE_DEMO.TEST_SCHEMA;
DROP SCHEMA FINANCE_DEMO.TEST_SCHEMA;
```

**Post-Remediation:**
- Update runbooks to use SYSADMIN for database operations
- Review and update any automation scripts using ACCOUNTADMIN
- Document when ACCOUNTADMIN access is actually required

**Labels:** `severity:critical`, `rbac`, `governance`, `compliance`, `security`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 45 (Current)  
**Related:** Issue #6 (warehouse ownership)

---

### Issue #6: FINANCE_DEMO_WH Warehouse Owned by ACCOUNTADMIN (Privilege Escalation Risk)
**Source:** rbac_audit_report.md  
**Severity:** Critical  
**Impact:** Operational privilege escalation requirement  
**SLA:** 24 hours

**Description:**
The production warehouse `FINANCE_DEMO_WH` is owned by `ACCOUNTADMIN` instead of `SYSADMIN`. This forces operational tasks like resizing, suspending, and monitoring to require ACCOUNTADMIN privileges.

**Impact:**
- Warehouse operations require ACCOUNTADMIN elevation
- Cannot delegate warehouse management to non-admin roles
- Increased security risk from excessive ACCOUNTADMIN usage
- Violates separation of duties principle
- Audit trail pollution

**Current State:**
```sql
SHOW WAREHOUSES LIKE 'FINANCE_DEMO_WH';
-- Owner: ACCOUNTADMIN ❌
```

**Recommended Remediation:**
```sql
USE ROLE ACCOUNTADMIN;

-- Transfer warehouse ownership to SYSADMIN
GRANT OWNERSHIP ON WAREHOUSE FINANCE_DEMO_WH TO ROLE SYSADMIN COPY CURRENT GRANTS;

-- Verify transfer
SHOW WAREHOUSES LIKE 'FINANCE_DEMO_WH';
-- Owner: SYSADMIN ✅
```

**Additional Hardening:**
```sql
-- Create specialized warehouse admin role
USE ROLE SECURITYADMIN;
CREATE ROLE WAREHOUSE_ADMIN COMMENT = 'Manages warehouse operations (resize, suspend, resume)';
GRANT ROLE WAREHOUSE_ADMIN TO ROLE SYSADMIN;

-- Grant warehouse management privileges
USE ROLE ACCOUNTADMIN;
GRANT OPERATE, MODIFY ON WAREHOUSE FINANCE_DEMO_WH TO ROLE WAREHOUSE_ADMIN;
GRANT MONITOR ON WAREHOUSE FINANCE_DEMO_WH TO ROLE WAREHOUSE_ADMIN;
```

**Verification:**
```sql
-- Test warehouse operations without ACCOUNTADMIN
USE ROLE SYSADMIN;
ALTER WAREHOUSE FINANCE_DEMO_WH SET WAREHOUSE_SIZE = MEDIUM;
ALTER WAREHOUSE FINANCE_DEMO_WH SUSPEND;
ALTER WAREHOUSE FINANCE_DEMO_WH RESUME;
```

**Labels:** `severity:critical`, `rbac`, `governance`, `warehouse`, `security`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 45 (Current)  
**Related:** Issue #5 (database ownership)

---

## High Priority Issues (GitHub Issues #7-12)

### Issue #7: 50 Orphan Compliance Alerts (Referential Integrity Failure)
**Source:** data_quality_report.md  
**Severity:** High  
**Impact:** Data integrity issue - compliance alerts reference non-existent customers  
**SLA:** 3 business days

**Description:**
50 compliance alerts in `FINANCE_DEMO.RAW.COMPLIANCE_ALERTS` reference 47 customer IDs that do not exist in the `CUSTOMERS` table. These are orphan records that will be lost in any inner join.

**Impact:**
- Compliance reports may be incomplete
- Cannot trace alerts back to customer profiles
- Regulatory reporting gaps
- Data lineage is broken

**Sample Evidence:**
```sql
-- Find orphan alerts
SELECT ca.ALERT_ID, ca.CUSTOMER_ID, ca.ALERT_TYPE
FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS ca
LEFT JOIN FINANCE_DEMO.RAW.CUSTOMERS c ON ca.CUSTOMER_ID = c.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL;
```

**Recommended Remediation:**

**Option 1: Add is_customer_valid Flag**
```sql
-- In stg_compliance_alerts.sql
WITH validated AS (
  SELECT 
    ca.*,
    CASE 
      WHEN c.customer_id IS NOT NULL THEN TRUE 
      ELSE FALSE 
    END as is_customer_valid
  FROM {{ source('raw', 'compliance_alerts') }} ca
  LEFT JOIN {{ source('raw', 'customers') }} c 
    ON ca.customer_id = c.customer_id
)
SELECT * FROM validated
```

**Option 2: Create Placeholder Customers**
```sql
-- Insert placeholder records for missing customers
INSERT INTO FINANCE_DEMO.RAW.CUSTOMERS (
  CUSTOMER_ID, RISK_RATING, ACCOUNT_STATUS, 
  ONBOARDING_DATE, TOTAL_AUM, CLIENT_SEGMENT
)
SELECT DISTINCT
  ca.CUSTOMER_ID,
  'Unknown' as RISK_RATING,
  'Data Issue' as ACCOUNT_STATUS,
  CURRENT_DATE as ONBOARDING_DATE,
  0.00 as TOTAL_AUM,
  'Unknown' as CLIENT_SEGMENT
FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS ca
LEFT JOIN FINANCE_DEMO.RAW.CUSTOMERS c ON ca.CUSTOMER_ID = c.CUSTOMER_ID
WHERE c.CUSTOMER_ID IS NULL;
```

**dbt Test to Add:**
```yaml
version: 2
models:
  - name: stg_compliance_alerts
    columns:
      - name: customer_id
        tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
```

**Labels:** `severity:high`, `data-quality`, `compliance`, `referential-integrity`  
**Assignee:** @data-engineering-lead  
**Milestone:** Sprint 46

---

### Issue #8: Negative Transaction Amounts in Deposits/Dividends (Data Logic Issue)
**Source:** data_quality_report.md  
**Severity:** High  
**Impact:** Semantically invalid data - negative deposits  
**SLA:** 3 business days

**Description:**
100,571 transactions (20.1%) have negative amounts, including semantically invalid cases like negative Deposits (9,965 rows), Dividends (10,041 rows), and Interest (10,136 rows). Negative amounts are spread uniformly across all transaction types, suggesting random sign assignment rather than meaningful debits/credits.

**Impact:**
- Financial aggregations (total revenue, total deposits) are incorrect
- Negative deposits violate business logic
- Cannot distinguish debits from credits
- Reporting metrics are unreliable

**Sample Evidence:**
```sql
SELECT 
  TRANSACTION_TYPE,
  COUNT(*) as negative_count,
  AVG(AMOUNT) as avg_negative_amount
FROM FINANCE_DEMO.RAW.TRANSACTIONS
WHERE AMOUNT < 0
GROUP BY TRANSACTION_TYPE
ORDER BY negative_count DESC;
```

**Recommended Remediation:**

**Option 1: Add Transaction Direction Column**
```sql
-- In stg_transactions.sql
SELECT
  *,
  CASE 
    WHEN transaction_type IN ('Deposit', 'Dividend', 'Interest') 
      AND amount < 0 THEN 'Credit' -- Flip sign
    WHEN transaction_type IN ('Withdrawal', 'Fee')
      AND amount < 0 THEN 'Debit'
    WHEN amount >= 0 THEN 'Credit'
    ELSE 'Unknown'
  END as transaction_direction,
  
  ABS(amount) as amount_abs,
  
  CASE 
    WHEN transaction_type IN ('Deposit', 'Dividend', 'Interest') 
      THEN ABS(amount)
    WHEN transaction_type IN ('Withdrawal', 'Fee')
      THEN -ABS(amount)
    ELSE amount
  END as amount_normalized
FROM {{ source('raw', 'transactions') }}
```

**Option 2: Flag Invalid Records**
```sql
-- Add data quality flag
SELECT
  *,
  CASE 
    WHEN transaction_type IN ('Deposit', 'Dividend', 'Interest') AND amount < 0 
      THEN TRUE
    ELSE FALSE
  END as is_invalid_negative
FROM {{ source('raw', 'transactions') }}
```

**dbt Test to Add:**
```yaml
version: 2
models:
  - name: stg_transactions
    tests:
      - dbt_expectations.expect_column_values_to_be_between:
          column_name: amount_normalized
          min_value: 0
          where: "transaction_type IN ('Deposit', 'Dividend', 'Interest')"
```

**Investigation Required:**
- Coordinate with source system team to understand sign convention
- Determine if negative amounts represent reversals or errors
- Establish business rules for amount normalization

**Labels:** `severity:high`, `data-quality`, `business-logic`, `investigation-required`  
**Assignee:** @data-engineering-lead  
**Milestone:** Sprint 46

---

### Issue #9: CALL Statements Averaging 5.23 Seconds (Performance Issue)
**Source:** finops_report.md  
**Severity:** High  
**Impact:** Cost and performance - slow stored procedures  
**SLA:** 3 business days

**Description:**
7,943 CALL statements in the last 30 days averaged 5.23 seconds each, making them the slowest query type by far (SELECTs average 0.08s). This indicates stored procedures need optimization.

**Impact:**
- Increased warehouse credit consumption
- Slower data pipelines and ETL processes
- Poor user experience for downstream consumers
- Potential SLA violations

**Cost Impact:**
- 7,943 calls × 5.23 seconds = 41,543 seconds = 11.5 hours of compute
- At current warehouse size, estimated ~1.5 credits wasted on slow procedures

**Sample Query:**
```sql
SELECT 
  query_text,
  execution_time / 1000 as execution_seconds,
  warehouse_name,
  user_name
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_type = 'CALL'
  AND start_time >= DATEADD(day, -30, CURRENT_DATE)
ORDER BY execution_time DESC
LIMIT 20;
```

**Recommended Actions:**

**Step 1: Identify Slowest Procedures**
```sql
-- Find procedures taking > 10 seconds
SELECT 
  REGEXP_SUBSTR(query_text, 'CALL\\s+(\\w+\\.\\w+\\.\\w+)', 1, 1, 'e', 1) as procedure_name,
  COUNT(*) as call_count,
  AVG(execution_time / 1000) as avg_seconds,
  MAX(execution_time / 1000) as max_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_type = 'CALL'
  AND start_time >= DATEADD(day, -30, CURRENT_DATE)
GROUP BY 1
HAVING AVG(execution_time / 1000) > 10
ORDER BY avg_seconds DESC;
```

**Step 2: Optimization Techniques**
- Review procedure logic for unnecessary loops
- Replace cursors with set-based operations
- Add appropriate indexes/clustering keys
- Consider breaking into smaller, parallelizable units
- Use RESULT_SCAN for intermediate results
- Leverage materialized views for pre-aggregations

**Step 3: Monitoring**
```sql
-- Create alert for slow procedures
CREATE OR REPLACE ALERT slow_procedure_alert
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '60 MINUTE'
  IF (EXISTS (
    SELECT 1 
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE query_type = 'CALL'
      AND execution_time > 60000  -- 60 seconds
      AND start_time >= DATEADD(minute, -60, CURRENT_TIMESTAMP)
  ))
  THEN CALL system$send_email(...);
```

**Estimated Savings:**
- Target: Reduce average CALL time from 5.23s to 2.0s (62% improvement)
- Monthly savings: ~1.0 credits (~$2-3 depending on rate)

**Labels:** `severity:high`, `performance`, `cost-optimization`, `stored-procedures`  
**Assignee:** @data-engineering-lead  
**Milestone:** Sprint 46  
**Related:** Issue #10 (warehouse rightsizing)

---

### Issue #10: DEMO_WH Has 4.2x Higher Cost Per Query Than FINANCE_DEMO_WH
**Source:** finops_report.md  
**Severity:** High  
**Impact:** Cost efficiency - warehouse oversized for workload  
**SLA:** 3 business days

**Description:**
`DEMO_WH` costs 0.3459 credits per query compared to 0.0820 for `FINANCE_DEMO_WH` - a 4.2x difference. This suggests DEMO_WH is oversized for its workload.

**Impact:**
- Wasted compute credits on oversized warehouse
- Inefficient resource allocation
- Unnecessary cost

**Cost Analysis:**
- DEMO_WH: 39 queries × 0.3459 credits/query = 13.49 credits total
- FINANCE_DEMO_WH: 39 queries × 0.0820 credits/query = 3.20 credits total
- **Potential savings: 10.29 credits for 39 queries**

**Current Configuration:**
```sql
SHOW WAREHOUSES LIKE 'DEMO_WH';
-- Size: LARGE (8 servers) ❌
```

**Recommended Actions:**

**Option 1: Resize DEMO_WH**
```sql
ALTER WAREHOUSE DEMO_WH SET WAREHOUSE_SIZE = 'SMALL';
```

**Option 2: Consolidate Workloads**
```sql
-- Migrate demo queries to FINANCE_DEMO_WH
-- Update user/role default warehouse
ALTER USER demo_user SET DEFAULT_WAREHOUSE = 'FINANCE_DEMO_WH';

-- Suspend DEMO_WH if no longer needed
ALTER WAREHOUSE DEMO_WH SUSPEND;
```

**Option 3: Right-size Based on Query Profile**
```sql
-- Analyze query complexity for DEMO_WH
SELECT 
  query_type,
  AVG(execution_time / 1000) as avg_seconds,
  AVG(bytes_scanned / 1024 / 1024) as avg_mb_scanned,
  COUNT(*) as query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name = 'DEMO_WH'
  AND start_time >= DATEADD(day, -30, CURRENT_DATE)
GROUP BY query_type;
```

**Monitoring:**
```sql
-- Set up resource monitor
CREATE OR REPLACE RESOURCE MONITOR demo_wh_monitor
  WITH CREDIT_QUOTA = 5
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE DEMO_WH SET RESOURCE_MONITOR = demo_wh_monitor;
```

**Estimated Monthly Savings:**
- Current cost: 0.35 credits × 30 days = 10.5 credits/month
- Optimized cost: 0.08 credits × 30 days = 2.4 credits/month
- **Monthly savings: 8.1 credits (~$16-24 depending on rate)**

**Labels:** `severity:high`, `cost-optimization`, `warehouse`, `finops`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 46

---

### Issue #11: CoCo CLI Consuming 51% of Total Credits (Cost Optimization)
**Source:** finops_report.md  
**Severity:** High  
**Impact:** Cost driver - largest single expense  
**SLA:** 3 business days

**Description:**
Snowflake CoCo CLI consumed 7.75 credits (51.03% of total) in the last 30 days, making it the largest single cost driver ahead of traditional warehouse compute (4.07 credits, 26.76%).

**Impact:**
- High cost for development tool usage
- Potential inefficient session management
- Need to understand and optimize CoCo usage patterns

**Cost Breakdown:**
- **CoCo CLI:** 7.75 credits (51.03%)
- **CoCo Desktop:** 2.87 credits (18.90%)
- **CoCo Snowsight:** 0.42 credits (2.79%)
- **Total CoCo:** 11.04 credits (72.72% of all costs)

**Analysis Required:**
```sql
-- Investigate CoCo usage patterns
SELECT 
  user_name,
  DATE(start_time) as usage_date,
  COUNT(*) as query_count,
  SUM(credits_used_cloud_services) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE '%CORTEX%'
  OR user_name LIKE '%CORTEX%'
  AND start_time >= DATEADD(day, -30, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY total_credits DESC;
```

**Recommended Actions:**

**1. Consolidate Development Sessions**
- Avoid opening multiple concurrent CoCo sessions
- Close idle sessions promptly
- Use shared development environments where appropriate

**2. Optimize Query Patterns**
```sql
-- Identify repeated queries that could be cached
SELECT 
  query_text,
  COUNT(*) as execution_count,
  SUM(credits_used_cloud_services) as total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE user_name = 'CORTEX_USER'
  AND start_time >= DATEADD(day, -30, CURRENT_DATE)
GROUP BY query_text
HAVING COUNT(*) > 5
ORDER BY total_credits DESC;
```

**3. Set CoCo Budget Limits**
```sql
-- Create resource monitor for CoCo usage
CREATE OR REPLACE RESOURCE MONITOR coco_monthly_limit
  WITH CREDIT_QUOTA = 10
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO NOTIFY;
```

**4. Best Practices for Development**
- Use smaller warehouses for exploratory queries (X-SMALL or SMALL)
- Leverage query result caching
- Avoid full table scans during development
- Profile queries before scaling up warehouse size

**Monitoring:**
```sql
-- Weekly CoCo cost report
SELECT 
  DATE_TRUNC('week', start_time) as week_start,
  SUM(credits_used_cloud_services) as weekly_credits,
  COUNT(DISTINCT user_name) as active_users
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE '%CORTEX%'
GROUP BY 1
ORDER BY 1 DESC;
```

**Target:**
- Reduce CoCo costs from 7.75 credits/month to 5.0 credits/month (35% reduction)
- **Estimated savings: 2.75 credits/month (~$5-8)**

**Labels:** `severity:high`, `cost-optimization`, `cortex-code`, `finops`, `development`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 46

---

### Issue #12: No Auto-Suspend Configured for COMPUTE_WH (Cost Leak)
**Source:** finops_report.md  
**Severity:** High  
**Impact:** Idle warehouse consuming credits  
**SLA:** 3 business days

**Description:**
The primary warehouse `COMPUTE_WH` (consuming 89.7% of warehouse credits) may not have auto-suspend configured or the timeout is too long, leading to idle credit consumption.

**Impact:**
- Warehouse continues consuming credits during idle periods
- Estimated 10-15% waste from idle time
- Missed cost optimization opportunity

**Current Configuration:**
```sql
SHOW WAREHOUSES LIKE 'COMPUTE_WH';
-- Check: AUTO_SUSPEND column
```

**Recommended Configuration:**
```sql
-- Set auto-suspend to 60 seconds (aggressive for cost savings)
ALTER WAREHOUSE COMPUTE_WH SET 
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- Alternative: 5 minutes for workloads with frequent bursts
ALTER WAREHOUSE COMPUTE_WH SET 
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;
```

**Cost Impact Analysis:**
```sql
-- Estimate idle time
WITH warehouse_sessions AS (
  SELECT 
    warehouse_name,
    start_time,
    end_time,
    LEAD(start_time) OVER (PARTITION BY warehouse_name ORDER BY start_time) as next_query_start,
    DATEDIFF(second, end_time, LEAD(start_time) OVER (PARTITION BY warehouse_name ORDER BY start_time)) as idle_seconds
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  WHERE warehouse_name = 'COMPUTE_WH'
    AND start_time >= DATEADD(day, -30, CURRENT_DATE)
)
SELECT 
  warehouse_name,
  COUNT(*) as idle_periods,
  SUM(idle_seconds) / 3600 as total_idle_hours,
  AVG(idle_seconds) as avg_idle_seconds
FROM warehouse_sessions
WHERE idle_seconds BETWEEN 60 AND 3600  -- Between 1 min and 1 hour
GROUP BY warehouse_name;
```

**Recommended Auto-Suspend Strategy:**

| Warehouse Type | Auto-Suspend | Reason |
|----------------|--------------|--------|
| **Interactive (BI, ad-hoc)** | 60-300 seconds | Users expect instant results, frequent bursts |
| **ETL/Batch** | 60 seconds | Long-running jobs, infrequent re-activation |
| **Development** | 60 seconds | Sporadic usage, cost-sensitive |
| **CI/CD** | 0 seconds (immediate) | Single job per activation |

**Monitoring:**
```sql
-- Create alert for warehouses running idle
CREATE OR REPLACE ALERT warehouse_idle_alert
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '30 MINUTE'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
    WHERE warehouse_name = 'COMPUTE_WH'
      AND end_time >= DATEADD(minute, -30, CURRENT_TIMESTAMP)
      AND avg_running = 0  -- No queries running
      AND avg_queued_load = 0  -- No queries queued
  ))
  THEN CALL system$send_email(...);
```

**Verification:**
```sql
-- Monitor auto-suspend effectiveness
SELECT 
  warehouse_name,
  DATE(start_time) as date,
  COUNT(*) as suspend_count
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_EVENTS_HISTORY
WHERE event_name = 'AUTO_SUSPEND'
  AND warehouse_name = 'COMPUTE_WH'
  AND start_time >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY 2 DESC;
```

**Estimated Savings:**
- Current waste: ~0.4 credits/day × 30 days = 12 credits/month from idle time
- With auto-suspend (60s): ~0.04 credits/day × 30 days = 1.2 credits/month
- **Monthly savings: 10.8 credits (~$22-32)**

**Labels:** `severity:high`, `cost-optimization`, `warehouse`, `auto-suspend`, `finops`  
**Assignee:** @platform-lead  
**Milestone:** Sprint 46

---

## Medium Priority Issues (Jira Tickets)

### FINANCE-001: COMPLIANCE_ALERTS Missing TRANSACTION_ID Column (Schema Gap)
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** Cannot link alerts to specific transactions  
**SLA:** 2 weeks

**Description:**
The `COMPLIANCE_ALERTS` table has no `TRANSACTION_ID` column, preventing foreign key validation and making it impossible to link alerts to specific transactions for investigation.

**Impact:**
- Cannot trace which transaction triggered an alert
- Incomplete data lineage
- Investigation workflows are manual
- Cannot validate alert business logic against transaction data

**Recommended Solution:**

**Option 1: Add Column at Source** (preferred if source system supports)
```sql
ALTER TABLE FINANCE_DEMO.RAW.COMPLIANCE_ALERTS 
ADD COLUMN TRANSACTION_ID NUMBER(6,0);

-- Backfill historical data if possible
UPDATE FINANCE_DEMO.RAW.COMPLIANCE_ALERTS ca
SET TRANSACTION_ID = (
  SELECT t.TRANSACTION_ID
  FROM FINANCE_DEMO.RAW.TRANSACTIONS t
  WHERE t.CUSTOMER_ID = ca.CUSTOMER_ID
    AND t.TRANSACTION_DATE = ca.ALERT_DATE
  LIMIT 1
);
```

**Option 2: Create Intermediate Mapping Model** (if source cannot be changed)
```sql
-- models/intermediate/int_alerts_with_transactions.sql
WITH transaction_matches AS (
  SELECT 
    ca.*,
    t.transaction_id,
    ROW_NUMBER() OVER (
      PARTITION BY ca.alert_id 
      ORDER BY ABS(DATEDIFF(second, t.transaction_date, ca.alert_date))
    ) as match_rank
  FROM {{ ref('stg_compliance_alerts') }} ca
  LEFT JOIN {{ ref('stg_transactions') }} t
    ON ca.customer_id = t.customer_id
    AND t.transaction_date BETWEEN 
      DATEADD(day, -1, ca.alert_date) AND 
      DATEADD(day, 1, ca.alert_date)
)
SELECT * EXCEPT (match_rank)
FROM transaction_matches
WHERE match_rank = 1
```

**dbt Test:**
```yaml
version: 2
models:
  - name: int_alerts_with_transactions
    columns:
      - name: transaction_id
        tests:
          - not_null:
              where: "status != 'Data Quality Issue'"
```

**Labels:** `type:schema-change`, `data-model`, `compliance`, `enhancement`  
**Assignee:** Unassigned (Sprint Planning)  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-002: No Primary Key Constraints Defined (Schema Documentation)
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** No guardrails for future data quality regressions  
**SLA:** 2 weeks

**Description:**
None of the three RAW tables (`TRANSACTIONS`, `CUSTOMERS`, `COMPLIANCE_ALERTS`) have primary key, unique key, or check constraints defined in Snowflake.

**Impact:**
- No schema-level documentation of intended uniqueness
- Query optimizer cannot leverage constraint metadata
- No guardrails against future duplicate inserts
- DBT tests provide runtime validation but no DDL-level enforcement

**Recommended Solution:**
```sql
-- Add NOT ENFORCED constraints for documentation and query optimization
ALTER TABLE FINANCE_DEMO.RAW.CUSTOMERS 
ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id) NOT ENFORCED;

-- Note: Cannot add PK to TRANSACTIONS or COMPLIANCE_ALERTS 
-- until duplicate issues (#1, #2) are resolved

-- After duplicates are fixed:
ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ADD CONSTRAINT pk_transactions PRIMARY KEY (transaction_id) NOT ENFORCED;

ALTER TABLE FINANCE_DEMO.RAW.COMPLIANCE_ALERTS 
ADD CONSTRAINT pk_compliance_alerts PRIMARY KEY (alert_id) NOT ENFORCED;

-- Add foreign key constraints
ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS
ADD CONSTRAINT fk_trans_customer 
  FOREIGN KEY (customer_id) REFERENCES FINANCE_DEMO.RAW.CUSTOMERS(customer_id) 
  NOT ENFORCED;

ALTER TABLE FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
ADD CONSTRAINT fk_alert_customer 
  FOREIGN KEY (customer_id) REFERENCES FINANCE_DEMO.RAW.CUSTOMERS(customer_id) 
  NOT ENFORCED;
```

**Why NOT ENFORCED:**
- Snowflake does not enforce constraints at write time (except NOT NULL)
- Constraints provide metadata for query optimization
- Serve as documentation for schema design intent
- DBT tests provide actual runtime validation

**Labels:** `type:schema-definition`, `data-quality`, `documentation`, `technical-debt`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog  
**Blocked By:** Issues #1, #2 (duplicate resolution)

---

### FINANCE-003: All Columns Nullable (Schema Hardening)
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** No schema enforcement for required fields  
**SLA:** 2 weeks

**Description:**
All columns in all RAW tables are nullable. Business logic likely requires certain fields (IDs, dates) to be NOT NULL.

**Recommended Solution:**
```sql
-- Analyze NULL rates first
SELECT 
  'TRANSACTIONS' as table_name,
  SUM(CASE WHEN transaction_id IS NULL THEN 1 ELSE 0 END) as transaction_id_nulls,
  SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as customer_id_nulls,
  SUM(CASE WHEN transaction_date IS NULL THEN 1 ELSE 0 END) as transaction_date_nulls
FROM FINANCE_DEMO.RAW.TRANSACTIONS;

-- Add NOT NULL constraints if no nulls exist
ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ALTER COLUMN transaction_id SET NOT NULL;

ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ALTER COLUMN customer_id SET NOT NULL;

ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ALTER COLUMN transaction_date SET NOT NULL;

-- Repeat for CUSTOMERS and COMPLIANCE_ALERTS
```

**dbt Alternative:**
```yaml
version: 2
models:
  - name: stg_transactions
    columns:
      - name: transaction_id
        tests:
          - not_null
      - name: customer_id
        tests:
          - not_null
      - name: transaction_date
        tests:
          - not_null
```

**Labels:** `type:schema-hardening`, `data-quality`, `constraints`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-004: 75% of Customers Non-Active (Business Logic Review)
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** Unexpected data distribution - business validation needed  
**SLA:** 2 weeks

**Description:**
Only 24.8% of customers have `ACCOUNT_STATUS = 'Active'`. The remaining 75.2% are Inactive (25.2%), Dormant (25.1%), or Closed (24.9%). Yet all customers have transactions.

**Questions for Business:**
1. Should Closed/Dormant customers still have transactions?
2. Is this expected behavior or a data quality issue?
3. Should downstream models filter by account status?

**Investigation Query:**
```sql
-- Transaction activity by account status
SELECT 
  c.ACCOUNT_STATUS,
  COUNT(DISTINCT c.customer_id) as customer_count,
  COUNT(t.transaction_id) as transaction_count,
  AVG(transaction_count) as avg_transactions_per_customer,
  SUM(t.amount) as total_amount
FROM FINANCE_DEMO.RAW.CUSTOMERS c
LEFT JOIN FINANCE_DEMO.RAW.TRANSACTIONS t ON c.customer_id = t.customer_id
GROUP BY c.ACCOUNT_STATUS
ORDER BY customer_count DESC;
```

**Potential Actions:**
- Add `is_active_customer` flag in staging model
- Create separate marts for Active vs All customers
- Document business rules in dbt model descriptions
- Add dbt test to alert if Active % drops below threshold

**Labels:** `type:investigation`, `business-logic`, `data-validation`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-005: Uniform Categorical Distributions Suggest Synthetic Data
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** Data realism concern for testing/development  
**SLA:** 2 weeks

**Description:**
All categorical columns in RAW tables show near-uniform distributions (each value ~20-25% frequency). This suggests synthetic or randomly generated data rather than real-world patterns.

**Examples:**
- TRANSACTION_TYPE: 10 values, each ~50K rows (~10% each)
- ACCOUNT_TYPE: 5 values, each ~100K rows (~20% each)
- RISK_RATING: 3 values, each ~30K rows (~33% each)

**Impact:**
- Models trained on this data may not reflect production patterns
- Business logic testing may miss edge cases
- Aggregations and dashboards show unrealistic distributions

**Recommended Actions:**

**If Development Data:**
- Document that this is synthetic test data
- Plan for realistic data generation or production-like sampling
- Use weighted distributions based on production patterns

**If Production Data:**
- Investigate why distributions are so uniform
- Check for data pipeline bugs or random assignment logic
- Validate source system data generation

**Query to Compare:**
```sql
-- Check if distributions are statistically uniform
SELECT 
  transaction_type,
  COUNT(*) as row_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage,
  ABS(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () - 10.0) as deviation_from_uniform
FROM FINANCE_DEMO.RAW.TRANSACTIONS
GROUP BY transaction_type
ORDER BY row_count DESC;
```

**Labels:** `type:investigation`, `data-quality`, `synthetic-data`, `testing`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-006: VARCHAR Columns Unbounded (Schema Documentation)
**Source:** data_quality_report.md  
**Severity:** Medium  
**Impact:** No length documentation  
**SLA:** 2 weeks

**Description:**
All VARCHAR columns use the default `VARCHAR(16777216)` (16MB). While Snowflake storage is based on actual data length, explicit sizing provides documentation.

**Recommended Solution:**
```sql
-- Analyze actual string lengths
SELECT 
  'TRANSACTION_TYPE' as column_name,
  MAX(LENGTH(transaction_type)) as max_length,
  AVG(LENGTH(transaction_type)) as avg_length
FROM FINANCE_DEMO.RAW.TRANSACTIONS

UNION ALL

SELECT 
  'CURRENCY',
  MAX(LENGTH(currency)),
  AVG(LENGTH(currency))
FROM FINANCE_DEMO.RAW.TRANSACTIONS;

-- Right-size columns based on findings
ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ALTER COLUMN transaction_type TYPE VARCHAR(50);

ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
ALTER COLUMN currency TYPE VARCHAR(3);  -- ISO 4217 standard
```

**Labels:** `type:schema-optimization`, `documentation`, `technical-debt`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-007: 9 dbt Models Use SELECT * (Anti-Pattern)
**Source:** dbt_optimization_report.md  
**Severity:** Medium  
**Impact:** Schema changes break downstream models  
**SLA:** 2 weeks

**Description:**
9 out of 11 models use `SELECT *` from sources/refs, creating tight coupling and fragile pipelines.

**Affected Models:**
- `stg_transactions` (lines 5-6, 18)
- `stg_customers` (line 5)
- `stg_compliance_alerts` (line 5)
- `int_customer_metrics` (line 5)
- `int_high_risk_transactions` (line 5)
- `mart_customer_360` (lines 5-6, 17-18, 30-31)
- `mart_transaction_summary` (lines 5-6, 17-18)
- `mart_compliance_dashboard` (lines 5-6, 17-18)

**Risks:**
- Upstream column additions break downstream models
- Column renames silently propagate
- Cannot control column ordering
- Implicit dependencies are hard to track

**Recommended Fix:**
```sql
-- ❌ BEFORE (fragile)
SELECT *
FROM {{ source('raw', 'transactions') }}

-- ✅ AFTER (explicit)
SELECT 
  transaction_id,
  transaction_date,
  customer_id,
  account_type,
  transaction_type,
  amount,
  currency,
  branch_city,
  business_line
FROM {{ source('raw', 'transactions') }}
```

**Automation Script:**
```bash
# Generate explicit column lists for all models
for model in models/staging/*.sql; do
  echo "Processing $model..."
  # Extract source/ref, query INFORMATION_SCHEMA, generate column list
done
```

**Labels:** `type:refactoring`, `dbt`, `best-practices`, `technical-debt`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-008: 5 Models Missing dbt Tests (Quality Gates)
**Source:** dbt_optimization_report.md  
**Severity:** Medium  
**Impact:** No data quality validation  
**SLA:** 2 weeks

**Description:**
5 models have no tests defined in `schema.yml`:
- `stg_transactions`
- `stg_customers`
- `stg_compliance_alerts`
- `int_customer_metrics`
- `int_high_risk_transactions`

**Recommended Tests:**

**Staging Models:**
```yaml
version: 2
models:
  - name: stg_transactions
    columns:
      - name: transaction_sk
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: transaction_type
        tests:
          - accepted_values:
              values: ['Deposit', 'Withdrawal', 'Transfer', 'ATM', 'Check', 'Wire', 'ACH', 'Fee', 'Dividend', 'Interest']
```

**Intermediate Models:**
```yaml
version: 2
models:
  - name: int_customer_metrics
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - customer_id
    columns:
      - name: total_transactions
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 1
```

**Labels:** `type:testing`, `dbt`, `data-quality`, `technical-debt`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-009: DEMO_ROLE Privilege Scope Unclear (RBAC Review)
**Source:** rbac_audit_report.md  
**Severity:** Medium  
**Impact:** Separation of duties unclear  
**SLA:** 2 weeks

**Description:**
`DEMO_ROLE` owns `DEMO_DB` and `DEMO_WH` and is granted to user SAURABH120S who also has ACCOUNTADMIN. The boundary between demo and production resources is unclear.

**Recommended Actions:**

**1. Document Role Purpose**
```sql
ALTER ROLE DEMO_ROLE SET COMMENT = 
  'Non-production demo and testing role. Should NOT access FINANCE_DEMO database.';
```

**2. Verify Access Boundaries**
```sql
-- Ensure DEMO_ROLE cannot access production
SHOW GRANTS TO ROLE DEMO_ROLE;

-- Revoke any production grants
REVOKE ALL ON DATABASE FINANCE_DEMO FROM ROLE DEMO_ROLE;
```

**3. Create Separate Demo Environment**
```sql
-- Enforce separation via schemas
CREATE SCHEMA DEMO_DB.TESTING COMMENT = 'Isolated testing environment';
GRANT ALL ON SCHEMA DEMO_DB.TESTING TO ROLE DEMO_ROLE;

-- Production data should not be accessible
REVOKE SELECT ON ALL TABLES IN SCHEMA FINANCE_DEMO.RAW FROM ROLE DEMO_ROLE;
```

**Labels:** `type:rbac-review`, `governance`, `security`, `documentation`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

### FINANCE-010: FINANCE_CI_ROLE Has Production Read Access (CI/CD Security)
**Source:** rbac_audit_report.md  
**Severity:** Medium  
**Impact:** CI/CD has production data access  
**SLA:** 2 weeks

**Description:**
The `FINANCE_CI_ROLE` (used by `FINANCE_CI_USER` for CI/CD) has read access to production finance data. CI logs and artifacts may expose sensitive data.

**Recommended Actions:**

**1. Verify Read-Only Restrictions**
```sql
SHOW GRANTS TO ROLE FINANCE_CI_ROLE;

-- Ensure no WRITE privileges
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN DATABASE FINANCE_DEMO FROM ROLE FINANCE_CI_ROLE;
```

**2. Restrict to Test Data**
```sql
-- Option 1: CI uses masked/synthetic test data
CREATE OR REPLACE VIEW FINANCE_DEMO.CI.TRANSACTIONS_TEST AS
SELECT 
  transaction_id,
  transaction_date,
  HASH(customer_id) as customer_id_hash,  -- Mask PII
  account_type,
  transaction_type,
  amount,
  currency,
  branch_city,
  business_line
FROM FINANCE_DEMO.RAW.TRANSACTIONS
LIMIT 1000;

GRANT SELECT ON VIEW FINANCE_DEMO.CI.TRANSACTIONS_TEST TO ROLE FINANCE_CI_ROLE;
REVOKE SELECT ON TABLE FINANCE_DEMO.RAW.TRANSACTIONS FROM ROLE FINANCE_CI_ROLE;
```

**3. Audit CI Logs**
```sql
-- Monitor CI activity
SELECT 
  start_time,
  user_name,
  role_name,
  query_text,
  rows_produced
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE user_name = 'FINANCE_CI_USER'
  AND start_time >= DATEADD(day, -7, CURRENT_DATE)
ORDER BY start_time DESC;
```

**4. Implement Row-Level Security**
```sql
-- Create row access policy for CI role
CREATE OR REPLACE ROW ACCESS POLICY ci_test_data_only
  AS (customer_id NUMBER) RETURNS BOOLEAN ->
    CASE 
      WHEN CURRENT_ROLE() = 'FINANCE_CI_ROLE' 
        THEN customer_id IN (SELECT customer_id FROM test_customer_ids LIMIT 100)
      ELSE TRUE
    END;

ALTER TABLE FINANCE_DEMO.RAW.TRANSACTIONS 
  ADD ROW ACCESS POLICY ci_test_data_only ON (customer_id);
```

**Labels:** `type:security-hardening`, `ci-cd`, `rbac`, `data-privacy`  
**Assignee:** Unassigned  
**Priority:** P2  
**Sprint:** Backlog

---

## Slack Notifications (Informational)

### Slack Message Template for #data-platform-alerts (Critical Issues)

```
🚨 **CRITICAL DATA PLATFORM ISSUES DETECTED** 🚨

**Report Date:** September 10, 2026
**Severity:** CRITICAL (P0)
**SLA:** 24 hours

📊 **6 Critical Issues Require Immediate Attention:**

1️⃣ **TRANSACTION_ID Not Unique** - 116,790 duplicate rows blocking analytics
   → GitHub Issue #1 | Assignee: @platform-lead

2️⃣ **ALERT_ID Not Unique** - 482 duplicate compliance records
   → GitHub Issue #2 | Assignee: @platform-lead

3️⃣ **ACCOUNTADMIN in dbt profiles** - Major security violation
   → GitHub Issue #3 | Assignee: @security-lead

4️⃣ **Password auth instead of key-pair** - Security risk
   → GitHub Issue #4 | Assignee: @security-lead

5️⃣ **FINANCE_DEMO owned by ACCOUNTADMIN** - RBAC violation
   → GitHub Issue #5 | Assignee: @platform-lead

6️⃣ **FINANCE_DEMO_WH owned by ACCOUNTADMIN** - Privilege escalation risk
   → GitHub Issue #6 | Assignee: @platform-lead

📈 **Impact:**
• Data quality: Unreliable analytics and compliance reports
• Security: Overprivileged roles and weak authentication
• Governance: RBAC violations

🔗 **Full Report:** reports/issue_routing_log.md
🎫 **GitHub Project:** https://github.com/your-org/finance-analytics/issues

⏰ **Next Review:** September 11, 2026 (24-hour check-in)
```

### Slack Message Template for #data-platform (High Priority)

```
⚠️ **Data Platform Weekly Digest - High Priority Items**

**Report Date:** September 10, 2026

📋 **6 High Priority Issues (Sprint 46):**

• Issue #7: 50 orphan compliance alerts
• Issue #8: Negative transaction amounts in deposits
• Issue #9: Slow CALL statements (5.23s avg)
• Issue #10: DEMO_WH 4.2x more expensive than FINANCE_DEMO_WH
• Issue #11: CoCo CLI consuming 51% of total credits
• Issue #12: No auto-suspend on COMPUTE_WH

💰 **Cost Impact:** Estimated $50-80/month savings potential

📊 **10 Medium Priority Items:** See Jira tickets FINANCE-001 through FINANCE-010

🔗 **Full Report:** reports/issue_routing_log.md
```

---

## Execution Instructions

### Step 1: Store Credentials

Run these commands to store all required credentials:

```bash
# GitHub
cortex secret store github_token --from-file ~/.github/token
cortex secret store github_owner --value "your-org"
cortex secret store github_repo --value "finance-analytics"

# Jira
cortex secret store jira_token --from-file ~/.jira/token
cortex secret store jira_base_url --value "https://your-domain.atlassian.net"
cortex secret store jira_email --value "your-email@company.com"
cortex secret store jira_project_key --value "FINANCE"

# Slack
cortex secret store slack_token --from-file ~/.slack/bot_token
cortex secret store slack_channel_alerts --value "C01234567"  # Channel ID for #data-platform-alerts
cortex secret store slack_channel_general --value "C07654321"  # Channel ID for #data-platform

# Verify
cortex secret list
```

### Step 2: Execute Routing (Python Script)

Create and run this routing script:

```python
# route_issues.py
import os
import json
from datetime import datetime

# GitHub Issues (Critical + High)
github_issues = [
    {
        "title": "🔴 CRITICAL: TRANSACTION_ID Not Unique - 116,790 Duplicate Rows",
        "body": "See reports/issue_routing_log.md Issue #1",
        "labels": ["severity:critical", "data-quality", "blocking", "dbt"],
        "assignees": ["platform-lead"]
    },
    # ... (add all 12 GitHub issues)
]

# Jira Tickets (Medium)
jira_tickets = [
    {
        "summary": "COMPLIANCE_ALERTS Missing TRANSACTION_ID Column",
        "description": "See reports/issue_routing_log.md FINANCE-001",
        "priority": {"name": "Medium"},
        "issuetype": {"name": "Task"}
    },
    # ... (add all 10 Jira tickets)
]

# Create GitHub issues
for issue in github_issues:
    # Use mcp__github__create_issue tool
    pass

# Create Jira tickets
for ticket in jira_tickets:
    # Use mcp__jira__jira_post tool
    pass

# Send Slack notifications
# Use mcp__slack__slack_post_message tool
```

### Step 3: Verify Routing

After execution, verify:

```bash
# Check GitHub issues
gh issue list --repo your-org/finance-analytics

# Check Jira tickets
curl -u email@company.com:$JIRA_TOKEN \
  https://your-domain.atlassian.net/rest/api/3/search?jql=project=FINANCE

# Check Slack messages (manually verify in Slack UI)
```

---

## Appendix: Routing Statistics

### By Severity
| Severity | Count | % of Total | Destination |
|----------|-------|-----------|-------------|
| Critical | 6 | 27.3% | GitHub + Slack Alert |
| High | 6 | 27.3% | GitHub + Slack |
| Medium | 10 | 45.4% | Jira |
| Low | 0 | 0% | N/A |
| **Total** | **22** | **100%** | - |

### By Report Source
| Report | Critical | High | Medium | Total |
|--------|----------|------|--------|-------|
| data_quality_report.md | 2 | 2 | 6 | 10 |
| dbt_optimization_report.md | 2 | 0 | 2 | 4 |
| finops_report.md | 0 | 4 | 0 | 4 |
| rbac_audit_report.md | 2 | 0 | 2 | 4 |
| **Total** | **6** | **6** | **10** | **22** |

### By Issue Category
| Category | Count |
|----------|-------|
| Data Quality | 8 |
| Security | 4 |
| Cost Optimization | 4 |
| RBAC/Governance | 4 |
| dbt Best Practices | 2 |

---

## Next Steps

1. ✅ **Immediate (Today):** Review this routing log
2. ⏳ **Day 1:** Store credentials via `cortex secret store`
3. ⏳ **Day 1:** Execute routing script to create GitHub issues and Jira tickets
4. ⏳ **Day 1:** Send Slack notifications to #data-platform-alerts
5. ⏳ **Day 2:** Assign Critical issues to platform and security leads
6. ⏳ **Week 1:** Resolve all 6 Critical issues (24-hour SLA)
7. ⏳ **Sprint 46:** Address all 6 High priority issues
8. ⏳ **Sprint 47-48:** Prioritize and address Medium priority Jira tickets

---

**Routing Log Status:** READY FOR EXECUTION  
**Generated By:** Cortex Code Issue Router  
**Report Version:** 1.0  
**Last Updated:** September 10, 2026
