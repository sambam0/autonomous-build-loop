# Goal
Fold "Orchestrate a goal" into the Autonomous Build Loop so phase/goal orchestration is *inside* the loop skill, not a separate parallel practice.

**Status:** folded. See `CHANGELOG.md`, SKILL.md **Orchestrate a goal**, and `references/orchestrate.md`. `_incoming/orchestrate-a-goal/` was removed after absorption. This file is the original brief.

# Sources (attached under uploads/)
- `autonomous-build-loop/` — current loop skill (SoT mirror)
- `orchestrate-a-goal/` — Grok Bot orchestrator skill to absorb

# What "inside the build loop" means
1. When a user goal is multi-agent / multi-specialist (not just execute tasks in worktrees), the loop should **orchestrate**: restate goal + success criteria → scoped tasks with owner/input/output/escalate → in-flight board → self-contained briefs → minimum assignees → status back to human.
2. Map orchestrate concepts onto existing loop stages (don't invent a second top-level workflow):
   - Roadmap / Discuss / Plan: goal breakdown + specialist ownership where relevant
   - Execute: handoffs / briefs for parallel roles (executor, reviewer, tester) using the brief template
   - STATE / PROGRESS / inflight-style tracking: Active / Queued / Blocked without forcing Grok-only paths
3. Keep the loop usable **standalone** (Claude Code / Codex / headless) — Grok Bot paths (`/home/box/orchestrator/inflight.md`, SendToAgent) are an **adapter**, not a hard dependency. Prefer a thin `adapters/grok-bot.md` (or extend existing adapters/) that says how an Orchestrator bot maps roster → loop roles.
4. Do **not** dilute verify/ship gates. Orchestration does not skip plan-check, test gate, or goal verification.
5. Preserve autonomous-build-loop naming, `.loop/` layout, and scripts unless a tiny additive file is clearly better.

# Deliverables
1. Updated `SKILL.md` with a clear "Orchestrate a goal" section (when to orchestrate vs pure execute) and steps wired into roadmap→plan→execute.
2. Updated or new reference (e.g. `references/orchestrate.md` or section in `planning.md` / `agents.md`) with brief template + roster mapping (Orchestrator/Engineer/Loopsmith/Reviewer/Researcher/Tester → loop roles).
3. Adapter note for Grok Bot (optional but preferred) if adapters/ already exists.
4. Short CHANGELOG or PR description of what changed.
5. Open a PR (or commit on main if new Origin repo) with the skill package ready to copy into `~/.cursor/skills/autonomous-build-loop`.

# Done when
- A reader of SKILL.md can run goal→phases **and** fan work to specialists using one skill.
- Orchestrate-a-goal content is absorbed (not merely linked as "see other skill").
- No secrets; no Carnile product code changes unless needed for examples (prefer none).
