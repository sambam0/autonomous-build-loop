# Role map — autonomous-build-loop ↔ Grok Bot crew

Generic loop roles (left) map to crew specialists (right). Prefer the **minimum sequential** assignee. Do not fan out the same ask.

| Loop role | Crew specialist | Dispatch surface (v1) | Notes |
|-----------|-----------------|----------------------|--------|
| Loop owner / orient / babysit | **Orchestrator** | Owns inflight + STATE sync; may run `status.sh` via machine Shell or Engineer proxy | Not an executor |
| executor | **Engineer** | Cursor CloudAgent (preferred for repo work) or 1:1 brief pointing at prompt file / task | Writes code; commits on phase/slot branch; writes `results/<id>.md` when using waves |
| plan-checker | **Reviewer** | Separate 1:1 agent turn (fresh context) or `.loop/role.sh plan-checker` | Must not be the session that wrote the plan |
| goal-verifier | **Reviewer** (or Engineer only if Reviewer unavailable — still fresh turn) | Separate turn or `.loop/role.sh goal-verifier` | Must not be the session that implemented the phase |
| ui-checker | **Tester** (deferred brief) | `.loop/role.sh ui-checker` until brief exists | Fresh context; screenshots |
| ui-researcher | **Tester** or Engineer | `.loop/role.sh ui-researcher` | Before UI-SPEC |
| reviewer (per-task) | **Reviewer** (deferred brief) | Fresh turn or `role.sh reviewer` | Optional; not in v1 briefs/ |
| cross-reviewer | Second model via `role.sh --reviewer` | CLI | Keep on REVIEW_AGENT; not a crew chat substitute |
| explorer / test-runner / codebase-mapper | **Engineer** (or CLI `role.sh`) | As needed | Read-only except codebase-mapper → CODEBASE.md |
| discuss / roadmap / ship facilitation | **Orchestrator** + **human** | Chat with human | Human approves roadmap, UI-SPEC, ship |

## Explicit non-maps

| Specialist | Coding-wave role? |
|------------|-------------------|
| **Researcher** | **No.** Out-of-band (social intel, market, YC evidence). Do not assign executor / plan-checker / goal-verifier. |
| **Loopsmith** | Meta only (skill/adapter/routine design). Not a coding executor unless the task is adapter docs. |
| **Tester** | Eval / UI / probe phases — not default executor for product features. |

## Fresh-context rule

Plan-checker, goal-verifier, and ui-checker **must** run in a context that did not produce the work.  
Invalid: “Reviewer already saw it in the Orchestrator thread.”  
Valid: new 1:1 brief, `role.sh`, or cross-model `--reviewer`.
