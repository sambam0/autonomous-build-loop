# Babysit playbook — Orchestrator watches a coding loop

Playbook only (Slice C). **Do not create a standing routine** until one real overnight dry-run completes with **no false pings**.

Related: `COMPOSITION.md`, `STATE-INFLIGHT.md`, `ROLE_MAP.md`, `README.md`, skill `references/failure-modes.md`.

---

## Purpose

While a phase is in **execute** / **verify** (CLI `loop.sh` overnight or crew `COMPOSITION.md` waves), the loop owner:

1. Reads real `.loop/` status (never invents Next action)
2. Maps stop / unhealthy signals → re-dispatch Engineer **or** ping Samuel
3. Mirrors Active on `/home/box/orchestrator/inflight.md` from STATE
4. **Never** push / open PR / merge to main from babysit

---

## Hard-gate: working read path

Babysit is **blocked** until Orchestrator can read **both**:

- Output of `.loop/status.sh` (run from **repo root**, not from inside `.loop/`)
- A progress log tail: `.loop/logs/run.log` when using `loop.sh`, **or** the composition substitutes below when only `wave.sh` was used

### Reachability matrix (document honestly each run)

| Path | How | status.sh | run.log | Valid for babysit? |
|------|-----|-----------|---------|-------------------|
| **Mac Shell** | `machineId` on Samuel’s Mac; `cd <repo>` then `.loop/status.sh`; `tail` logs | Yes when Mac **connected** and repo checked out | Yes if `loop.sh` ran there | **Valid** when connected |
| **Mac Shell** | Mac **disconnected** | No | No | **Blocked** — do not fake status |
| **Box checkout** | e.g. `/workspace/carnile` (Slice B dry-run mirror) | Yes from repo root | Only if `loop.sh` wrote it; composition dry-runs may have **no** `run.log` | **Valid** for STATE/status/PROGRESS; use substitutes for logs (below) |
| **Engineer proxy** | Brief Engineer: run status + tail logs on host that has the checkout; paste output | Via report | Via report | **Valid** when Engineer can reach the host |
| **CloudAgent VM** | Mapping B: prepare/merge inside CloudAgent checkout | On the VM only unless synced | On the VM only unless synced | **Valid on VM**; Orchestrator needs artifact sync, PR checkout, or Engineer proxy — **not** directly readable from box by default |

**Current known state (2026-09-11):** Mac machines reported **disconnected**. Slice B proved on **box** `/workspace/carnile` (status.sh works from repo root; composition used `wave.sh` → **no `run.log`**; gate evidence in `.loop/logs/*.gate.log`). Treat box checkout + Engineer proxy as the reachable pair until Mac reconnects or CloudAgent syncs artifacts back.

### Composition log substitutes (when `run.log` missing)

If the run used `COMPOSITION.md` / `wave.sh` only:

| Read | Why |
|------|-----|
| `.loop/STATE.md` | Next action, stage, blockers |
| `.loop/status.sh` | Tasks done/open/blocked, verification, gate hint |
| `.loop/logs/wave-*.gate.log` | Last merge gate |
| `.loop/LAST_VERIFY.txt` | Present ⇒ gate failing |
| Phase `PROGRESS.md` + `results/*.md` | Per-task done/blocked |
| `git log -5 --oneline` on phase branch | Whether workers committed |

Do **not** invent a `run.log` or claim `loop.sh` exit codes unless `loop.sh` actually ran.

### How to read (examples)

```bash
# Always from repo root
cd /path/to/repo
.loop/status.sh
tail -n 40 .loop/logs/run.log          # if exists (loop.sh)
tail -n 20 .loop/logs/*.gate.log       # composition
test -f .loop/LAST_VERIFY.txt && echo GATE_FAILING
```

If `status.sh` prints `loop: not inside a git repository`, you were not at repo root — fix cwd and retry.

---

## Check cadence (manual playbook)

1. Orient: read STATE.md → run status.sh → tail log / substitutes.
2. Update inflight Active from **STATE Next action** only (see STATE-INFLIGHT.md).
3. If healthy → **stay quiet** (no Samuel ping, no Crew spam).
4. If unhealthy / terminal → apply exit map below; re-dispatch or ping once with evidence paths.

---

## Exit / signal map

### A. `loop.sh` finished (last line of `run.log` is `LOOP END …`)

| Exit | Meaning | Action |
|------|---------|--------|
| **0** | Phase verified (or tasks done with verify skipped) | Quiet unless ship needed → ping Samuel only for ship/PR approval |
| **2** | Only blocked tasks left | Read `BLOCKED:` reasons. **Re-dispatch** Engineer if fix is code/setup within rules; **ping Samuel** for `DECISION NEEDED` / `HUMAN ACTION` / credentials |
| **3** | Stalled (no progress) | Read agent logs. **Re-dispatch once** with sharper task / trust fix if clear; if second stall → **ping Samuel** |
| **4** | Gate failing too often | **Re-dispatch** Engineer on verify fix; if environmental / flaky gate needs human → **ping Samuel** |
| **5** | Max iterations | **Ping Samuel** (Reviewer: always surface — do not silently raise MAX_ITERS) |
| **6** | STOP file | Quiet or short FYI; do not restart without owner intent |
| **7** | Human verification needed | **Ping Samuel** with VERIFICATION walkthrough |
| **8** | Gaps remain after gap rounds | **Ping Samuel** with VERIFICATION + gap tasks; optionally queue plan fix then Engineer — do not blind re-loop |

Setup failures (exit **1**) → **ping Samuel** or Engineer with stderr; treat as blocked babysit.

### B. Composition / mid-wave (no LOOP END yet)

| Signal | Action |
|--------|--------|
| status: open tasks, recent commits, gate passing, no LAST_VERIFY | **Healthy → quiet** |
| prepare failed / dirty tree / no ready tasks | **Re-dispatch** Engineer (or fix host); ping Samuel only if human-only |
| Worker `Result: blocked: …` | Same as exit 2 rules |
| `wave.sh merge` Gate FAIL / LAST_VERIFY present | **Re-dispatch** Engineer; ping if not fixable |
| Mapping A bridge failed (CloudAgent ↛ slot) | **Re-dispatch** Engineer on bridge; ping if auth/human |
| No status read path (Mac down, no box checkout, no proxy) | **Babysit blocked** — ping Samuel once that hard-gate failed; do not guess |

### Healthy → quiet

No ping when: status reachable, Next action clear, tasks progressing or done pending ship, gate green, no STOP, no blocked-only, no exit 3/4/5/7/8.

Empty “still running” check-ins are false pings — skip them.

---

## Re-dispatch Engineer vs escalate Samuel

**Re-dispatch Engineer** (1:1 or CloudAgent) when:

- Gate red with a clear code fix
- Worker blocked on VERIFY PACKAGE / missing results / merge conflict / slot setup
- Stall with obvious permissions/trust/task-size fix (once)
- Composition prepare/merge host steps need a pair of hands on the checkout

**Ping Samuel** when:

- DECISION NEEDED / HUMAN ACTION / credentials / spend / external send
- Ship / push / PR
- Exit 5, 7, 8 (and repeated 3)
- Product scope / locked CONTEXT change
- Hard-gate: no read path to status/logs

**Never from babysit:** push, PR, merge to main, weaken tests, invent STATE Next action, skip fresh-context judges by “already discussed in Orchestrator.”

---

## Inflight mirror

After each meaningful check:

| Inflight field | Source |
|----------------|--------|
| Active task text | `.loop/STATE.md` → ## Next action (verbatim sense) |
| Owner | ROLE_MAP for current stage |
| Blocked | PROGRESS blocked tasks or LOOP END exit 2/4/8 |
| Done | Only when ship complete or human-accepted stop |

Do not duplicate PROGRESS checkboxes on inflight.

---

## Standing routine (later — not now)

Create a routine **only after**:

1. One real overnight (or multi-hour) dry-run
2. Read path stayed valid for the whole run
3. **Zero false pings** (no healthy→noise)

Until then: manual playbook only. Routine prompt should say: stay quiet when healthy; use this exit map; never push/PR.

---

## Slice C checklist

- [ ] Read path chosen and recorded (Mac / box / proxy / VM)
- [ ] `status.sh` from repo root succeeded
- [ ] `run.log` tailed **or** composition substitutes used
- [ ] Inflight ← STATE Next (not invented)
- [ ] Action from map applied (quiet / re-dispatch / ping)
- [ ] No push/PR
- [ ] No standing routine created yet
