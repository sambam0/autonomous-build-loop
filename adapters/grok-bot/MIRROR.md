# Skill mirror — Mac SoT vs box

## Locations

| Copy | Path | Role |
|------|------|------|
| **Source of truth (SoT)** | `~/.cursor/skills/autonomous-build-loop` on Samuel’s Mac | Cursor-installed skill; edits that matter for Cursor live here |
| **Package** | `~/autonomous-build-loop.skill` (Mac) | Distributable package; refresh when releasing |
| **Box mirror** | `/home/box/orchestrator/autonomous-build-loop` | Crew-readable copy for Grok Bot agents |

## Policy (v1 default)

1. **Mac SoT wins** on conflict for skill content (SKILL.md, scripts, templates, references, adapters).
2. **Crew may edit the box mirror** when implementing approved adapter/docs slices (e.g. Slice A). After edits, **sync box → Mac SoT** in the same effort whenever machine access allows.
3. Do not silently diverge scripts/harness on box without Mac sync — harness changes are rare and must land on SoT.
4. Project `.loop/` directories live **inside each git repo**, not in the skill folder. Mirroring the skill does not mirror project state.

## Who syncs when

| Event | Who | Action |
|-------|-----|--------|
| Approved adapter/docs written on box | Implementing specialist (usually Loopsmith) | Copy changed paths to Mac SoT; report sync status |
| Human edits skill on Mac | Human (or ask Engineer/Loopsmith) | Refresh box mirror before crew uses it |
| Before Slice B/C or overnight babysit | Orchestrator | Confirm box `adapters/grok-bot/` matches Mac (or note drift) |

## Sync commands (Mac connected)

From a Grok Bot session with Mac `machineId` available, copy at least:

- `adapters/grok-bot/**`
- `SKILL.md` (if Adapters subsection changed)

Example intent (paths may use CopyFromBox / scp / rsync depending on tools):

```text
Box:  /home/box/orchestrator/autonomous-build-loop/adapters/grok-bot/
Mac:  ~/.cursor/skills/autonomous-build-loop/adapters/grok-bot/

Box:  /home/box/orchestrator/autonomous-build-loop/SKILL.md
Mac:  ~/.cursor/skills/autonomous-build-loop/SKILL.md
```

If Mac is disconnected or write fails: leave box as the working crew copy, document “sync pending” in the handoff, and ask the human or Orchestrator to refresh SoT before treating Mac as current.

## Drift check

```bash
# On Mac
diff -rq ~/.cursor/skills/autonomous-build-loop/adapters/grok-bot \
  /path/to/box-mirror/adapters/grok-bot   # after copying box tree locally, or compare checksums
```

Crew planning against a stale mirror is a defect — fix mirror before new slices.
