# finance-analytics

> A Production-Ready, Self-Governing, AI-Augmented Data Platform on Snowflake![Uploading image.png…]()
 — using Snowflake CoCo CLI's full extensibility stack.

This repository is the companion project to a 7-part Medium series on **Snowflake CoCo CLI**. It demonstrates how to build a governed, automated finance analytics platform from scratch — using Skills, Subagents, Agent Teams, Hooks, and MCP integrations.

---

## The Series

| Part | Title | Link |
|------|-------|------|
| 1 | Build a Production-Ready dbt Project | [Read →](https://medium.com/@saurabh.kr/build-a-production-ready-dbt-project-using-snowflake-cortex-code-cli-c51fb8556f66) |
| 2 | Build Custom Skills | [Read →](https://medium.com/@saurabh.kr/build-custom-skills-in-snowflake-cortex-code-cli-e5e7fe287c9c) |
| 3 | Build Custom Subagents | [Read →](https://medium.com/@saurabh.kr/build-custom-subagent-in-snowflake-cortex-code-cli-part-3-4d2b1f478e11) |
| 4 | Build and Run Agent Teams | [Read →](https://medium.com/@saurabh.kr/build-and-run-agent-teams-in-snowflake-cortex-code-cli-part-4-97e836acdc49) |
| 5 | Build Guardrails with Hooks | [Read →](https://medium.com/@saurabh.kr/add-guardrails-to-your-ai-agents-with-hooks-in-snowflake-cortex-code-cli-part-5-77525986ccf5) |
| 6 | Build MCP Integrations | [Read →](https://medium.com/@saurabh.kr/build-mcp-integrations-in-snowflake-cortex-code-cli-part-6-9d029a749393) | 
| 7 | Ship to Production | [Read →](https://medium.com/@saurabh.kr/ship-your-ai-augmented-data-platform-to-production-with-snowflake-cortex-code-cli-part-7-c368c8c4120d) | 

---

## What's Inside

```
finance-analytics/
├── .cortex/
│   ├── agents/
│   │   ├── data-quality-inspector.md   # Profiles raw tables, flags anomalies
│   │   ├── dbt-optimizer.md            # Reviews dbt project for best practices
│   │   ├── rbac-auditor.md             # Audits Snowflake roles and access grants
│   │   ├── finops-analyst.md           # Analyses credit consumption
│   │   └── issue-router.md             # Routes findings to GitHub, Jira, Slack
│   ├── skills/
│   │   ├── source-onboard/             # Automates raw source onboarding into dbt
│   │   └── dbt-model-generator/        # Generates dbt models from source tables
│   ├── hooks/
│   │   ├── block-destructive-sql.sh    # Blocks DROP/TRUNCATE/DELETE at runtime
│   │   ├── cost-guard.sh               # Prevents queries exceeding credit threshold
│   │   ├── audit-logger.sh             # Logs every tool call with timestamp
│   │   ├── pii-scanner.sh              # Scans file writes for PII patterns
│   │   └── log-mcp-call.sh             # Audit trail for all external MCP calls
│   └── settings.json                   # Hook configuration
├── finance_warehouse/                  # dbt project (3-layer architecture)
│   ├── models/
│   │   ├── staging/                    # Views over raw sources
│   │   ├── intermediate/               # Ephemeral business logic
│   │   └── marts/                      # Final tables for consumption
│   └── dbt_project.yml
├── reports/                            # Agent-generated output
├── AGENTS.md                           # Project conventions for Cortex Code
└── README.md
```

---

## The Extensibility Stack

| Layer | What It Does | Introduced |
|-------|-------------|------------|
| `AGENTS.md` | Project context and conventions | Part 1 |
| Skills | Reusable playbooks your team can invoke | Part 2 |
| Subagents | Autonomous specialist agents | Part 3 |
| Agent Teams | Coordinated multi-agent execution | Part 4 |
| Hooks | Lifecycle interceptors and policy enforcement | Part 5 |
| MCP | External tool integration (GitHub, Jira, Slack) | Part 6 |

---

## Prerequisites

- Snowflake account (trial works)
- [Snowflake Cortex Code CLI](https://docs.snowflake.com/en/user-guide/cortex-code) installed
- dbt Core with `dbt-snowflake` adapter
- Node.js (for MCP servers via `npx`)

---

## Getting Started

**1. Clone the repo**

```bash
git clone https://github.com/saurabhkr0/finance-analytics.git
cd finance-analytics
```

**2. Set up dbt credentials**

Create `finance_warehouse/profiles.yml` (not committed — see `.gitignore`):

```yaml
finance_warehouse:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: your_account
      user: your_user
      authenticator: externalbrowser
      role: YOUR_ROLE
      warehouse: YOUR_WAREHOUSE
      database: FINANCE_DEMO
      schema: RAW
      threads: 4
```

**3. Install dbt packages**

```bash
cd finance_warehouse
dbt deps
```

**4. Configure MCP servers (Part 6+)**

Set environment variables in your shell profile:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
export ATLASSIAN_SITE_NAME="yourcompany"
export ATLASSIAN_USER_EMAIL="your@email.com"
export ATLASSIAN_API_TOKEN="..."
export SLACK_BOT_TOKEN="xoxb-..."
export SLACK_TEAM_ID="T..."
```

Then add MCP servers:

```bash
cortex mcp add github npx -y @modelcontextprotocol/server-github \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN

cortex mcp add jira npx -y @aashari/mcp-server-atlassian-jira \
  -e ATLASSIAN_SITE_NAME=$ATLASSIAN_SITE_NAME \
  -e ATLASSIAN_USER_EMAIL=$ATLASSIAN_USER_EMAIL \
  -e ATLASSIAN_API_TOKEN=$ATLASSIAN_API_TOKEN

cortex mcp add slack npx -y @modelcontextprotocol/server-slack \
  -e SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN \
  -e SLACK_TEAM_ID=$SLACK_TEAM_ID
```

**5. Launch Cortex Code**

```bash
cortex
```

---

## Running the Health Check Swarm

From a Cortex Code session, run the full four-agent audit + issue routing in one prompt:

```
Launch a swarm of agents:
1. data-quality-inspector agent to profile FINANCE_DEMO.RAW
2. dbt-optimizer agent to review the dbt project
3. rbac-auditor agent to audit all roles and access
4. finops-analyst agent to analyze credit consumption for the last 30 days

When all four agents complete, launch the issue-router agent to
read all reports in reports/ and route findings to GitHub, Jira, and Slack.
```

Reports are written to `reports/`. GitHub issues, Jira tickets, and a Slack summary are created automatically.

---

## CI/CD

This repo includes a GitHub Actions workflow (`.github/workflows/cortex-ci.yml`) that validates the Cortex Code stack on every pull request:

- Agent definitions present and correctly structured
- Hooks present and free of hardcoded secrets
- `settings.json` is valid JSON
- `dbt_project.yml` and `AGENTS.md` exist

---

## Author

**Saurabh Kumar** — Senior Manager, Data & AI at Accenture Australia, Snowflake Data Superhero  
[Medium](https://medium.com/@saurabh.kr) · [LinkedIn](https://www.linkedin.com/in/saurabh-kr15/)

---

## Licence

MIT
