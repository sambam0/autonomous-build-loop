Produced by the plan stage from ROADMAP.md success criteria and CONTEXT.md decisions.

## Goal
<phase goal, copied from ROADMAP.md>

## Must-haves
Derived goal-backward. The goal verifier checks every line here, so each must be observable in the codebase.

Truths (observable behavior when the goal is met):
- MH-1: <a user can ...>

Artifacts (what must exist and be substantive, not stubs):
- <path>: <what it provides>

Key links (connections that must be wired, or the goal fails even with all files present):
- <from path> → <to path> via <call, import, query, route>

## Constraints
- Patterns to follow: <path of an existing example to copy>
- Off-limits: <files, folders, systems>
- Dependencies: <"none new" or the allowed packages, each confirmed to exist on its registry>

## Tasks
Each task: one concern, roughly 20–60 minutes of agent work, ending in a state `.loop/verify.sh` can check.
Tasks with no dependency on each other and no overlapping Files can run in the same parallel wave.
If the phase has UI-SPEC.md, UI tasks list the UI-xx checks they cover.
The first task is a tracer: the thinnest end-to-end slice through every layer this phase touches.
IDs must match PROGRESS.md.

### T1: <title> (tracer)
Depends on: none
Covers: MH-1, D-01
Files: <paths this task creates or modifies; used to run tasks in parallel safely>
Read first: <files the agent must read before editing>
Do: <concrete change with file paths; no "align with" or "improve">
Test first: <yes, for behavior-adding logic | no>
Done when: <verifiable: named test passes, command output, or specific code assertion; plus verify green>

### T2: <title>
Depends on: T1
Covers:
Files:
Read first:
Do:
Test first:
Done when:
