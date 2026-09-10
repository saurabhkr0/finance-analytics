I'll orchestrate this multi-phase swarm workflow for you. Let me load the team-workflow skill first to properly coordinate these agents.Now I'll set up the team-workflow and coordinate your swarm of agents. Let me start with the setup steps.Now let me list all teammates to see what specialized agents are available:I see the standard team-workflow roles. For this swarm use case with specialized agents, I'll create individual tasks for each agent and use the "research" role to execute them in parallel. Let me create the step graph for the 4 parallel analysis agents, followed by the routing agent:Perfect! Now I have the step graph. Let me create individual tasks with detailed work contracts for each specialized agent:Now let me bind these tasks to the steps and spawn the workers:Now let me spawn the workers. 

**Teammate selection:** 4 research workers for parallel analysis (data quality, dbt optimization, RBAC audit, cost analysis), 1 implementor for routing findings. Total: 5 of 45 budget.Good catch - I'm still in plan mode. Let me write a plan first since we're orchestrating a swarm, then exit plan mode:Searching for relevant tools...
Found 1 relevant tool

Now let me exit plan mode and get user approval to proceed:Perfect! Now I can spawn the implementor agent for the routing phase:Excellent! All 5 agents spawned successfully. The swarm is now running:

**Phase 1 (running now):** 4 research agents analyzing in parallel
- research-1: data-quality-inspector
- research-2: dbt-optimizer  
- research-3: rbac-auditor
- research-4: finops-analyst

**Phase 2 (will start automatically):** implementor-1 routing findings once all 4 reports complete

Monitoring for notifications...