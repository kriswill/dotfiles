---
type: Decision
title: Ship User-Level Claude Skills as Split Stow Packages
description: 'User-level Claude Code skills deploy through two mirrored stow packages (claude for nixos, claude-me for the macs) sharing one copy via a repo-internal symlink, because stow cannot traverse the macs'' unowned ~/.claude fallback symlink.'
tags: [claude, stow, dotfiles]
generated: { by: okflight/0.4.0, at: 2026-07-25T23:35:00-07:00 }
sources:
  - id: gnu-stow-manual
    resource: https://www.gnu.org/software/stow/manual/stow.html
    title: GNU Stow manual
---

**Status:** active. **Where:** [`home/claude/`](../../home/claude),
[`home/claude-me/`](../../home/claude-me),
[stow tree pattern](../patterns/stow-tree.md),
[claude-account-selector](../modules/claude-account-selector.md).

## Context

The `session-coordinator` skill (a global Claude Code skill for running
coordinated multi-agent missions in tmux, distilled from the 2026-07-25
flake-explorer extractor session) needed to reach every machine's *user-level*
Claude config — not the repo-scoped `.claude/skills/` project skills. The
target differs per OS: nebula uses plain `~/.claude`, while the macs run the
[account selector](../modules/claude-account-selector.md) whose profile split
puts the personal config at `~/.claude-me`, with `~/.claude` existing only as
the selector's fallback symlink (`~/.claude -> ~/.claude-me`).

A single `.claude/...`-shaped stow package cannot serve both: GNU Stow refuses
to traverse a directory-position symlink it does not own (verified
empirically — `existing target is not owned by stow: .claude`), so on the macs
that package would conflict-skip forever and never deploy.

## Decision

Two thin stow packages share one copy of the skill:

- `home/claude/.claude/skills/session-coordinator/` — the canonical
  files; deploys on nebula, skip-listed on darwin.
- `home/claude-me/.claude-me/skills/session-coordinator` — a
  repo-internal relative symlink into the `claude` package; deploys on the
  macs (targeting the real profile dir, bypassing the unowned symlink),
  skip-listed on nixos.

Both skip-list entries carry why-comments per
[per-OS stow scoping](stow-os-skip-lists.md). The corporate profile
(`~/.claude-work`) is deliberately unwired; a `claude-work` package is the
extension point if a skill should ever ship there — the split keeps
per-profile skill sets an explicit, reviewable choice, which is the point of
[profile isolation](claude-profile-isolation.md).

A property worth knowing: the skill maintains a `LESSONS.md` that its own
post-mission retrospective appends to. Because deployment is stow links into
the live repo, those retrospectives write *into this repository* — skill
evolution shows up as ordinary `git diff`/history under
`home/claude/.claude/skills/session-coordinator/`, and syncs to the other
machines on pull like any dotfile. Mechanical lessons graduate from that
file into self-tested scripts — see
[lessons-to-scripts](claude-skill-lessons-to-scripts.md).

## Consequences

- New machines get the skill on first rebuild; edits and accumulated lessons
  propagate as commits, with no second copy to drift.
- Anything else that should land in the user-level Claude config follows the
  same recipe: put it in `home/claude/`, symlink it from `home/claude-me/`.
- Watch-out: the `claude-me` package reaches its content through a symlink
  inside the stow dir; if the `claude` package is ever renamed or moved, the
  relative link must move with it (`okf validate` will not catch it — stow's
  restow log on the macs will).

## Citations

- Commit `67d6f3c` (packages + skip lists), PR kriswill/dotfiles#45
  ownership/conflict semantics
