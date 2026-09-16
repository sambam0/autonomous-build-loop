<!-- autonomous-build-loop:start -->
## Autonomous build loop
This repo is built with a spec-driven loop. Start every session by reading `.loop/STATE.md` (where the project is and what to do next) and `.loop/RULES.md` (standing rules).
Phases live in `.loop/phases/<NN-name>/` (CONTEXT, UI-SPEC when there's UI work, SPEC, PROGRESS, VERIFICATION). The gate is `.loop/verify.sh`: nothing is done until it passes.
<!-- autonomous-build-loop:end -->
