# Orchestrate a goal

How to break a user goal into specialist-owned slices and track them **inside** the loop — not as a second skill or a second board.

Read this when SKILL.md's **Orchestrate a goal** path applies. Sequential execute (one executor, or a `wave.sh` wave of executors) does not need this file.

This document absorbs the former `orchestrate-a-goal` skill. Grok Bot paths (`/home/box/orchestrator/inflight.md`, SendToAgent) are **adapter-only**; see `adapters/grok-bot/`.

## Contents
- When to orchestrate
- Roster (loop roles first)
- Steps
- Task ownership fields
- Brief template
- In-flight board
- Closing and status
- Do not

## When to orchestrate

A multi-step goal that should be handed to **specialists**, not done as one blob and not done as only sequential implement-and-gate tasks.

Stay on sequential execute when every slice is "an executor changes these files and the gate passes." Orchestrate when the critical path includes distinct jobs: a judge who must not be the author, UI/eval probing, bounded research, skill/routine work, or several of those in one goal — especially when the human would otherwise relay context between chats.

If you hesitate, execute. Do not fan work out for awareness.

## Roster (loop roles first)

Use loop roles in SPEC.md. Crew names are aliases for the Grok Bot adapter only.

| Loop role | Job | Crew alias (adapter) |
|---|---|---|
| **Loop owner** | Owns the goal, task breakdown, assignments, STATE/PROGRESS, human status | Orchestrator |
| **executor** | Code, debugging, commits on the phase/slot branch | Engineer |
| **plan-checker** / **goal-verifier** / **reviewer** | Fresh-context judges of plans, finished phases, and diffs | Reviewer |
| **ui-researcher** / **ui-checker** | Design survey and UI-contract audit (screenshots) | Tester |
| **explorer** / **test-runner** / **codebase-mapper** | Read-only find/run/map (mapper writes `CODEBASE.md` only) | Engineer (or `role.sh`) |
| *(meta)* | Agent loops, skills, routines, evals, handoff briefs | Loopsmith — not a coding executor unless the task *is* adapter/skill docs |
| *(out of band)* | Social/market/LinkedIn-style lookups | Researcher — never executor, plan-checker, or goal-verifier |

Adapt names and ids to the current crew, but **do not invent a second role system**. Map onto `.loop/roles/` and `adapters/grok-bot/ROLE_MAP.md`.

Plan-checker, goal-verifier, and ui-checker **must** run in a context that did not produce the work. "Already discussed in the loop-owner thread" is not a review.

## Steps

Same seven steps as the absorbed skill, mapped onto loop stages:

1. **Restate** the goal in one sentence and write success criteria. Roadmap (or Quick-track CONTEXT/STATE) is where this lands. Do not assign anyone against a vague goal.
2. **Split** into the smallest scoped tasks that can finish independently. Each task needs the usual SPEC fields (`references/planning.md`) plus, when orchestrating: **Owner**, **Input**, **Output**, success criteria (**Done when**), and **Escalate** (what to send to the human).
3. **Update the in-flight board before dispatching:** Active / Queued / Blocked. Standalone that board *is* `.loop/STATE.md` Next action + phase `PROGRESS.md` (and STATE Blockers). A Grok Bot crew may *mirror* the same facts to `/home/box/orchestrator/inflight.md` — never as a competing task list.
4. **Brief** each assignee with a self-contained message (template below). Prefer 1:1 handoffs. Use a shared channel only for cross-cutting status or decisions that need several specialists. Coding waves still use `wave.sh` + executor prompts; judges use `role.sh` or a fresh subagent.
5. **Minimum assignees.** Do not fan out the same ask to every agent. Assign the smallest set that unblocks the goal.
6. **When results return:** update PROGRESS/STATE (then inflight, if using the adapter), unblock dependents, send an *extra* Reviewer only when a quality gate beyond the loop's judges is worth it, and give the human a short status (what moved, what's blocked, what needs them). **Plan-check, the test gate, and goal verification stay mandatory** — extra review never replaces them.
7. **Close** tasks only when success criteria are met or the human accepts a stop. Close a phase only at Ship, with the same preflight as always (`references/verification-and-ship.md`).

## Task ownership fields

Add these under a SPEC task that is not a plain coding slice (coding tasks imply `Owner: executor`):

```markdown
Owner: plan-checker
Input: phase CONTEXT.md, SPEC.md, PROGRESS.md, ROADMAP success criteria
Output: blocker/warning list with file:section refs; sign-off yes/no
Escalate: contradictory locked decisions; unachievable success criteria
```

- **Owner** is a loop role, not a person's name.
- **Input** must be enough to start without the human pasting context between chats.
- **Output** is a concrete artifact the loop owner can file (results note, review list, VERIFICATION section).
- **Escalate** is the human-only set: credentials, product/priority calls, ship/push/PR, destructive or paid actions, architectural Rule-4 changes.

Human-only work still goes under "For the human" in PROGRESS.md, not into a specialist task pretending to be autonomous.

## Brief template

Self-contained. The assignee should not need the parent thread.

```
Goal: …
Your slice: …
Context: …
Constraints: …
Done means: …
Report back: …
```

Filled examples live in `adapters/grok-bot/briefs/` (executor, plan-checker, goal-verifier). For Claude Code / Codex / headless, the same shape is the subagent prompt or the preamble to `.loop/role.sh <role>`. Do not create a second briefing format.

## In-flight board

| Column | Standalone (required) | Grok Bot adapter (optional mirror) |
|---|---|---|
| **Active** | `.loop/STATE.md` → Next action (verbatim sense) | `inflight.md` Active row pointing at that Next action |
| **Queued** | Phase `PROGRESS.md` `- [ ]` tasks | Inflight Queued — pointers only, not a fork of the checklist |
| **Blocked** | `PROGRESS.md` `- [!]` plus STATE Blockers | Inflight Blocked, with the `BLOCKED:` reason |

The loop owner keeps the board and chases blockers. The human is not the glue.

**Dual-board anti-pattern:** an inflight (or chat) task list that disagrees with PROGRESS.md. Inflight names phase + owner + Next action; PROGRESS owns checkboxes. Never invent Next action — if STATE is stale, fix STATE first.

Details for the adapter mirror: `adapters/grok-bot/STATE-INFLIGHT.md`.

## Closing and status

After each meaningful handoff, tell the human in a few lines:

- What moved (task ids, owner, evidence path)
- What's blocked (reason tag + who can unblock)
- What needs them (decisions, credentials, ship)

Stay quiet when nothing changed and nothing is blocked.

A coding goal is not "done" on the board until Ship preflight holds or the human accepts a stop. Orchestration does not skip plan-check, `.loop/verify.sh`, or goal-backward verification.

## Do not

- Make the human the glue between chats — you keep STATE/PROGRESS and chase blockers
- Message many agents "for awareness" without a concrete ask
- Start external sends, purchases, or destructive actions without the human's go-ahead
- Treat adjacency ("we already talked about it") as plan-check or goal-verify
- Depend on `/home/box/orchestrator/inflight.md` or SendToAgent unless you are on the Grok Bot adapter
- Dilute or skip the test gate, plan-check, or goal verification to make dispatch look finished
