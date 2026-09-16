# Composition playbook — CloudAgent / Engineer as wave executor

Drive one execute wave **without** an `AGENT_CMD` sync wrapper. The harness stays on `wave.sh` / `lib.sh`; the crew (or a Cursor CloudAgent) is the worker.

**v1 scope:** sequential only (`PARALLEL=1`). No parallel selection changes. No `lib.sh` Grok branches. An `AGENT_CMD` wrapper is a later slice only if this playbook is too slow.

Related: `briefs/executor.md`, `ROLE_MAP.md`, `wave.sh` usage, `templates/PROMPT.md` → Parallel worker mode.

---

## Exact flow

```
wave.sh prepare  →  CloudAgent / Engineer on prompt  →  results/<id>.md  →  wave.sh merge  →  gate
```

### 1. Orient

- Repo has a clean tree (prepare refuses dirty work).
- Active phase exists under `.loop/phases/…` with ready `- [ ]` tasks in `PROGRESS.md`.
- Loop owner (Orchestrator) reads `.loop/STATE.md` / `status.sh` when available; does not invent Next action.

### 2. Prepare (host that has the git checkout)

From the **repo root** on the host that owns the worktrees (Mac CLI, Engineer-on-Mac Shell, or the CloudAgent VM itself when using mapping B below):

```bash
PARALLEL=1 .loop/wave.sh prepare
```

`wave.sh` defaults `PARALLEL` to 3 when unset or `< 2`, so **always export `PARALLEL=1`** for crew composition.

Stdout: one TSV line per worker (v1: exactly one):

```text
TASK_ID<TAB>SLOT_PATH<TAB>PROMPT_FILE
```

(Manifest columns are `k id SLOT_PATH base PROMPT_FILE`; `prepare` prints `id SLOT_PATH PROMPT_FILE` via `cut -f2,3,5`.)

Also written:

- `.loop/logs/wave-label` — wave label
- `.loop/logs/wave-<label>-<id>.prompt.md` — full worker prompt (`PROMPT.md` + harness context)
- Slot worktree at `SLOT_PATH` on branch `loop-slot-<k>`

If prepare exits 2 (`no ready tasks`) or 1 (dirty tree / wave already prepared), stop and report **BLOCKED** with the stderr reason — do not invent a task.

### 3. Execute (Engineer / CloudAgent)

Fill `briefs/executor.md` (or equivalent CloudAgent prompt) with:

| Placeholder | Value |
|-------------|--------|
| `{{TASK_ID}}` | printed task id |
| `{{PROMPT_FILE}}` | printed prompt path (or paste its contents if the worker cannot see the host path) |
| `{{CWD}}` | `SLOT_PATH` for mapping A; CloudAgent checkout / slot path for mapping B |
| `{{REPO_ROOT}}` / `{{PHASE_DIR}}` | from repo + active phase |

Worker must:

1. Read the prompt file (or pasted prompt). Mode is **PARALLEL WORKER** even when `PARALLEL=1` — that is how `wave_prepare` labels the harness context.
2. Implement **only** that task. Do not edit `PROGRESS.md` or `.loop/STATE.md`.
3. Write `<phase>/results/<task id>.md` in merge-expected format (below).
4. Commit code + results file on the worker branch (`loop-slot-<k>` or the CloudAgent branch in mapping B). Message shape: `P<phase>-<id>: <summary>`.
5. Stop. No push/PR from the worker unless the loop owner explicitly asked for a dry-run PR.

Do **not** call `wave.sh run` in this playbook — that path is the CLI `AGENT_CMD` / headless agent runner. Composition replaces `run` with a crew/CloudAgent dispatch.

### 4. Results file (merge-expected)

Path: `<phase>/results/<task id>.md`

```text
Result: done
(or) Result: blocked: <DECISION NEEDED | HUMAN ACTION | VERIFY PACKAGE | reason>

## Notes
- <files created, gotchas, deviations>

## Deferred
- <out-of-scope issues>

## For the human
- <anything a person must do>
```

`wave_merge` reads the `Result:` line (`done*` → mark `[x]`; `blocked*` → mark `[!]` with `BLOCKED: …`). Missing/invalid results leave the task open for review.

### 5. Merge + gate (same host as prepare)

```bash
.loop/wave.sh merge
```

On success prints `Merged:…` then runs `.loop/verify.sh`:

- `Gate: PASS` — wave done; continue or stop per STATE.
- `Gate: FAIL` (exit 3) — see `.loop/LAST_VERIFY.txt`; fix before the next wave. Report **BLOCKED: VERIFY PACKAGE** (or fix-forward if the loop owner owns the fix).

Optional cleanup when slots are finished:

```bash
.loop/wave.sh clean
```

---

## How CloudAgent maps to a worker (v1)

CloudAgent always works on a **remote checkout + branch/PR**. Loop slots are **local git worktrees** (`loop-slot-*`). Those are not the same filesystem. Pick one mapping and stick to it for the wave.

### Mapping A — Host slots, CloudAgent as content worker (path bridge)

**Prepare + merge** run on a host that has the repo (usually Mac).

1. Host: `PARALLEL=1 .loop/wave.sh prepare` → capture `TASK_ID`, `SLOT_PATH`, `PROMPT_FILE`.
2. Read `PROMPT_FILE` on the host; paste full text into the CloudAgent launch prompt (CloudAgent cannot see Mac `SLOT_PATH`).
3. CloudAgent implements the task on its branch; writes `results/<id>.md`; commits.
4. **Bridge:** bring CloudAgent’s commit onto `loop-slot-<k>` on the host (cherry-pick / apply patch / merge the CloudAgent branch into the slot branch), **or** merge the CloudAgent branch onto the phase branch and then run a host-side merge path that still applies the results file. Prefer cherry-pick onto the prepared slot branch so `wave.sh merge` stays unchanged.
5. Host: `.loop/wave.sh merge` → gate.

Use when overnight Mac babysit owns the worktrees and CloudAgent is only the coding muscle.

**Honest BLOCKED:** if the bridge cannot land commits on `loop-slot-<k>` before merge (auth, conflict, missing results file), stop with reason — do not edit PROGRESS by hand to fake done.

### Mapping B — CloudAgent self-contained wave (preferred when CloudAgent is primary executor)

**Prepare, execute, and merge all run inside the CloudAgent VM checkout.** Slot worktrees are created on that VM, so path skew disappears for v1 sequential waves.

1. CloudAgent ensures `.loop/` exists (`bash <skill-dir>/scripts/init.sh` from the Mac/box skill mirror, or an already-vendored `.loop/` in the repo). Confirm `VERIFY_CMD` / gate is sane for a smoke phase.
2. Create or reuse a **throwaway** phase (docs-only / harness smoke). One ready tracer task. Do not invent Carnile product features.
3. `PARALLEL=1 .loop/wave.sh prepare` inside the VM checkout.
4. Same agent (or a follow-up turn) executes the printed prompt in `SLOT_PATH`, writes `results/<id>.md`, commits on `loop-slot-<k>`.
5. `.loop/wave.sh merge` → gate on the same checkout.
6. Open a PR only if the loop owner asked for dry-run evidence; never ship from babysit.

Use when Samuel’s Q1 choice is CloudAgent-primary and Mac CLI is not driving the wave.

**Sequential only:** never launch multiple CloudAgents against one prepare when `PARALLEL>1` until a later slice proves disjoint Files + multi-slot merge. v1 always `PARALLEL=1`.

---

## Engineer without CloudAgent

Same flow as Mapping A steps 1–5, but the executor is a Grok Bot Engineer session (or Mac shell agent) with `cwd = SLOT_PATH` and instruction = follow `PROMPT_FILE`. Prefer CloudAgent for non-trivial repo edits per crew defaults.

---

## Honest BLOCKED outcomes

Report **BLOCKED** (and write `Result: blocked: …` when a results file exists) when:

| Situation | Typical reason tag |
|-----------|-------------------|
| Dirty tree / wave already prepared / no ready tasks | harness prepare failure (cite stderr) |
| Missing credentials, payments, external sends | `HUMAN ACTION` |
| Locked CONTEXT decision cannot ship at full scope | `DECISION NEEDED` |
| Gate fails after merge and is not a quick fix owned by this wave | `VERIFY PACKAGE` |
| CloudAgent ↔ slot bridge failed (Mapping A) | reason in Notes / For the human |
| Skill / `.loop/` missing on the executor host and cannot be installed | `HUMAN ACTION` or setup reason |

Never mark done while verify fails. Never weaken tests to pass the gate. Never push/PR from composition babysit unless Samuel explicitly approved that dry-run PR.

---

## Checklist (one sequential wave)

- [ ] `PARALLEL=1` set for prepare
- [ ] Worker used prompt / PARALLEL WORKER rules
- [ ] `results/<id>.md` has valid `Result:` line
- [ ] Commit on worker/slot branch includes results file
- [ ] `wave.sh merge` then gate PASS **or** documented FAIL/BLOCKED with evidence
- [ ] Inflight/STATE updated by Orchestrator from real STATE — not invented

## Host gotcha (dry-run finding)

On hosts without `user.name` / `user.email`, `git merge` inside `wave.sh merge` can fail and be reported as `T01:conflict` even with a clean tree. Set for the merge process (does not require writing git config):

```bash
export GIT_AUTHOR_NAME='…' GIT_AUTHOR_EMAIL='…'
export GIT_COMMITTER_NAME='…' GIT_COMMITTER_EMAIL='…'
```

Then re-run prepare → worker → merge. Gate may still print PASS if `VERIFY_CMD` is trivial — always check `Merged:` for `*:merged` vs `*:conflict`.

