# Discuss: lock decisions before planning

The roadmap says what a phase delivers. Discuss captures how, in the places where the user's preference would change the result. Skipping it means the planner guesses, and a plausible wrong guess becomes hours of autonomous work in the wrong direction.

Output: the phase's `CONTEXT.md`. Planning, execution, and verification all treat its decisions as binding.

## Contents
- Pick a mode
- Find the gray areas
- Interview mode
- Assumptions mode
- Scope guardrail
- Writing CONTEXT.md
- Shortcuts

## Pick a mode

- **Interview** (default): for new areas, product-facing work, or when the user has opinions. Roughly 10 to 20 short exchanges.
- **Assumptions**: for codebases with clear patterns where most answers are obvious. You read the code, propose what you'd do with evidence, and the user corrects. Usually 2 to 4 exchanges.

Ask the user which they want if it's not obvious. Someone who says "just use what's there" wants assumptions mode.

## Find the gray areas

A gray area is an implementation decision that could reasonably go more than one way and that the user would care about. Derive them from the phase goal and what kind of thing it is: something users see, call, run, read, or something being organized.

Name specific gray areas, never generic categories like "UI" or "behavior":

| Phase | Gray areas |
|---|---|
| User authentication | Session length, error messages shown, multi-device policy, account recovery |
| Margin notes in a writing app | When notes generate, note length and tone, how notes anchor to edited text, dismiss and regenerate behavior |
| CSV export | Columns and order, date and number formats, large exports (stream or email), filtering |
| CLI for backups | Output format, flag design, progress reporting, failure recovery |

Don't ask about implementation internals the user doesn't care about (data structures, library internals, performance tactics). Decide those during planning and note them under "Agent discretion".

Before asking, check `.loop/STATE.md` project decisions and earlier phases' CONTEXT.md files. Anything already decided is pre-answered; mention it rather than re-asking.

## Interview mode

1. Present the gray areas you found (typically 3 to 6) and let the user pick which to discuss. The rest go to "Agent discretion" with your intended default noted.
2. For each chosen area, ask about 3 or 4 questions, one at a time. Offer concrete options with a recommended default where you have one, plus room for "something else".
3. When the user says "you decide", pick, state the choice, and record it as a decision anyway so the planner doesn't reopen it.
4. If the user references a doc, design, ticket, or file, add it to Canonical references immediately and read it before the next question.
5. After each area, summarize the decisions in one or two lines and confirm before moving on.

## Assumptions mode

1. Read the most relevant 5 to 15 files. The explorer role or `.loop/CODEBASE.md` helps here.
2. Write assumptions for each gray area in this shape:
   `A-3: Notes regenerate only on explicit request (evidence: Ideas stage uses a "Refresh" button in components/ideas/IdeasPanel.tsx; confidence: high)`
3. Present them grouped by area and ask the user to confirm or correct. Low-confidence assumptions go first.
4. Confirmed assumptions become decisions. Corrections become decisions in the user's wording.

## Scope guardrail

The phase boundary is fixed. Discussion clarifies how to build what's in scope, never whether to add capabilities.

- Clarifying (allowed): "What shows when there are no notes yet?", "Should notes survive a page reload?"
- New capability (not allowed): "Should writers also be able to reply to notes?", "What about sharing notes?"

The test: does this clarify something inside the phase, or could it be a phase of its own?

When the user raises a new capability, acknowledge it, say it would be its own phase, and record it under "Deferred ideas" in CONTEXT.md and the ROADMAP.md backlog. Don't lose it and don't plan it.

## Writing CONTEXT.md

Fill every section of the template:

- **Boundary:** the phase goal and what's explicitly excluded.
- **Decisions:** numbered `D-01`, `D-02`, and so on. Write each so a stranger could implement it and a verifier could check it. "Notes are at most 25 words, written in second person, and never quote the writer's sentences" beats "notes should be short and friendly".
- **Agent discretion:** areas left to judgment, with the default you intend.
- **Canonical references:** every doc or file downstream agents must read.
- **Code context:** reusable components, patterns to copy (with paths), integration points.
- **Deferred ideas:** everything ruled out of scope.

Then update `.loop/STATE.md`: Stage `plan`, a Next action, and a Log line. Commit the CONTEXT.md if the user wants planning artifacts in git (the default).

## Shortcuts

- **User has a PRD, ticket, or design doc:** skip the interview. Extract decisions from the doc, write CONTEXT.md, and ask the user only about genuine gaps or contradictions.
- **Low-stakes phase that follows established patterns:** use assumptions mode with the recommended defaults, show the list, and proceed unless the user objects.
- **Decision affects later phases too** (auth approach, data model conventions): also record it under Project decisions in STATE.md.
