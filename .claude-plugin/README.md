# Claude plugin marketplace (`kriswill`)

`marketplace.json` makes this repo a Claude plugin marketplace with two kinds
of entries:

- **In-repo plugins** live under `plugins/<name>/` and are listed with a
  relative `source` (`./plugins/<name>`).
- **Pointer entries** reference an upstream repo as a `github` source, so a
  sync fetches that plugin from upstream unchanged. No upstream code is
  vendored.

## In-repo plugins

- `tsc-lsp`: runs the TypeScript 7 native language server
  (`/run/current-system/sw/bin/tsc --lsp --stdio`) for `.ts`, `.tsx`, `.js`,
  `.jsx`, `.mts`, `.cts`, `.mjs` and `.cjs` files. The absolute path pins it to
  the system `typescript` package from `modules/{darwin,nixos}/neovim.nix`,
  because a project's `node_modules/.bin/tsc` on PATH may be TypeScript 5.x,
  which has no `--lsp`. Disable other TypeScript LSP plugins (`vtsls`,
  `typescript-lsp`) while it is enabled.

The CLI reads the local checkout directly:

```sh
claude plugin marketplace add ~/src/dotfiles
claude plugin install tsc-lsp@kriswill
```

## Pointer entries for Claude Desktop

Pointer entries exist because the Claude **desktop app** (Chat/Cowork →
Settings → Customize → Plugins) syncs marketplaces through the claude.ai
account with a stricter reader than the Claude Code CLI: a marketplace whose
plugin `source` is the repo root (`"./"`, i.e. `plugin.json` beside
`marketplace.json`) fails with "Failed to add marketplace" (verified 2026-09-28
with both `typesafe-ai/skills` and `anthropics/skills`;
`anthropics/claude-plugins-official`, whose plugins live in subdirectories,
syncs fine). The CLI accepts the root layout, so
`claude plugin marketplace add typesafe-ai/skills` works in the terminal and
the desktop app's Code tab, but that store is local and never reaches
Chat/Cowork.

Adding the marketplace in the desktop app: **Add → Add marketplace →
`kriswill/dotfiles` → Sync**, then install `typesafe` from the "Yours" tab.

To proxy another root-layout plugin, append a `plugins[]` entry with
`"source": { "source": "github", "repo": "<owner>/<repo>" }`; nothing else in
this repo depends on the file (import-tree walks `modules/` only, stow walks
`home/`). See `knowledge/decisions/claude-desktop-pointer-marketplace.md`.
