---
type: Decision
title: Proxy Root-Layout Plugins Through a Pointer Marketplace for Claude Desktop
description: 'Claude Desktop''s account-synced marketplace reader rejects marketplaces whose plugin source is the repo root ("./"), which the CLI accepts; rather than fork or patch upstream, the dotfiles repo carries a one-entry marketplace.json that references the upstream repo as a github source, so Desktop syncs the plugin from upstream unchanged.'
resource: .claude-plugin/marketplace.json
tags: [claude, macos, plugins]
generated: { by: okflight/0.4.0, at: 2026-09-28T00:00:00-07:00 }
---

**Where:** `.claude-plugin/marketplace.json` + `.claude-plugin/README.md` at the
repo root. Related: [Claude Profile Isolation Strategy](claude-profile-isolation.md)
(the desktop app is pinned to `~/.claude-me`, which turned out to be irrelevant
here).

## Context

`typesafe-ai/skills` installs fine in the Claude Code CLI
(`claude plugin marketplace add typesafe-ai/skills` → `claude plugin install
typesafe@typesafe-ai`, landing in `~/.claude-me/plugins/` on the macs), but the
Claude **desktop app**'s Settings → Customize → Plugins pane never showed it.
Two separate stores are at play:

- **Desktop Code tab + terminal CLI** — local, under `CLAUDE_CONFIG_DIR`
  (`~/.claude-me` via the account selector). The CLI install covers these.
- **Desktop Chat/Cowork** — marketplaces synced server-side through the
  claude.ai account ([support article](https://support.claude.com/en/articles/13837440-use-plugins-in-claude):
  "not from the CLI's ~/.claude directory"). Only the Add-marketplace dialog
  feeds it.

Adding `typesafe-ai/skills` in that dialog fails with the opaque "Failed to
add marketplace." Bisected 2026-09-28 by adding other marketplaces in the same
dialog:

| Marketplace | plugin `source` | Result |
|---|---|---|
| `typesafe-ai/skills` | `"./"` (repo root; `plugin.json` beside `marketplace.json`) | fails |
| `anthropics/skills` | `"./"` (+ `strict: false`, explicit `skills[]`) | fails |
| `anthropics/claude-plugins-official` | `./plugins/<name>` / `git-subdir` objects | syncs |

The repo's layout is valid for the CLI (cloned and checked: `marketplace.json`,
`plugin.json`, one `skills/typesafe-ai/SKILL.md` with proper frontmatter), and
the desktop app's GitHub connection works (the official marketplace synced). The
common factor in the failures is the root-level `"./"` plugin source, which
the claude.ai reader does not support.

## Decision

Make the dotfiles repo itself a **pointer marketplace**: one `marketplace.json`
whose plugin entry is `{ "source": "github", "repo": "typesafe-ai/skills" }`.
The plugin root the reader sees is then the upstream repo root — the same shape
as the official marketplace's `git-subdir` entries — sidestepping the `"./"`
case. Nothing is vendored or patched, and every desktop sync re-fetches
upstream, so the plugin tracks upstream releases without manual re-syncing (a
fork would not). The desktop app adds `kriswill/dotfiles` as the marketplace.

Rejected: forking/restructuring upstream (maintenance burden, explicitly not
wanted); a separate `kriswill/claude-marketplace` repo (cleaner, but one more
repo for a 20-line file — revisit if the entry list grows); uploading the lone
SKILL.md as a custom skill under Customize → Skills (works, zero repo, but
frozen at the uploaded version and not a plugin).

## Consequences

- The file is inert for everything else: import-tree walks `modules/`, stow
  walks `home/`, and the CLI only sees it if explicitly added as a marketplace.
- Whether the claude.ai reader accepts `github`-object sources is inferred
  from the official marketplace (which uses `git-subdir` objects), not
  verified — if this sync also fails, the custom-skill upload is the fallback.
- Worth an upstream issue on `typesafe-ai/skills` (move the plugin to
  `plugins/typesafe/`); once fixed there, the pointer entry can be dropped.
