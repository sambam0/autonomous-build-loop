# Grok Bot adapter for autonomous-build-loop

Drive the existing `.loop/` harness from a Grok Bot / Cursor multi-agent crew. **Do not fork the loop philosophy into chat-only state.** The CLI skill remains the execution core; this folder is how the crew *operates* it.

## When to use this adapter vs pure CLI

| Mode | When | Who runs the harness |
|------|------|----------------------|
| **Pure CLI** | Human at the Mac; overnight `tmux` + Claude/Codex/Gemini/OpenCode; no need for crew glue | Human (or local CLI only) |
| **Crew + adapter** | Solo founder wants Orchestrator to babysit, Engineer/CloudAgent to execute slices, Reviewer for fresh judges — without the human routing every chat | Loop owner (Orchestrator) + specialists |

If the work is a few known lines, use the skill’s **Direct** track in whatever session you’re in — skip this adapter.

## Board ownership (one-liner)

**Orchestrator defers coding phases to `.loop/`** (STATE, SPEC, PROGRESS, VERIFICATION). `/home/box/orchestrator/inflight.md` mirrors crew status only — it is not a second product board. Use this skill's **Orchestrate a goal** path (`SKILL.md` + `references/orchestrate.md`) to assign specialists; once a coding goal is in execute/verify, **`.loop/STATE.md` is source of Next action** (see `STATE-INFLIGHT.md`). Do not keep a sibling `orchestrate-a-goal` skill — that content lives in the loop now.

## Loop owner duties (Orchestrator)

1. Orient: read `.loop/STATE.md`, run `.loop/status.sh` when a read path exists.
2. Keep discuss / UI approve / ship with the human; do not skip them in chat.
3. Dispatch specialists with briefs from `briefs/` (same shape as `references/orchestrate.md`: Goal, Your slice, Context, Constraints, Done means, Report back) that point at concrete `.loop/` paths. Minimum assignees; no awareness-only pings.
4. Update inflight from STATE after meaningful steps — never invent Next action.
5. Escalate to the human per the map below; never push/PR from babysit.
6. **Never treat “already talked in Orchestrator thread” as plan-check or goal-verify.** Fresh-context judges only (see ROLE_MAP).

## Human escalation map

Escalate to the human when:

- Product / priority decision that changes success criteria or locked CONTEXT decisions
- Credentials, payments, external sends, destructive or hard-to-undo actions
- Ship / push / open PR (always ask)
- Blocked tasks needing `DECISION NEEDED` or `HUMAN ACTION`
- Exit / status: human verification needed (7), gaps remain (8), or repeated stall with no specialist path
- Safety / policy uncertainty

Do **not** escalate for ordinary handoff glue, which specialist to pick when ROLE_MAP is clear, or “confirm continue” when STATE Next action is already clear.

## Roles in v1

Documented briefs: **executor**, **plan-checker**, **goal-verifier** only.  
Deferred: ui-checker, per-task reviewer playbooks (use `role.sh` / CLI until those exist).  
**Researcher is out-of-band for coding waves** — do not map them into executor/plan/verify.

## Composition (Slice B)

See **`COMPOSITION.md`**: `PARALLEL=1 wave.sh prepare` → Engineer/CloudAgent on the printed prompt → `results/<id>.md` → `wave.sh merge` → gate. Sequential only; no `AGENT_CMD` wrapper. CloudAgent maps via host-slot bridge (A) or self-contained VM wave (B).

## Babysit (Slice C playbook)

See `BABYSIT.md` — how Orchestrator reads status/logs, exit map, inflight mirror, re-dispatch vs Samuel ping. **No standing routine until an overnight dry-run with zero false pings.**

## Related files

- Skill **Orchestrate a goal** — `../../SKILL.md` (section) and `../../references/orchestrate.md` (brief template, roster, board)
- `COMPOSITION.md` — prepare → executor → results → merge → gate
- `ROLE_MAP.md` — loop role → crew specialist → dispatch surface
- `STATE-INFLIGHT.md` — dual-state sync rules
- `MIRROR.md` — Mac SoT vs box mirror
- `briefs/` — copy-paste dispatch templates (executor, plan-checker, goal-verifier)
- `BABYSIT.md` — Orchestrator babysit playbook (Slice C; no routine yet)  
