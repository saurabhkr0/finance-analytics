# Snowflake RBAC Audit Report

**Account:** GC44975 (HQ84620)
**Audit Date:** 2026-04-25
**Auditor:** Cortex Code Automated RBAC Audit
**Scope:** All roles, users, grants, and access patterns for the FINANCE_DEMO environment

---

## Executive Summary

This account has **significant RBAC deficiencies**. It operates with a single user (`SAURABH120A`) using `ACCOUNTADMIN` as the default role for all daily operations. No custom roles exist. All objects (databases, schemas, warehouses, tables) are owned by `ACCOUNTADMIN`. There are no future grants, no resource monitors, no network policies, and no authentication policies. The environment violates Snowflake's least-privilege best practices across multiple dimensions.

**Overall Risk Rating: HIGH**

| Severity | Finding Count |
|----------|--------------|
| Critical | 3 |
| High | 4 |
| Medium | 3 |
| Low | 2 |

---

## Account Inventory

### Roles (6 total - all system defaults, zero custom roles)

| Role | Assigned Users | Granted to Roles | Granted Roles |
|------|---------------|-----------------|---------------|
| ACCOUNTADMIN | 1 | 0 | 2 (SECURITYADMIN, SYSADMIN) |
| ORGADMIN | 1 | 0 | 0 |
| SECURITYADMIN | 0 | 1 (ACCOUNTADMIN) | 1 (USERADMIN) |
| SYSADMIN | 0 | 1 (ACCOUNTADMIN) | 0 |
| USERADMIN | 0 | 1 (SECURITYADMIN) | 0 |
| PUBLIC | 0 | 0 | 0 |

### Users (1 total)

| User | Default Role | Default Warehouse | MFA Enabled | Disabled | Last Login |
|------|-------------|-------------------|-------------|----------|------------|
| SAURABH120A | ACCOUNTADMIN | COMPUTE_WH | Yes | No | 2026-04-25 |

### Databases (4 total)

| Database | Owner | Type |
|----------|-------|------|
| FINANCE_DEMO | ACCOUNTADMIN | STANDARD |
| SNOWFLAKE | (system) | APPLICATION |
| SNOWFLAKE_SAMPLE_DATA | ACCOUNTADMIN | IMPORTED |
| USER$SAURABH120A | (system) | PERSONAL |

### Warehouses (3 total)

| Warehouse | Owner | Size | Auto-Suspend | State |
|-----------|-------|------|-------------|-------|
| COMPUTE_WH | ACCOUNTADMIN | X-Small | 300s | STARTED |
| FINANCE_DEMO_WH | ACCOUNTADMIN | X-Small | 60s | SUSPENDED |
| SYSTEM$STREAMLIT_NOTEBOOK_WH | ACCOUNTADMIN | X-Small | 60s | SUSPENDED |

### FINANCE_DEMO Schemas

| Schema | Owner |
|--------|-------|
| RAW | ACCOUNTADMIN |
| ANALYTICS | ACCOUNTADMIN |
| ML | ACCOUNTADMIN |
| PUBLIC | ACCOUNTADMIN |

---

## Findings

### CRITICAL Severity

#### C1: ACCOUNTADMIN Used as Default Role for Daily Operations

**Description:** User `SAURABH120A` has `ACCOUNTADMIN` set as their default role and uses it for all 657 queries executed in the last 30 days. This includes routine SELECT (324), SHOW (260), and DESCRIBE (32) operations that should never require superadmin privileges.

**Risk:** Any accidental or malicious operation runs with full account control. A compromised session could drop databases, exfiltrate all data, create backdoor users, or modify billing. This is the single most impactful finding in this audit.

**Evidence:**
- Default role: `ACCOUNTADMIN`
- 657 queries in 30 days using ACCOUNTADMIN
- Query breakdown: SELECT (324), SHOW (260), DESCRIBE (32), CREATE (11), PUT_FILES (10), LIST_FILES (8)

**Remediation:**
```sql
-- 1. Create functional roles
CREATE ROLE FINANCE_READER;
CREATE ROLE FINANCE_WRITER;
CREATE ROLE FINANCE_ADMIN;

-- 2. Build role hierarchy under SYSADMIN
GRANT ROLE FINANCE_READER TO ROLE FINANCE_WRITER;
GRANT ROLE FINANCE_WRITER TO ROLE FINANCE_ADMIN;
GRANT ROLE FINANCE_ADMIN TO ROLE SYSADMIN;

-- 3. Grant appropriate privileges
GRANT USAGE ON DATABASE FINANCE_DEMO TO ROLE FINANCE_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE FINANCE_DEMO TO ROLE FINANCE_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA FINANCE_DEMO.RAW TO ROLE FINANCE_READER;
GRANT SELECT ON ALL TABLES IN SCHEMA FINANCE_DEMO.ANALYTICS TO ROLE FINANCE_READER;

GRANT ALL ON SCHEMA FINANCE_DEMO.ANALYTICS TO ROLE FINANCE_WRITER;
GRANT ALL ON SCHEMA FINANCE_DEMO.ML TO ROLE FINANCE_WRITER;

GRANT USAGE ON WAREHOUSE FINANCE_DEMO_WH TO ROLE FINANCE_READER;

-- 4. Assign to user and change default
GRANT ROLE FINANCE_ADMIN TO USER SAURABH120A;
ALTER USER SAURABH120A SET DEFAULT_ROLE = 'FINANCE_ADMIN';
```

---

#### C2: All Object Ownership Concentrated on ACCOUNTADMIN

**Description:** Every object in the account (FINANCE_DEMO database, all 4 schemas, all 3 tables, both user-created warehouses) is owned by `ACCOUNTADMIN`. No objects are owned by `SYSADMIN` or any functional role.

**Risk:** This defeats the purpose of the Snowflake role hierarchy. `SYSADMIN` cannot manage any objects because it owns nothing. Object management requires `ACCOUNTADMIN`, forcing its routine use. If custom roles are later created, they cannot be granted ownership without first using `ACCOUNTADMIN`.

**Evidence:**
- FINANCE_DEMO database: owned by ACCOUNTADMIN
- FINANCE_DEMO.RAW schema: owned by ACCOUNTADMIN
- FINANCE_DEMO.ANALYTICS schema: owned by ACCOUNTADMIN
- FINANCE_DEMO.ML schema: owned by ACCOUNTADMIN
- All 3 tables (TRANSACTIONS, CUSTOMERS, COMPLIANCE_ALERTS): owned by ACCOUNTADMIN
- COMPUTE_WH, FINANCE_DEMO_WH: owned by ACCOUNTADMIN

**Remediation:**
```sql
-- Transfer database and schema ownership to SYSADMIN
GRANT OWNERSHIP ON DATABASE FINANCE_DEMO TO ROLE SYSADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE FINANCE_DEMO TO ROLE SYSADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL TABLES IN SCHEMA FINANCE_DEMO.RAW TO ROLE SYSADMIN COPY CURRENT GRANTS;

-- Transfer warehouse ownership
GRANT OWNERSHIP ON WAREHOUSE FINANCE_DEMO_WH TO ROLE SYSADMIN COPY CURRENT GRANTS;
GRANT OWNERSHIP ON WAREHOUSE COMPUTE_WH TO ROLE SYSADMIN COPY CURRENT GRANTS;
```

---

#### C3: Single ACCOUNTADMIN User (No Break-Glass Redundancy)

**Description:** Only one user (`SAURABH120A`) has the `ACCOUNTADMIN` role. There is no second ACCOUNTADMIN user for emergency access.

**Risk:** If this user's credentials are compromised, locked out, or the user leaves the organization, there is no administrative recovery path without contacting Snowflake Support. This is a single point of failure for the entire account.

**Evidence:**
- `SHOW GRANTS OF ROLE ACCOUNTADMIN` returns only 1 user assignment

**Remediation:**
```sql
-- Create a dedicated break-glass admin user
CREATE USER FINANCE_BREAK_GLASS
  PASSWORD = '<strong-random-password>'
  DEFAULT_ROLE = 'PUBLIC'
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Break-glass emergency admin - credentials stored in vault';

GRANT ROLE ACCOUNTADMIN TO USER FINANCE_BREAK_GLASS;

-- Store credentials in a password vault (e.g., CyberArk, HashiCorp Vault)
-- Mandate MFA enrollment before first use
```

---

### HIGH Severity

#### H1: No Custom Roles Exist (Zero Functional Role Design)

**Description:** The account has only the 6 system-default roles. No custom functional roles have been created for data access, ETL operations, BI querying, or compliance review.

**Risk:** Without custom roles, there is no way to implement least-privilege access. As users are added, they will either get ACCOUNTADMIN (full access) or PUBLIC (no access to FINANCE_DEMO). There is no middle ground for analysts, data engineers, or auditors.

**Evidence:**
- `SHOW ROLES` returns exactly 6 rows (all system defaults)
- No roles matching project conventions (e.g., `FINANCE_READER`, `FINANCE_ETL`, `COMPLIANCE_REVIEWER`)

**Remediation:**
```sql
-- Recommended role hierarchy for this finance project:
CREATE ROLE FINANCE_READER;      -- SELECT on RAW + ANALYTICS
CREATE ROLE FINANCE_ETL;         -- INSERT/UPDATE on RAW, CREATE on ANALYTICS
CREATE ROLE COMPLIANCE_REVIEWER; -- SELECT on COMPLIANCE_ALERTS + audit views
CREATE ROLE FINANCE_ADMIN;       -- Full control under SYSADMIN

-- Wire into hierarchy
GRANT ROLE FINANCE_READER TO ROLE FINANCE_ETL;
GRANT ROLE FINANCE_READER TO ROLE COMPLIANCE_REVIEWER;
GRANT ROLE FINANCE_ETL TO ROLE FINANCE_ADMIN;
GRANT ROLE COMPLIANCE_REVIEWER TO ROLE FINANCE_ADMIN;
GRANT ROLE FINANCE_ADMIN TO ROLE SYSADMIN;
```

---

#### H2: No Future Grants Configured

**Description:** No future grants exist in the FINANCE_DEMO database or any of its schemas. When new tables, views, or other objects are created (e.g., by dbt), no roles will automatically receive access.

**Risk:** Every new object created requires manual grant statements, or it becomes accessible only to the creating role (ACCOUNTADMIN). This creates operational friction and leads to either over-use of ACCOUNTADMIN or broken access for downstream consumers.

**Evidence:**
- `SHOW FUTURE GRANTS IN DATABASE FINANCE_DEMO` returns 0 rows
- `SHOW FUTURE GRANTS IN SCHEMA FINANCE_DEMO.RAW` returns 0 rows

**Remediation:**
```sql
-- After creating custom roles, set up future grants:
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE FINANCE_DEMO TO ROLE FINANCE_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA FINANCE_DEMO.RAW TO ROLE FINANCE_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA FINANCE_DEMO.RAW TO ROLE FINANCE_READER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA FINANCE_DEMO.ANALYTICS TO ROLE FINANCE_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA FINANCE_DEMO.ANALYTICS TO ROLE FINANCE_READER;

GRANT ALL ON FUTURE TABLES IN SCHEMA FINANCE_DEMO.RAW TO ROLE FINANCE_ETL;
GRANT ALL ON FUTURE TABLES IN SCHEMA FINANCE_DEMO.ANALYTICS TO ROLE FINANCE_ETL;
```

---

#### H3: No Resource Monitors Configured

**Description:** No resource monitors exist in the account. All three warehouses can consume unlimited credits without alerting or automatic suspension.

**Risk:** A runaway query, recursive procedure, or compromised session could consume unlimited compute credits with no guardrail. In a finance environment, this is both a cost risk and a potential indicator of data exfiltration attempts going undetected.

**Evidence:**
- `SHOW RESOURCE MONITORS` returns 0 rows
- COMPUTE_WH auto_suspend = 300s (5 min, higher than typical)
- No credit quotas on any warehouse

**Remediation:**
```sql
CREATE RESOURCE MONITOR FINANCE_MONITOR
  WITH CREDIT_QUOTA = 100
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = 'FINANCE_MONITOR';
ALTER WAREHOUSE FINANCE_DEMO_WH SET RESOURCE_MONITOR = 'FINANCE_MONITOR';
```

---

#### H4: No Network Policies

**Description:** No network policies are configured. The account accepts connections from any IP address.

**Risk:** There is no IP allowlisting to restrict access to trusted networks. Combined with the single-user ACCOUNTADMIN setup, a credential compromise from any network location grants full account access.

**Evidence:**
- `SHOW NETWORK POLICIES` returns 0 rows

**Remediation:**
```sql
CREATE NETWORK POLICY FINANCE_NETWORK_POLICY
  ALLOWED_IP_LIST = ('<your-corporate-ip-range>')
  BLOCKED_IP_LIST = ()
  COMMENT = 'Restrict access to corporate network';

ALTER ACCOUNT SET NETWORK_POLICY = 'FINANCE_NETWORK_POLICY';
```

---

### MEDIUM Severity

#### M1: PUBLIC Role Has Broad Grants (106 Privileges)

**Description:** The PUBLIC role has 106 grants including:
- `USE AI FUNCTIONS` and `VIEW LINEAGE` at account level
- USAGE on `SYSTEM_COMPUTE_POOL_CPU` and `SYSTEM_COMPUTE_POOL_GPU`
- USAGE on `SYSTEM$STREAMLIT_NOTEBOOK_WH` warehouse
- USAGE on `SNOWFLAKE_SAMPLE_DATA` database and all its schemas
- SELECT on all tables across 6 schemas in SNOWFLAKE_SAMPLE_DATA (80+ tables)
- 14 Snowflake database roles (CORTEX_USER, ML_USER, etc.)

**Risk:** Most of these are Snowflake-provisioned defaults for sample data and are relatively low risk. However, the `USE AI FUNCTIONS` grant means any role can invoke AI/LLM functions which may incur costs. The `SYSTEM$STREAMLIT_NOTEBOOK_WH` USAGE grant gives all roles compute access.

**Remediation:**
```sql
-- Review and revoke AI function access from PUBLIC if cost control is needed
REVOKE USE AI FUNCTIONS ON ACCOUNT FROM ROLE PUBLIC;

-- Revoke public warehouse access
REVOKE USAGE ON WAREHOUSE SYSTEM$STREAMLIT_NOTEBOOK_WH FROM ROLE PUBLIC;

-- Revoke compute pool access
REVOKE USAGE ON COMPUTE_POOL SYSTEM_COMPUTE_POOL_CPU FROM ROLE PUBLIC;
REVOKE USAGE ON COMPUTE_POOL SYSTEM_COMPUTE_POOL_GPU FROM ROLE PUBLIC;
```

---

#### M2: ORGADMIN Granted to Primary User

**Description:** `SAURABH120A` has both `ACCOUNTADMIN` and `ORGADMIN` roles. `ORGADMIN` can manage organizational settings and other accounts.

**Risk:** If this user is compromised, the attacker gains not just account-level but organization-level control. `ORGADMIN` should be restricted to a separate, dedicated user.

**Evidence:**
- `SHOW GRANTS OF ROLE ORGADMIN` shows it granted to `SAURABH120A`

**Remediation:**
```sql
-- Create a dedicated org admin user (if organization management is needed)
-- Otherwise, revoke ORGADMIN from the daily-use account
REVOKE ROLE ORGADMIN FROM USER SAURABH120A;
```

---

#### M3: No Authentication Policies Configured

**Description:** No authentication policies exist in the account. There are no enforced password complexity requirements, session timeouts, or MFA mandates beyond user-level settings.

**Risk:** While the current single user has MFA enabled, there is no policy to enforce MFA for future users. New users could be created without MFA, and no password rotation is enforced.

**Evidence:**
- `SHOW AUTHENTICATION POLICIES` returns 0 rows

**Remediation:**
```sql
CREATE AUTHENTICATION POLICY FINANCE_AUTH_POLICY
  MFA_AUTHENTICATION_METHODS = ('TOTP')
  CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSQL', 'DRIVERS')
  SECURITY_INTEGRATIONS = ()
  COMMENT = 'Enforce MFA for all authentication';

ALTER ACCOUNT SET AUTHENTICATION POLICY = FINANCE_AUTH_POLICY;
```

---

### LOW Severity

#### L1: SYSADMIN Has No Object Grants (Bypassed in Hierarchy)

**Description:** SYSADMIN has only account-level privileges (CREATE DATABASE, CREATE WAREHOUSE, CREATE COMPUTE POOL) but owns zero objects and has no grants on existing databases, schemas, or tables.

**Risk:** The Snowflake-recommended hierarchy has SYSADMIN as the parent for all custom roles and the owner of databases/warehouses. Currently, SYSADMIN is non-functional. This is a design smell rather than a direct security risk.

**Evidence:**
- SYSADMIN grants: CREATE COMPUTE POOL, CREATE DATABASE, CREATE WAREHOUSE only
- No database, schema, or table grants

**Remediation:** Addressed by C2 (transferring ownership to SYSADMIN).

---

#### L2: COMPUTE_WH Auto-Suspend Set to 5 Minutes

**Description:** `COMPUTE_WH` has `auto_suspend = 300` seconds (5 minutes), while `FINANCE_DEMO_WH` is more appropriately set at 60 seconds.

**Risk:** Minor cost inefficiency. The warehouse stays running for 5 minutes after the last query, consuming credits unnecessarily.

**Remediation:**
```sql
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;
```

---

## FINANCE_DEMO Specific Analysis

### Object Access Matrix

| Object | ACCOUNTADMIN | SYSADMIN | PUBLIC | Custom Roles |
|--------|-------------|----------|--------|--------------|
| FINANCE_DEMO (DB) | OWNERSHIP | - | - | None exist |
| RAW (Schema) | OWNERSHIP | - | - | None exist |
| ANALYTICS (Schema) | OWNERSHIP | - | - | None exist |
| ML (Schema) | OWNERSHIP | - | - | None exist |
| TRANSACTIONS (Table) | OWNERSHIP | - | - | None exist |
| CUSTOMERS (Table) | OWNERSHIP | - | - | None exist |
| COMPLIANCE_ALERTS (Table) | OWNERSHIP | - | - | None exist |
| FINANCE_DEMO_WH | OWNERSHIP | - | - | None exist |
| COMPUTE_WH | OWNERSHIP | - | - | None exist |

**Observation:** The FINANCE_DEMO environment is a completely flat access model. There is exactly one user with exactly one role that has total ownership of everything. No object has more than one grant (OWNERSHIP by ACCOUNTADMIN). This is the antithesis of least-privilege design.

---

## Recommended Target RBAC Architecture

```
                    ACCOUNTADMIN
                         |
                      SYSADMIN
                         |
                   FINANCE_ADMIN
                    /         \
            FINANCE_ETL    COMPLIANCE_REVIEWER
                 |              |
            FINANCE_READER -----+
```

| Role | Purpose | Key Privileges |
|------|---------|---------------|
| FINANCE_READER | Analysts, BI tools | SELECT on RAW + ANALYTICS; USAGE on FINANCE_DEMO_WH |
| FINANCE_ETL | dbt, data pipelines | INSERT/UPDATE/DELETE on RAW; CREATE TABLE/VIEW on ANALYTICS |
| COMPLIANCE_REVIEWER | Audit and compliance | SELECT on COMPLIANCE_ALERTS; SELECT on audit views |
| FINANCE_ADMIN | Team lead, admin tasks | OWNERSHIP on schemas; manages grants within FINANCE_DEMO |

---

## Remediation Priority Matrix

| Priority | Finding | Action | Effort |
|----------|---------|--------|--------|
| 1 | C1 | Change default role away from ACCOUNTADMIN | Low |
| 2 | H1 | Create custom functional roles | Low |
| 3 | C2 | Transfer object ownership to SYSADMIN | Low |
| 4 | H2 | Configure future grants | Low |
| 5 | C3 | Create break-glass admin user | Low |
| 6 | H3 | Set up resource monitors | Low |
| 7 | H4 | Configure network policies | Medium |
| 8 | M3 | Create authentication policies | Medium |
| 9 | M1 | Review and tighten PUBLIC role grants | Low |
| 10 | M2 | Separate ORGADMIN from daily user | Low |
| 11 | L1 | Addressed by item 3 | - |
| 12 | L2 | Reduce COMPUTE_WH auto-suspend | Low |

---

## Appendix: Raw Data Summary

- **Total roles:** 6 (all system defaults)
- **Total users:** 1
- **Total databases:** 4 (1 user-created, 1 sample, 1 system, 1 personal)
- **Total warehouses:** 3 (2 user-created, 1 system)
- **FINANCE_DEMO schemas:** 4 (RAW, ANALYTICS, ML, PUBLIC)
- **FINANCE_DEMO.RAW tables:** 3 (TRANSACTIONS, CUSTOMERS, COMPLIANCE_ALERTS)
- **Future grants:** 0
- **Resource monitors:** 0
- **Network policies:** 0
- **Authentication policies:** 0
- **ACCOUNTADMIN queries (30 days):** 657 by SAURABH120A, 4 by FIRST_USER (system provisioning)
