---
type: Reference
title: Bash Language
description: 'Bash — the shell scripting substrate for standalone scripts and nix-embedded wrappers, under strict mode + shellcheck everywhere; the interactive shell is zsh, and new tooling prefers bun + TypeScript.'
tags: [bash, shell, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Bash](https://www.gnu.org/software/bash/manual/) is the GNU
Bourne-again shell. Here it is the glue language, deliberately bounded on
two sides: interactive shells are [zsh](modules/zsh.md), and new tooling
defaults to [bun + TypeScript](bun-runtime.md) — bash remains where a shell
is the natural fit.

## How this repo uses it

**Standalone scripts** (`scripts/*.sh`) follow the house style codified in
[`AGENTS.md`](../AGENTS.md): `#!/usr/bin/env bash`, `set -euo pipefail`,
`trap … EXIT` for temp resources, `UPPER_CASE` constants.

**Most shell code is nix-embedded**, which changes the safety story:
`writeShellApplication` wrappers (the [dev](modules/dev.md) shell's `okf`,
nh, cbissue/cbissues, dots-adopt, the config-snapshot CLIs) get
`set -euo pipefail` injected and are **shellcheck-checked at build time**
— lint errors fail the rebuild, not the runtime. The other embedded forms
are darwin activation scripts and the stow restow script shared via
`lib/stow-restow-script.nix` ([dotfiles-stow](modules/dotfiles-stow.md)).

**Editing and lint** ([nvim LSP](nvim/lsp.md)): shellcheck lint + shfmt
format via efm for sh/bash/zsh, with shfmt anchored on `.editorconfig` for
indent rules; bashls's built-in shellcheck is disabled so diagnostics
aren't doubled. Extensionless scripts are filetype-detected by shebang
([filetypes](nvim/filetypes.md)).

## Citations

- [GNU Bash manual](https://www.gnu.org/software/bash/manual/)
- [ShellCheck](https://www.shellcheck.net/) — the static analyzer enforced
  both in-editor and inside `writeShellApplication` builds
