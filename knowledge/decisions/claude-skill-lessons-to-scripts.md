---
type: Decision
title: Graduate Session-Coordinator Lessons Into Deterministic Scripts
description: Mechanical mission lessons from the session-coordinator skill's LESSONS.md are enforced by self-tested scripts (monitoring, status hygiene, CI/merge races, locking, spawn preflight) instead of prose the coordinator model must remember; prose stays only for judgment calls.
tags: [claude, tooling]
timestamp: '2026-07-28T20:08:06-07:00'
---

**Status:** active. **Where:**
[`home/claude/.claude/skills/session-coordinator/scripts/`](../../home/claude/.claude/skills/session-coordinator/scripts),
[skills deployment](claude-skills-split-stow-packages.md),
[herdr](../modules/herdr.md), [tmux](../modules/tmux.md).

## Context

The skill's Step-7 retrospective appends mission lessons to `LESSONS.md`
(which lives in-repo — see the
[deployment decision](claude-skills-split-stow-packages.md)). After three
missions (~28 lessons) the same failure classes kept recurring despite being
recorded: single-read idle alerts that were turn-boundary races, self-stamped
status times drifting hours behind wall clock, recalled commit SHAs citing
objects that did not exist, CI verdicts reused across a superseding push,
hand-retyped `heavy.lock` recipes. A prose lesson relies on the coordinator —
a model — re-reading and remembering it under load, which is exactly when it
fails.

## Decision

Every lesson that is *mechanical* gets enforced by a script; each script
ships a `--self-test` (the skill's retrospective rule mandates rerunning it
after any script change). Two batches, commits `5e6871f` and `024351a`:

- `heartbeat.sh` — debounced teammate monitor (every non-working state needs
  2 consecutive reads; tmux classifies by the spinner line, herdr by
  `herdr agent get`'s `agent_status`); auto-submits stranded input-box
  prompts through msg-teammate.sh's verified bare-Enter.
- `log-status.sh` — status lines stamp `date +%H:%M` and
  `git rev-parse --short HEAD` themselves; `--retract` emits the
  `*** RETRACTION ***` banner.
- `ci-watch.sh` / `merge-pr.sh` — checks stream against an armed head SHA,
  verdicts voided if the head moves; merges refuse on SHA mismatch, then arm
  `gh pr merge --auto`.
- `with-heavy-lock.sh` — the canonical `heavy.lock` mutex (owner file,
  trap-release, atomic-rename stale-holder stealing).
- `stand-down.sh` — end-of-mission gate: lock free, worktrees clean, no
  commit unreachable from every remote ref.
- `spawn-teammate.sh` preflight (refuses unexpanded brief placeholders and
  primary-checkout workdirs) and `msg-teammate.sh --inbox` (mirrors a
  directive to the teammate's inbox file *before* attempting delivery).
- Integration-policy gate (user-feedback-driven, same day): a mandatory
  Step-1 decision recorded in `<scratch>/mission-policy` — `no-github` |
  `push-only` | `prs-user-merge` | `prs-auto-merge`. spawn-teammate.sh
  refuses briefs that don't declare the level, and merge-pr.sh refuses any
  merge the policy doesn't explicitly permit (no file → no merge; per-PR
  `--user-approved` under `prs-user-merge`). Added after a mission opened
  PRs and merged to main against an explicit "no PRs" — the mode where the
  user runs adversarial review in a separate session depends on merges
  waiting for them.

Method notes: self-tests mock external CLIs on `PATH` (`gh`) rather than
touching real PRs, and the herdr JSON field was verified against the live
server before use — a guessed field name caused a false-MISSING in a prior
mission, so the scripts' own construction followed the lesson they encode.
Epistemic lessons (hypothesis labeling, ALL/ONLY/LAST enumeration demands,
mutation-gated guard tests) deliberately stay prose: a script pretending to
check judgment would give false assurance.

## Consequences

- The encoded failure classes cannot recur by forgetting — they are
  structural now. `LESSONS.md` Action lines flipped to APPLIED, so future
  retrospectives don't re-propose them and the file remains the queue of
  *unencoded* knowledge.
- Scripts deploy through the stow-shared skill, so improvements propagate as
  ordinary commits like any dotfile.
- Watch-out: `heartbeat.sh`'s pane-text classifier (spinner regex,
  bottom-8-lines input-box heuristic) tracks Claude Code's TUI rendering —
  re-verify its self-test fixtures when the TUI changes. The
  [herdr](../modules/herdr.md) coupling is the `agent_status` field of
  `herdr agent get` (protocol 16 at time of writing); a schema change
  degrades classification to MISSING, which is the conservative direction.

## Citations

- Commits `5e6871f`, `024351a`
- [`LESSONS.md`](../../home/claude/.claude/skills/session-coordinator/LESSONS.md)
  — the lesson entries these scripts encode (`Action: APPLIED 2026-07-28`)
- [`SKILL.md`](../../home/claude/.claude/skills/session-coordinator/SKILL.md)
  — Steps 4–6 reference the scripts
