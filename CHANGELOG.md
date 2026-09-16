# Changelog

## Unreleased

### Folded: Orchestrate a goal into the loop

Specialist orchestration is now a path *inside* this skill (roadmap → discuss → plan → execute), not a separate habit or sibling skill.

- **SKILL.md** — new **Orchestrate a goal** path: when to orchestrate vs sequential execute; restate goal + success criteria → scoped tasks (owner, input, output, escalate) → Active/Queued/Blocked → self-contained briefs → minimum assignees → human status. Wired into existing stages. Verify, ship, and test gates are unchanged.
- **`references/orchestrate.md`** — absorbed the former `orchestrate-a-goal` skill (roster, steps, brief template, board rules, do-nots). Standalone agents use `.loop/STATE.md` + `PROGRESS.md`. Grok Bot `/home/box/orchestrator/inflight.md` and SendToAgent remain adapter-only.
- **`references/planning.md`**, **`references/agents.md`** — specialist ownership fields and how to dispatch roles without a second orchestration system.
- **`adapters/grok-bot/`** — README, ROLE_MAP, and STATE-INFLIGHT now point at the loop path instead of a sibling `orchestrate-a-goal` skill. Existing briefs already match the absorbed template.
- **Templates** — SPEC/PROGRESS note the optional ownership fields and the Active/Queued/Blocked mapping.
- **Removed** `_incoming/orchestrate-a-goal/` after absorption.

No harness, script, or gate-command changes. No application/product code. No secrets.
