# Pointer marketplace for Claude Desktop

`marketplace.json` makes this repo a Claude plugin marketplace with **no plugin
code of its own**: every entry references an upstream repo as a `github`
source, so a sync fetches the plugin from upstream unchanged.

It exists because the Claude **desktop app** (Chat/Cowork → Settings →
Customize → Plugins) syncs marketplaces through the claude.ai account with a
stricter reader than the Claude Code CLI: a marketplace whose plugin `source`
is the repo root (`"./"`, i.e. `plugin.json` beside `marketplace.json`) fails
with "Failed to add marketplace" (verified 2026-09-28 with both
`typesafe-ai/skills` and `anthropics/skills`; `anthropics/claude-plugins-official`,
whose plugins live in subdirectories, syncs fine). The CLI accepts the root
layout, so `claude plugin marketplace add typesafe-ai/skills` works in the
terminal and the desktop app's Code tab, but that store is local and never
reaches Chat/Cowork.

Adding the marketplace in the desktop app: **Add → Add marketplace →
`kriswill/dotfiles` → Sync**, then install `typesafe` from the "Yours" tab.

To proxy another root-layout plugin, append a `plugins[]` entry with
`"source": { "source": "github", "repo": "<owner>/<repo>" }`; nothing else in
this repo depends on the file (import-tree walks `modules/` only, stow walks
`home/`). See `knowledge/decisions/claude-desktop-pointer-marketplace.md`.
