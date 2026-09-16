Status: draft

The UI contract for this phase, written between discuss and plan. Approved before planning (set `Status: approved`).
Planning turns Acceptance checks into tasks; the ui-checker audits the result against this file.

## Design direction
<2–4 sentences on the intended feel, grounded in the product's existing look>
References (match these): <existing screens, files, or screenshots>
Anti-references (must not look like this): <e.g. default component-library styling, generic SaaS dashboard>

## Tokens
Use existing tokens by name. List only what this phase uses; mark anything new as NEW (needs approval).

| Kind | Token | Value | Source |
|---|---|---|---|
| Color | | | |
| Type | | | |
| Spacing | | | |
| Radius | | | |
| Motion | | | |

## Screens
### S1: <screen name> (route `/path`)
Layout: <regions and hierarchy, top to bottom>
Responsive: <what changes below and above the breakpoint>
Components: <which components from the table below>

## Components
| Component | Source (existing path, or NEW) | States required |
|---|---|---|
| | | default, hover, focus-visible, disabled, loading, empty, error |

## Interactions and motion
- <trigger → response, duration and easing tokens, reduced-motion behavior>

## Copy
Exact strings. Tasks must use these verbatim.

| Where | Text |
|---|---|
| | |

## Accessibility
- Text and controls meet WCAG AA contrast
- Every interactive element is keyboard reachable with a visible focus style
- Icon-only buttons have accessible names
- Motion respects prefers-reduced-motion

## Acceptance checks
Checkable from code or screenshots. Tasks list the IDs they cover. Keep taste out of this list.
- UI-01: <e.g. primary actions use the pill Button variant from components/ui/button.tsx; no other button styles on this screen>
- UI-02: <e.g. new components use only tokens: no hex/rgb values, arbitrary Tailwind values, or font-family declarations>
- UI-03: <e.g. every async surface renders loading, empty, and error states with the copy above>

Human-judged (goes to "For the human" in PROGRESS.md):
- <e.g. overall feel matches the design direction at 390px and 1440px>

## Screenshots
Routes for `.loop/ui-snap.sh` (one per line, starting with /):
- /
