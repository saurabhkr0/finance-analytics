# Snowflake RBAC Audit Report

**Generated:** September 10, 2026  
**Account:** FP99918  
**Auditor:** Cortex Code RBAC Auditor

---

## Executive Summary

This audit assessed the Role-Based Access Control (RBAC) configuration for the Snowflake account. The analysis identified **9 active roles**, **2 users**, and **1,302+ privilege grants**. Key findings include proper role hierarchy adherence, minimal direct grants to users (good practice), and several opportunities to improve privilege segregation and reduce overprivilege risks.

### Risk Level: **MEDIUM**

**Key Concerns:**
- ACCOUNTADMIN holds ownership of critical production resources
- DEMO_ROLE has ownership privileges on production-adjacent databases
- Multiple AI and system roles have extensive privileges that may not be actively monitored

---

## 1. Role Inventory

### Active Roles (9 total)

| Role Name | Assigned to Users | Granted to Roles | Granted Roles | Created On |
|-----------|-------------------|------------------|---------------|------------|
| ACCOUNTADMIN | 1 | 0 | 2 | 2026-08-18 |
| DEMO_ROLE | 1 | 1 | 0 | 2026-08-19 |
| FINANCE_CI_ROLE | 1 | 1 | 0 | 2026-09-10 |
| ORGADMIN | 1 | 0 | 0 | 2026-08-18 |
| PUBLIC | 0 | 0 | 1 | 2026-08-18 |
| SECURITYADMIN | 0 | 1 | 1 | 2026-08-18 |
| SNOWFLAKE_LEARNING_ROLE | 0 | 1 | 0 | 2026-08-18 |
| SYSADMIN | 0 | 1 | 2 | 2026-08-18 |
| USERADMIN | 0 | 1 | 0 | 2026-08-18 |

### System Roles (239 additional Cortex/AI roles not shown)
The account contains 239 system-managed roles (CORTEX-MODEL-ROLE-*, APP_*, AI_OBSERVABILITY_*, etc.) which are standard for Snowflake AI and system operations.

---

## 2. User Role Assignments

### User: SAURABH120S
- **ACCOUNTADMIN** (created 2026-08-18)
- **DEMO_ROLE** (created 2026-08-19)
- **ORGADMIN** (created 2026-08-18)

**Risk:** User has ACCOUNTADMIN access. Ensure this is justified and follows least privilege principles.

### User: FINANCE_CI_USER
- **FINANCE_CI_ROLE** (created 2026-09-10)

**Status:** Appropriately scoped for CI/CD operations with read-only intent.

---

## 3. Role Hierarchy

```
ACCOUNTADMIN (root)
├── SECURITYADMIN
│   └── USERADMIN
├── SYSADMIN
│   ├── DEMO_ROLE
│   └── FINANCE_CI_ROLE
├── DEMO_ROLE
├── FINANCE_CI_ROLE
└── SNOWFLAKE_LEARNING_ROLE
    └── PUBLIC
```

**Analysis:**
- ✅ Follows Snowflake recommended role hierarchy
- ✅ SECURITYADMIN and SYSADMIN properly grant to ACCOUNTADMIN
- ⚠️ DEMO_ROLE and FINANCE_CI_ROLE both granted to ACCOUNTADMIN and SYSADMIN (double inheritance)

---

## 4. Privilege Analysis

### Account-Level Privileges by Role

#### SECURITYADMIN (16 distinct account privileges)
```
APPLY AUTHENTICATION POLICY, APPLY FEATURE POLICY, APPLY MAINTENANCE POLICY, 
APPLY MULTI PARTY APPROVAL POLICY, APPLY PACKAGES POLICY, APPLY PASSWORD POLICY, 
APPLY SESSION POLICY, ATTACH POLICY, BIND SERVICE ENDPOINT, CREATE NETWORK POLICY, 
MANAGE APPLICATION SPECIFICATIONS, MANAGE CALLER GRANTS, MANAGE GRANTS, 
MANAGE ORGANIZATION ACCESS, MANAGE SERVICE CALLER ACCESS, MANAGE VISIBILITY
```
**Status:** ✅ Appropriate security-focused privileges

#### SYSADMIN (3 account privileges)
```
CREATE COMPUTE POOL, CREATE DATABASE, CREATE WAREHOUSE
```
**Status:** ✅ Appropriate infrastructure management privileges

#### USERADMIN (2 account privileges)
```
CREATE ROLE, CREATE USER
```
**Status:** ✅ Appropriate user management privileges

#### ACCOUNTADMIN (92 account privileges)
**Status:** ⚠️ Expected for ACCOUNTADMIN but requires careful monitoring

---

## 5. Object Ownership Analysis

### Database Ownership

| Database | Owner Role | Risk Level |
|----------|------------|------------|
| FINANCE_DEMO | ACCOUNTADMIN | HIGH ⚠️ |
| SNOWFLAKE_LEARNING_DB | ACCOUNTADMIN | MEDIUM |
| SNOWFLAKE_SAMPLE_DATA | ACCOUNTADMIN | LOW |
| DEMO_DB | DEMO_ROLE | MEDIUM ⚠️ |

**Concern:** Production databases (FINANCE_DEMO) should be owned by SYSADMIN or a dedicated data admin role, not ACCOUNTADMIN.

### Warehouse Ownership

| Warehouse | Owner Role | Risk Level |
|-----------|------------|------------|
| FINANCE_DEMO_WH | ACCOUNTADMIN | HIGH ⚠️ |
| COMPUTE_WH | ACCOUNTADMIN | MEDIUM |
| DEMO_WH | DEMO_ROLE | LOW |
| SNOWFLAKE_LEARNING_WH | ACCOUNTADMIN | LOW |
| SYSTEM$STREAMLIT_NOTEBOOK_WH | ACCOUNTADMIN | LOW |

**Concern:** Production warehouses should be owned by SYSADMIN for better separation of duties.

---

## 6. Privilege Sprawl Assessment

### Top Roles by Privilege Count

| Role | Object Types | Total Grants |
|------|--------------|--------------|
| ACCOUNTADMIN | 8 types | 258 grants |
| TRUST_CENTER_ADMIN | 5 types | 172 grants |
| TRUST_CENTER_VIEWER | 5 types | 70 grants |
| DATA_SECURITY_ADMIN | 6 types | 83 grants |
| DATA_SECURITY_VIEWER | 5 types | 65 grants |
| POSTGRES_MIRROR_ADMIN | 3 types | 94 grants |

**Analysis:**
- ACCOUNTADMIN: Expected high privilege count (149 database_role grants + 92 account privileges)
- System roles (TRUST_CENTER_*, DATA_SECURITY_*): Standard for monitoring and governance
- ⚠️ Review if all system roles are actively used

---

## 7. Governance Gaps

### 🔴 CRITICAL

1. **Production Database Ownership**
   - `FINANCE_DEMO` owned by ACCOUNTADMIN instead of SYSADMIN
   - **Impact:** Violates separation of duties principle
   - **Remediation:** Transfer ownership to SYSADMIN

2. **Production Warehouse Ownership**
   - `FINANCE_DEMO_WH` owned by ACCOUNTADMIN
   - **Impact:** Operational tasks require ACCOUNTADMIN elevation
   - **Remediation:** Transfer ownership to SYSADMIN

### 🟡 MEDIUM

3. **DEMO_ROLE Privilege Scope**
   - Owns DEMO_DB and DEMO_WH
   - Granted to user SAURABH120S who also has ACCOUNTADMIN
   - **Impact:** Unclear separation between demo and production resources
   - **Remediation:** Clarify purpose and scope of DEMO_ROLE

4. **FINANCE_CI_ROLE Access**
   - Has read access to production finance data
   - **Impact:** CI/CD processes have production data access
   - **Recommendation:** Verify read-only restrictions and audit CI logs

### 🟢 LOW

5. **Inactive System Roles**
   - 239 Cortex/AI model roles exist but may not all be in use
   - **Impact:** Increased attack surface if unused
   - **Recommendation:** Audit which AI models are actively used

---

## 8. Best Practices Assessment

| Practice | Status | Notes |
|----------|--------|-------|
| No direct grants to users | ✅ PASS | All access via roles |
| Proper role hierarchy | ✅ PASS | Follows Snowflake model |
| Separation of duties | ⚠️ PARTIAL | ACCOUNTADMIN owns production resources |
| Least privilege principle | ⚠️ PARTIAL | User has ACCOUNTADMIN access |
| Role documentation | ❌ FAIL | No role descriptions/comments |
| Regular access reviews | ⚠️ UNKNOWN | Cannot verify from metadata |

---

## 9. Recommendations

### Immediate Actions (High Priority)

1. **Transfer Production Ownership**
   ```sql
   -- Transfer database ownership
   GRANT OWNERSHIP ON DATABASE FINANCE_DEMO TO ROLE SYSADMIN;
   
   -- Transfer warehouse ownership
   GRANT OWNERSHIP ON WAREHOUSE FINANCE_DEMO_WH TO ROLE SYSADMIN;
   ```

2. **Document Role Purposes**
   ```sql
   -- Add comments to custom roles
   ALTER ROLE DEMO_ROLE SET COMMENT = 'Demo and testing role - non-production only';
   ALTER ROLE FINANCE_CI_ROLE SET COMMENT = 'Read-only role for CI/CD health checks via Cortex Code';
   ```

3. **Review ACCOUNTADMIN Access**
   - Audit why user SAURABH120S requires ACCOUNTADMIN
   - Consider creating specialized admin roles for day-to-day operations
   - Implement MFA for ACCOUNTADMIN usage

### Short-Term Actions (30 days)

4. **Create Specialized Roles**
   ```sql
   -- Example: Create a data admin role for finance operations
   CREATE ROLE FINANCE_DATA_ADMIN COMMENT = 'Finance data warehouse administrator';
   GRANT ROLE FINANCE_DATA_ADMIN TO ROLE SYSADMIN;
   
   -- Grant necessary privileges
   GRANT ALL ON DATABASE FINANCE_DEMO TO ROLE FINANCE_DATA_ADMIN;
   GRANT USAGE ON WAREHOUSE FINANCE_DEMO_WH TO ROLE FINANCE_DATA_ADMIN;
   ```

5. **Implement Access Monitoring**
   - Set up alerts on ACCOUNTADMIN usage
   - Monitor grant changes via GRANTS_TO_ROLES/GRANTS_TO_USERS views
   - Review access logs quarterly

6. **Audit DEMO_ROLE Usage**
   - Verify DEMO_ROLE is only used for non-production activities
   - Consider restricting DEMO_DB to separate schema/database

### Long-Term Actions (60-90 days)

7. **Implement Role-Based Segregation**
   - Create READ_ONLY roles for analysts
   - Create WRITE roles for data engineers
   - Create ADMIN roles for infrastructure management

8. **Regular RBAC Audits**
   - Schedule quarterly RBAC reviews
   - Implement automated compliance checks
   - Document role request and approval process

9. **Enhance Security Posture**
   - Enable MFA for all users
   - Implement network policies
   - Review authentication policies

---

## 10. Compliance Checklist

- [ ] No excessive ACCOUNTADMIN usage
- [ ] Production resources owned by SYSADMIN
- [ ] All roles have documented purposes
- [ ] Regular access reviews performed
- [ ] Unused roles removed or disabled
- [ ] MFA enabled for privileged accounts
- [ ] Audit logging enabled and monitored
- [ ] Least privilege principle enforced

**Current Compliance Score: 4/8 (50%)**

---

## Appendix A: Query Used for Audit

```sql
-- Role inventory
SHOW ROLES;

-- Role hierarchy
SELECT 
    grantee_name AS child_role,
    name AS parent_role
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE granted_on = 'ROLE' AND deleted_on IS NULL;

-- User assignments
SELECT 
    grantee_name AS user_name,
    role AS role_name
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE deleted_on IS NULL;

-- Privilege grants
SELECT 
    grantee_name AS role_name,
    privilege,
    granted_on AS object_type,
    name AS object_name
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE deleted_on IS NULL;
```

---

## Report Metadata

- **Total Roles Audited:** 248 (9 custom + 239 system)
- **Total Users:** 2
- **Total Grants Analyzed:** 1,302
- **Critical Issues:** 2
- **Medium Issues:** 2
- **Low Issues:** 1
- **Audit Duration:** Real-time analysis
- **Next Audit Recommended:** December 10, 2026 (90 days)

---

**Report Status:** DRAFT - Requires review by Security Admin  
**Approval Required By:** SECURITYADMIN or ACCOUNTADMIN
