---
type: Decision
title: Ship Tool-Agnostic Agent Skills From an agents Stow Package
description: 'Skills that are not Claude-specific live in an agents stow package at ~/.agents/skills, with each Claude profile package carrying a repo-internal discovery symlink, so one copy serves every agent tool and every profile.'
tags: [claude, agents, stow, dotfiles]
generated: { by: okflight/0.4.0, at: 2026-08-19T11:35:00-07:00 }
sources:
  - id: adopt-a-dotfile-playbook
    resource: ../playbooks/adopt-dotfile.md
    title: Adopt a dotfile playbook
---

**Status:** active. **Where:** [`home/agents/`](../../home/agents),
[`home/claude/`](../../home/claude), [`home/claude-me/`](../../home/claude-me),
[`home/claude-work/`](../../home/claude-work),
[stow tree pattern](../patterns/stow-tree.md),
[split stow packages for Claude skills](claude-skills-split-stow-packages.md).

## Context

Two skills — `html-doc` (the house dark/light theme for standalone HTML
documents) and `test-system-prompt` (empirical system-prompt capture and
diffing) — were living untracked in `~/.agents/skills/`, with hand-made
symlinks from `~/.claude-work/skills/` and nothing on any other machine.

Neither is Claude-specific: `html-doc` is a CSS/markup convention and
`test-system-prompt` drives a proxy and a pair of TypeScript scripts. The
authoring convention is that a skill's real files belong in the
vendor-neutral `.agents/skills/<name>/`, with `.claude/skills/<name>` as
nothing more than the discovery path a particular tool happens to read.

The existing [split stow packages](claude-skills-split-stow-packages.md)
decision puts Claude *user-level* skills in `home/claude/` and symlinks them
from `home/claude-me/`. Applying that here would have buried a tool-agnostic
skill inside a vendor directory and forced any future non-Claude agent to
reach through `.claude/`.

## Decision

A separate `agents` stow package holds the real files, and every Claude
profile package carries a repo-internal relative symlink to it:

- `home/agents/.agents/skills/{html-doc,test-system-prompt}/` — the canonical
  files. Deploys on both OSes (no skip-list entry).
- `home/{claude,claude-me,claude-work}/<cfg>/skills/<name>` — a symlink
  `../../../agents/.agents/skills/<name>`, so each profile Claude Code
  actually reads exposes the same single copy.

All three profiles were wired deliberately: unlike a mission-specific skill,
these two are useful in any session, and the cost of a broken discovery path
is a skill that silently never fires.

`~/.agents/skills/` stays a real directory holding a mix of stow-managed and
unmanaged entries — `microsoft-foundry` is installed by a skill manager and
tracked in `~/.agents/.skill-lock.json`, and `--no-folding` leaves it alone.

## Consequences

- One copy, three profiles, both OSes; edits show up as ordinary `git diff`
  under `home/agents/` because stow links point at the live checkout.
- A new non-Claude agent tool needs only its own discovery symlink; the skill
  itself does not move.
- Watch-out: the profile packages reach their content through a symlink inside
  the stow dir, so renaming or moving `home/agents/` breaks all three links at
  once. `okf validate` will not catch it — the restow log will.
- Watch-out: `dots-adopt` moves the source, so adopting a directory that a
  skill manager owns would desync its lock file. Adopt only hand-authored
  skills.
