I'll help you route the findings from the reports directory to GitHub Issues, Jira, and Slack. Let me start by reading the report files.Let me read all the report files to understand the findings:Now I need to check what MCP tools are available for GitHub, Jira, and Slack routing:Perfect! Now I have all the MCP tools I need. Let me check for stored secrets before starting the routing:I need to inform the user that secrets are required for the MCP integrations. Let me create a routing plan and document the requirements:Now let me parse all the findings by severity. Based on the reports I've read:

**Data Quality Report:**
- Critical: TRANSACTION_ID duplicates (116,790 excess rows), ALERT_ID duplicates (482 excess rows)
- High: 50 orphan alerts referencing non-existent customers, Negative amounts in transactions
- Medium: Missing TRANSACTION_ID column in COMPLIANCE_ALERTS, No PK/UK constraints

**dbt Optimization Report:**
- Critical: Multiple anti-patterns causing full table scans
- High: Inefficient CTEs, missing incremental models
- Medium: Various optimization opportunities

**FinOps Report:**
- High: CALL statements averaging 5.23 seconds
- Medium: DEMO_WH inefficiency, sporadic workloads
- Low: Various optimization opportunities

**RBAC Audit Report:**
- Critical: Production database and warehouse owned by ACCOUNTADMIN
- Medium: DEMO_ROLE privilege scope, FINANCE_CI_ROLE access
- Low: Inactive system roles

Let me create the routing log with the parsed findings. However, I need to inform the user about the missing secrets first:## Summary

I've analyzed all report files in the `reports/` directory and created a comprehensive routing log at `reports/issue_routing_log.md`. Here's what I found:

**Findings Summary:**
- **6 Critical** issues → GitHub Issues
- **5 High** issues → Jira Tickets  
- **7 Medium** issues → Slack Notifications

**Current Status: BLOCKED** - Missing MCP credentials

To complete the routing, you need to store three secrets:

```bash
# 1. GitHub Personal Access Token
cortex secret store github-token --from-file /path/to/token.txt

# 2. Jira API credentials (format: email:api_token)
cortex secret store jira-credentials --from-file /path/to/jira-creds.txt

# 3. Slack Bot Token
cortex secret store slack-token --from-file /path/to/slack-token.txt
```

Once you store these secrets, I can execute the routing workflow to:
1. Create 6 GitHub Issues for critical data integrity, security, and performance problems
2. Create 5 Jira Tickets for high-priority data quality and cost optimization work
3. Send 7 Slack notifications to `#data-engineering`, `#data-quality`, `#finops`, and `#security` channels

The detailed routing log includes all finding descriptions, impact assessments, recommended actions, and the specific GitHub/Jira/Slack content that will be created.