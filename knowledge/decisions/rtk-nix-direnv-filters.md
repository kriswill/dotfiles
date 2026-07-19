---
type: Decision
title: rtk Custom Filters for nix/direnv Wrapper Noise
description: Added user-global rtk TOML filters for nix run/shell/develop/build/flake-check and direnv exec, discovered via rtk discover usage data; requires filter_stderr since both tools log to stderr, and only fires when the rtk prefix is typed explicitly.
resource: AGENTS.md
tags: [rtk, nix, direnv, token-optimization]
timestamp: '2026-07-19T00:00:00-07:00'
---

**Status:** active. **Where:** [rtk](../packages/rtk.md) /
[rtk module](../modules/rtk.md) / [stow tree](../patterns/stow-tree.md) /
`AGENTS.md`.

## Context

`rtk discover -a -s 90` (a scan of 327 Claude Code sessions / 8762 Bash
commands) showed `nix run`, `nix shell`, `nix develop -c`, `nix build`,
`nix flake check -L`, and `direnv exec .` as frequent wrapper commands rtk
has no built-in filter for — none of them are in rtk's ~90 native Rust
subcommands, so they always pass through unfiltered. `nix eval` was the
single largest miss (93 hits) but was left alone: rtk's TOML filter DSL
strips noise *lines*, it doesn't reformat structured output, and `rtk json`
(rtk's JSON compactor) only accepts a file argument, not stdin — no clean
fit.

## Decision

Added two filters to `~/.config/rtk/filters.toml` (user-global; `rtk config
--create` first generated it locally, then `dots-adopt rtk
.config/rtk/{config,filters}.toml` captured both files — alongside rtk's
main `config.toml` — into a new `home/rtk` [stow package](../patterns/stow-tree.md),
so it's git-tracked and deploys to every host like any other dotfile):

```toml
[filters.nix]
match_command = "^nix\\s+(run|shell|develop|build|flake\\s+check)\\b"
filter_stderr = true
strip_ansi = true
strip_lines_matching = [
  "^\\s*$", "^this path will be fetched", "^these \\d+ paths will be fetched",
  "^\\s+/nix/store/", "^copying path '.*' from '.*'\\.\\.\\.",
  "^warning: Git tree '.*' is dirty",
]

[filters.direnv]
match_command = "^direnv\\s+exec\\b"
filter_stderr = true
strip_ansi = true
strip_lines_matching = ["^direnv: loading ", "^direnv: using ", "^direnv: nix-direnv: "]
```

`AGENTS.md` now tells agents to prefix these six command forms with `rtk`.

Two gotchas surfaced during verification (`RTK_TOML_DEBUG=1`, real
not-yet-cached-package runs):

- **`filter_stderr = true` is required.** Both nix's fetch/copy progress
  lines and direnv's `loading`/`using` lines go to stderr. Without the flag,
  `RTK_TOML_DEBUG=1` reports `matched filter: 'nix'` — the match succeeds —
  but the filter pipeline never touches stderr, so the raw noise prints
  anyway. A matched-but-unfiltered result is silent; only the debug env var
  surfaces it.
- **No auto-rewrite.** rtk's Claude Code hook (`rtk rewrite`) only rewrites
  commands rtk natively recognizes; custom TOML filters are never consulted
  by it (confirmed empirically — `rtk rewrite "nix flake check -L"` exits 1
  even with a matching, trusted filter present). The `rtk` prefix must be
  typed by hand, which is why `AGENTS.md` spells out the six forms instead
  of relying on the hook.

Also confirmed, not used here: a custom TOML filter can never override a
command name rtk already implements natively in Rust (e.g. `wc`) —
`RTK_TOML_DEBUG=1` reports a shadow warning and the Rust module always wins.
Irrelevant for `nix`/`direnv` since neither is a native rtk subcommand.

## Consequences

- `rtk nix run …` / `rtk nix shell …` / `rtk nix develop -c …` /
  `rtk nix build …` / `rtk nix flake check …` / `rtk direnv exec . …` now
  strip store-fetch and direnv-loading boilerplate while leaving the wrapped
  tool's real output untouched.
- Being in the `home/rtk` stow package, the filters (and `config.toml`)
  propagate to every host on the next `dotfiles-stow` restow — no per-host
  re-application needed.
- `nix eval` remains unfiltered; revisit only if a stdin-capable compaction
  path appears (e.g. a future `rtk json -` or a `truncate_lines_at`-based
  filter proves acceptable for JSON).

## Citations

- [rtk-ai/rtk — custom filters guide](https://github.com/rtk-ai/rtk/blob/master/docs/guide/getting-started/configuration.md)
- [rtk-ai/rtk — TOML filter DSL reference](https://github.com/rtk-ai/rtk/blob/master/src/filters/README.md)
