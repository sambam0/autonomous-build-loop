# STATE.md ↔ inflight.md

## Sources of truth

| Concern | Source of truth | Mirror / note |
|---------|-----------------|---------------|
| Coding phase stage, Next action, blockers, log | **Repo `.loop/STATE.md`** | Always read first when a repo loop exists |
| Phase decisions | Phase `CONTEXT.md` / `SPEC.md` | Not on inflight |
| Task checklist / results | Phase `PROGRESS.md`, `results/` | Not on inflight |
| Verification status | Phase `VERIFICATION.md` | Summarize on inflight only when Active |
| Crew who-is-doing-what across goals | **`/home/box/orchestrator/inflight.md`** | Coordination only |
| Goal breakdown / specialist assignment recipe | Skill **Orchestrate a goal** | Defers coding execute/verify to `.loop/` |

## Who updates what

| Actor | Updates STATE.md | Updates inflight.md |
|-------|------------------|---------------------|
| Human or CLI loop session | Yes (after meaningful steps) | Optional |
| Orchestrator (loop owner) | Yes when driving discuss/plan/ship in crew mode — keep Next action exact | Yes — Active/Queued/Blocked from STATE |
| Engineer / CloudAgent executor | Progress via PROGRESS / results / commits; may append STATE Log if brief says so | No (Orchestrator mirrors) |
| Reviewer (judges) | Writes/merges into plan-check notes or VERIFICATION as role requires | No |

**Orchestrator never invents Next action.** If STATE is missing or stale, fix STATE (or ask the human) before changing inflight.

## Sync cadence

1. Before any crew dispatch on a coding goal: read STATE (+ `status.sh` if available).
2. After Collect from a specialist: update STATE if the stage/Next action changed; then mirror Active row on inflight.
3. On loop exit / babysit check: map status to inflight Blocked or Done; ping human per README escalation map.
4. When closing a coding goal on inflight: require STATE stage `ship` complete or human-accepted stop — not vibes.

## Inflight Active row shape (coding goals)

| Task | Owner | Done means |
|------|-------|------------|
| `<phase>: <STATE Next action one-liner>` | Specialist from ROLE_MAP | Evidence path under `.loop/` or gate/VERIFICATION status |

## Dual-board anti-pattern

Do **not** keep a parallel task list on inflight that disagrees with PROGRESS.md. Inflight points at the phase and owner; PROGRESS owns checkboxes.
