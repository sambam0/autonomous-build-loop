# Roadmap and planning

How to cut work into phases, and how to turn a phase's decisions into a plan an unattended loop can finish correctly.

## Contents
- Roadmap: milestones and phases
- Mapping an existing codebase
- Research (only when needed)
- Must-haves: plan backwards from the goal
- Tasks
- Specialist ownership (when orchestrating)
- Tracer first
- Test first
- Parallel-safe plans
- UI phases
- Plan check and revision
- Gap-closure tasks
- Worked example

## Roadmap: milestones and phases

A **milestone** is a releasable increment: what this version lets users do, and what it deliberately doesn't. A **phase** is one bounded goal inside it that can be discussed, planned, executed, and verified in one pass.

A good phase:
- has a goal that fits one sentence and is neither trivial nor suspiciously broad
- can be planned without waiting on answers from other phases
- ends in something a verifier can check without reading the whole codebase
- usually becomes 3 to 8 tasks

"Add HMAC signature validation to webhook routes" is a phase. "Build authentication" is usually several. "Fix a typo" isn't a phase at all. When in doubt, split: smaller phases verify more confidently and make wrong decisions cheaper to reverse.

For each phase in ROADMAP.md, write 2 to 7 **success criteria** as observable truths ("A writer can dismiss a note and it doesn't return on reload"). These are the contract the goal verifier holds the phase to. The plan can add must-haves but never drop these.

Order phases so foundations come first and each phase leaves the product working. Record `Depends on:` honestly.

Get the user's approval on the roadmap before starting phase 1. For a single feature, a one-phase roadmap is fine.

## Mapping an existing codebase

Before the first roadmap in a repo with real code, produce `.loop/CODEBASE.md` with the codebase-mapper role:
- Claude Code: spawn the `loop-codebase-mapper` subagent
- Any agent: `.loop/role.sh codebase-mapper`

Skim the result with the user and fix anything wrong. Refresh it when the architecture shifts meaningfully. Every planner and executor reads it, so errors here spread.

## Research (only when needed)

Research when the phase involves a library, API, or pattern that nobody on the project has used yet, or a decision depends on facts you don't have. Skip it when the work follows patterns already in the codebase.

Keep it bounded: list the specific open questions first, answer those, stop. Record findings briefly in the phase's SPEC.md Constraints or a short "Research notes" section in CONTEXT.md.

**Package legitimacy:** before any task adds a dependency, confirm the package exists on its registry under that exact name, is maintained, and is the one the docs refer to (`npm view <name>`, `pip index versions <name>`, the registry page). Agents can invent plausible package names, and a typo-squatted package is a security incident. Put confirmed names in SPEC.md Constraints, and nothing else gets installed.

## Must-haves: plan backwards from the goal

Before writing tasks, work backwards from the phase goal. This is what keeps "all tasks done" from meaning "goal missed".

1. **Truths:** what must be observably true when the goal is met? Start with the roadmap success criteria, then add any the decisions imply. Phrase them from the user's or caller's point of view.
2. **Artifacts:** for each truth, what must exist? Concrete paths and what each provides.
3. **Key links:** for each artifact, what must it be connected to for the truth to hold? Component → API route, route → database, form → handler, event → state → render. Stubs and orphaned code hide here, so be explicit.

Write these into SPEC.md's Must-haves section with IDs (`MH-1`...). Tasks reference them under "Covers", and the goal verifier checks each one against the code.

## Tasks

Every task in SPEC.md has:

- **Depends on:** task IDs, or none
- **Covers:** the must-haves, decisions, and UI checks it delivers (`MH-2, D-03, UI-01`)
- **Files:** every path it creates or modifies (directories allowed). This is what lets tasks run in parallel safely, so list shared files honestly.
- **Read first:** files the executor must read before editing, always including the files it will modify and the pattern file it should copy
- **Do:** the concrete change with file paths. Ban vague verbs: "align with", "improve", "clean up", "handle properly".
- **Test first:** yes for behavior-adding logic (business rules, API behavior, data transforms), no for glue, config, and pure UI layout
- **Done when:** verifiable, never subjective. Acceptable forms are a named test passing, a command's output, or a specific assertion about the code ("route file exports POST and calls `generateNotes` from lib/notes.ts"). Always also "verify passes".

Size each task at 20 to 60 minutes of agent work and about 8 files or fewer. Split when "Do" joins unrelated concerns with "and" or "Done when" needs more than one sentence. Merge when a task alone would leave the gate red, like a type change and the call sites it breaks.

Keep human work out: credentials, design judgment, and product calls go under "For the human" in PROGRESS.md, and tasks are written to work around them (mock the external service, read the key from env).

Then write the checklist into PROGRESS.md with matching IDs and titles.

## Specialist ownership (when orchestrating)

Most phases are sequential execute: every task's owner is the executor role, and `loop.sh` / `wave.sh` run them. When the phase (or the parent goal) needs specialists — SKILL.md **Orchestrate a goal** and `references/orchestrate.md` — add these fields on each task that is not a plain coding slice:

- **Owner:** a loop role (`executor`, `plan-checker`, `goal-verifier`, `ui-checker`, `ui-researcher`, `reviewer`, `explorer`, `test-runner`, `codebase-mapper`). Crew names (Engineer, Reviewer, Tester, …) belong only in `adapters/grok-bot/ROLE_MAP.md`.
- **Input:** what they receive (paths, prior outputs, constraints). Enough to start without the human relaying the parent thread.
- **Output:** the artifact they return (results file, review list, VERIFICATION section, `CODEBASE.md`).
- **Escalate:** what they must not decide — credentials, product calls, ship/push/PR, architectural Rule-4 changes.

Coding tasks keep Files, Test first, and Done when, and may omit Owner (it is executor). Specialist tasks still need a verifiable Done when. Human-only work stays under "For the human".

Assign the minimum set. Do not create a "FYI" task for every role. Plan-checker and goal-verifier remain mandatory loop gates in a fresh context; listing them as owners does not replace running them.

The harness still executes `- [ ]` coding tasks via `loop.sh` / `wave.sh`. Specialist judges typically run via `role.sh` or a briefed subagent. They are not a second backlog and they do not skip the test gate.

## Tracer first

Make T1 a tracer: the thinnest real slice through every layer the phase touches. For a feature with UI, API, and database, that's one field saved from one form through one route into one table, and rendered back. It's production-quality code, not a throwaway spike.

Tracers surface integration dead ends at iteration 1 instead of after five horizontal layers are built on a wrong assumption. Later tasks widen the slice.

Skip it only when the phase touches a single layer.

## Test first

For `Test first: yes` tasks the executor writes the failing test, confirms it fails for the right reason, then implements. This gives the loop a check that can't be satisfied by a stub, which matters more when nobody is watching.

If the project has no test setup for the relevant layer, the first task installs and configures it with one passing smoke test. Confirm the test framework package names first (see Package legitimacy).

## Parallel-safe plans

When the user wants parallel waves (`PARALLEL` above 1), shape the plan so independent work can actually run at once:
- After the tracer, look for tasks that don't depend on each other and don't share files. For example, the API route, the panel component, and the guard function can be three independent tasks once the tracer defines their contracts.
- Put shared contracts (types, API shapes, schema) in the tracer or an early task, so parallel tasks build against something fixed.
- Hidden shared files are the main source of merge conflicts: schema and migrations, route registries, barrel exports, `package.json`, global styles, translation catalogs. Two independent tasks that both touch one need a dependency between them.

See `references/parallel-and-review.md` for how waves are selected and merged.

## UI phases

If the phase has an approved UI-SPEC.md (see `references/ui-design.md`), every acceptance check UI-xx must be covered by a task. UI tasks read UI-SPEC.md first, name the component states and exact copy they implement, and add a component test where the project supports it. Human-judged UI items go under "For the human".

## Plan check and revision

Before any execution, run the plan-checker in a fresh context. The author of a plan is the worst judge of it.
- Claude Code: spawn `loop-plan-checker`
- Any agent: `.loop/role.sh plan-checker`

It checks coverage of success criteria, decisions, and must-haves; scope reduction; task completeness; size; dependencies; tracer-first; key links; verifiability; constraints; human work leaking into tasks; SPEC/PROGRESS sync; parallel safety of `Files:`; and UI contract coverage.

With cross-model review configured, run the reviewer model's plan-checker at the same time (Claude Code: spawn `loop-plan-checker` and `loop-cross-reviewer` together; any agent: `.loop/role.sh plan-checker --reviewer`) and merge both lists. A blocker from either model is a blocker unless you can show from the plan that it's wrong.

Fix every BLOCKER, address warnings or note why not, and run the checker again. Stop after three rounds. If blockers remain, bring them to the user, since they usually mean the phase is too big (split it) or a decision is ambiguous (reopen discuss).

**Scope reduction is always a blocker.** If the plan delivers a smaller version of a locked decision ("static labels for now", "v1 without sync"), either plan it at full scope or propose splitting the phase. Never let a shrunken decision into the loop quietly.

Show the user the final task list, then update STATE.md: Stage `execute`, Next action, Log line.

## Gap-closure tasks

When goal verification finds gaps, it adds `G1`, `G2`... tasks to SPEC.md and PROGRESS.md. The loop executes them automatically, up to `MAX_GAP_ROUNDS`. When planning gap tasks by hand (after human verification, for example), use the same format as normal tasks, one gap per task, with "Read first" pointing at the exact files the verification report names.

## Worked example

ROADMAP phase:
```markdown
### 02: Margin notes
Status: active
Goal: In the Craft stage, writers see short notes beside their paragraphs, generated from what they wrote.
Success criteria:
- A writer opening Craft on a piece with 3+ paragraphs sees notes anchored to specific paragraphs
- Notes never contain rewritten versions of the writer's sentences
- A dismissed note stays dismissed after reload
Depends on: 01
```

CONTEXT decisions (excerpt): `D-01` notes generate on entering Craft and on explicit "Refresh" only. `D-02` at most 25 words, second person, no quoting. `D-03` dismissal is stored per note.

SPEC must-haves:
```markdown
Truths:
- MH-1: Entering Craft on a 3+ paragraph piece shows notes anchored by paragraph id
- MH-2: No note body contains a sentence from the piece
- MH-3: Dismissed notes stay hidden after reload
Artifacts:
- prisma/schema.prisma: MarginNote model with paragraphId and dismissedAt
- app/api/craft/notes/route.ts: POST generates, PATCH dismisses
- components/craft/MarginNotes.tsx: renders notes beside paragraphs
Key links:
- components/craft/MarginNotes.tsx → app/api/craft/notes/route.ts via fetch on mount and on Refresh
- app/api/craft/notes/route.ts → prisma.marginNote via create and update
```

SPEC tasks (excerpt):
```markdown
### T1: One note end to end (tracer)
Depends on: none
Covers: MH-1, D-01
Files: prisma/schema.prisma, prisma/migrations, app/api/craft/notes/route.ts, components/craft/MarginNotes.tsx
Read first: prisma/schema.prisma, app/api/ideas/route.ts, components/ideas/IdeasPanel.tsx
Do: Add MarginNote model and migration; POST /api/craft/notes returns one note for the first paragraph using lib/llm.ts; MarginNotes renders it beside that paragraph on Craft mount.
Test first: yes
Done when: craft-notes.route.test.ts asserts POST stores and returns a note with paragraphId (LLM mocked); margin-notes.test.tsx renders a returned note next to its paragraph; verify passes.

### T2: Enforce no-quoting rule
Depends on: T1
Covers: MH-2, D-02
Files: lib/notes/guard.ts, lib/notes/guard.test.ts, app/api/craft/notes/route.ts
Read first: lib/llm.ts, app/api/craft/notes/route.ts
Do: Add lib/notes/guard.ts that rejects notes containing any sentence of 6+ words from the piece or over 25 words, and retries generation once.
Test first: yes
Done when: guard.test.ts covers quoted sentence rejected, 26-word note rejected, valid note accepted; route test asserts guard is applied; verify passes.
```

PROGRESS "For the human":
```markdown
- Visual review of margin layout at narrow widths
- Confirm note tone on three real pieces
```

T1 and T2 are sequential execute (Owner executor, implied). A specialist task on the same phase would add Owner / Input / Output / Escalate — for example a plan-checker before execute, still run in a fresh context via `role.sh` or `loop-plan-checker`, not as a substitute for those gates.
