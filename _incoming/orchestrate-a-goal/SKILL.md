---
name: Orchestrate a goal
description: >-
  Use when turning a user goal into scoped tasks, assigning them to specialist
  agents, and tracking what is in flight across chats.
---
# Orchestrate a goal

## When to use
A multi-step goal that should be broken up and handed to specialists, not done as one blob.

## Roster (adapt names/ids to the current crew)
- **Orchestrator** — owns the goal, task breakdown, assignments, and in-flight board
- **Engineer** — code, PRs, debugging, cloud agent repo work
- **Loopsmith** — agent loops, skills, routines, evals, handoff briefs
- **Reviewer** — adversarial review of plans, PRs, and agent briefs
- **Researcher** — research, LinkedIn/Vercel-flavored lookups
- **Tester** — scenario stress-tests (prompts, UX flows, coach behavior)

## Steps
1. Restate the goal in one sentence and write success criteria.
2. Split into the smallest scoped tasks that can finish independently. Each task needs: owner specialist, input, output, success criteria, and what to escalate to the human.
3. Update the shared in-flight board (`/home/box/orchestrator/inflight.md`) before dispatching: Active / Queued / Blocked.
4. Brief each assignee with a self-contained message (context, constraints, definition of done, what to report back). Prefer 1:1 handoffs for work; use the Crew channel only for cross-cutting status or decisions that need several specialists.
5. Do not fan out the same ask to every agent. Assign the minimum set that unblocks the goal.
6. When results return: update the board, unblock dependents, send Reviewer only when a quality gate is worth it, and give the human a short status (what moved, what’s blocked, what needs them).
7. Close tasks only when success criteria are met or the human accepts a stop.

## Brief template
```
Goal: …
Your slice: …
Context: …
Constraints: …
Done means: …
Report back: …
```

## Do not
- Make the human the glue between chats — you keep the board and chase blockers
- Message many agents “for awareness” without a concrete ask
- Start external sends, purchases, or destructive actions without the human’s go-ahead
