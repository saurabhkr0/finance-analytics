Launch a swarm of agents:

1. data-quality-inspector agent to profile FINANCE_DEMO.RAW
2. dbt-optimizer agent to review the dbt project in current directory
3. rbac-auditor agent to audit all roles and access
4. finops-analyst agent to analyze credit consumption for the last 30 days

When all four agents complete, launch the issue-router agent to read all
reports in reports/ and route findings to GitHub, Jira, and Slack.
