# UI design stage

For phases with user-visible interface work, write a UI contract between discuss and plan. Without one, every fresh-context session restyles from scratch, and the result drifts toward generic component-library defaults. The gate can't catch that, because nothing about "looks like a template" fails a test.

The contract fixes this in two ways. It pins tokens, component states, and copy so executors build the same thing. And it turns much of "does it look right" into checks the ui-checker can verify from code and screenshots.

## Contents
- When to run it
- Step 1: Research the existing design system
- Step 2: Write the contract with the user
- Writing acceptance checks
- Step 3: Plan against the contract
- Screenshots setup
- How verification uses it

## When to run it

Run the UI stage when a phase adds or changes screens, components, or visual states a user will see. Skip it for backend-only phases, and for tiny UI tweaks that just follow an existing component (note the component in CONTEXT.md instead).

Create the phase with `--ui`, or add the contract later:
```bash
.loop/new-phase.sh "Margin notes" --ui
cp .loop/templates/phase/UI-SPEC.md .loop/phases/<phase>/UI-SPEC.md
```

Set STATE.md Stage to `ui` while working on it.

## Step 1: Research the existing design system

Spawn `loop-ui-researcher` (Claude Code) or run `.loop/role.sh ui-researcher`. It reads token sources, the component library, the screens closest to this phase, and motion patterns, and it takes screenshots of related routes when it can. You get back tokens in use, available components and their missing states, patterns to follow, inconsistencies, and a suggested direction.

With cross-model review on, running a second researcher on the other model is rarely worth it. Save the second opinion for the ui-checker.

## Step 2: Write the contract with the user

Work through UI-SPEC.md in this order, asking the user where the answer is a matter of taste:

1. **Design direction.** Two to four sentences on feel, anchored in what exists. Always name anti-references, meaning what it must not look like. "Not a default shadcn card grid, not a light SaaS dashboard" gives executors something concrete to avoid.
2. **Tokens.** Reference existing tokens by name, taken from the researcher's findings. Mark anything new as NEW and get explicit approval, because a new color or font size is a design-system change.
3. **Screens.** For each screen: route, layout regions in order, and responsive behavior.
4. **Components.** Reuse wherever possible. For every component, list the states it must implement. Missing states (loading, empty, error, disabled, focus-visible) are the most common UI gap agents leave.
5. **Interactions and motion.** Trigger, response, duration and easing token, and reduced-motion behavior.
6. **Copy.** Exact strings for headings, buttons, empty states, and errors. Agents invent filler copy unless strings are pinned.
7. **Accessibility.** Keep the defaults, and add anything product-specific.
8. **Acceptance checks.** See below.
9. **Screenshots.** List the routes to capture.

Show the user the finished contract. When they approve, set `Status: approved`. The loop refuses to run a phase whose UI contract isn't approved.

## Writing acceptance checks

Acceptance checks must be verifiable from code or a screenshot without taste. Anything that needs taste goes in the human-judged list.

| Not checkable | Checkable |
|---|---|
| Buttons look consistent | UI-01: All actions on /craft use `Button` from components/ui/button.tsx with the `pill` variant; no other button elements or classes |
| Uses the brand colors | UI-02: New components contain no hex, rgb, or hsl values and no arbitrary Tailwind color classes; colors come from `--color-*` tokens |
| Handles loading nicely | UI-03: The notes panel renders a skeleton while fetching, "No notes yet. Keep writing." when empty, and the error copy with a Retry button on failure |
| Responsive | UI-04: Below 768px the margin panel collapses into a bottom sheet toggled by the Notes button; at 1280px it's a fixed right column |
| Accessible | UI-05: Every icon-only button has an aria-label; the notes panel is reachable by Tab and closes with Escape |
| Feels premium | Human-judged: overall feel matches the design direction at 390px and 1440px |

Aim for 5 to 12 checks per UI phase. Each check should fail if an executor took the generic shortcut.

## Step 3: Plan against the contract

When writing SPEC.md:
- Every UI-xx check is covered by at least one task (`Covers: MH-2, D-03, UI-01, UI-03`).
- UI tasks put `UI-SPEC.md` first in "Read first", along with the component source files they'll use.
- "Done when" names the states and copy that must exist, plus a component test where the project has component testing.
- Human-judged items go under "For the human" in PROGRESS.md.

The plan-checker blocks plans with an unapproved contract or uncovered checks.

## Screenshots setup

Screenshots let the ui-checker (and the researcher) actually look at the result. They need three things:

1. **Playwright in the project:** `npm i -D @playwright/test && npx playwright install chromium`, or the equivalent for your package manager. The script resolves Playwright from the project, so nothing is installed globally.
2. **A reachable app.** Set `UI_BASE_URL`. To have the script start and stop the dev server itself, set `UI_START_CMD` (for example `pnpm dev`). It waits up to 3 minutes for the URL to respond.
3. **Auth, for logged-in pages.** Save a session once with `npx playwright codegen --save-storage=.loop/ui-auth.json <UI_BASE_URL>`, log in, close the window, and set `UI_STORAGE_STATE=".loop/ui-auth.json"`. The file is gitignored. Use a test account, never a real one.

Then run:
```bash
.loop/ui-snap.sh             # routes from the contract's Screenshots section
.loop/ui-snap.sh /craft /    # or explicit routes
```

Screenshots land in `.loop/logs/screens/<phase>/<timestamp>/` at every `UI_VIEWPORTS` size. The script also reports redirects (usually missing auth), HTTP errors, and console errors per page.

In parallel waves or unattended runs, several processes can't share one dev server port. Screenshots belong in verification, which runs once in the main checkout, not in executor iterations.

## How verification uses it

When a phase has UI-SPEC.md, the verify iteration runs the ui-checker alongside the goal-verifier, and the ui-checker also runs on the reviewer model when cross-model review is on. The ui-checker audits the changed files for token use, component reuse, states, copy, and accessibility, then audits the screenshots against screens and the design direction.

In VERIFICATION.md:
- A FAIL on any UI check makes the status `gaps_found` and becomes a gap task.
- HUMAN items go to "For the human" and make the status `human_needed` when everything else passes.
- A preference that isn't in the contract is never a failure. If the user wants it enforced, add it to the contract and re-verify.
