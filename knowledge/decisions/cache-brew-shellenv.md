---
type: Decision
title: Cache brew shellenv Output in darwin.zsh
description: 'brew shellenv re-execs and re-emits identical static exports on every zsh start (~30ms); cache its output to a file and refresh only when the brew binary changes, mirroring the existing determinate-nixd completion cache.'
tags: [zsh, performance, darwin]
timestamp: '2026-07-16T18:00:00-07:00'
---

**Status:** active. **Where:**
[home/zsh/.config/zsh/darwin.zsh](../../home/zsh/.config/zsh/darwin.zsh),
[zsh module](../modules/zsh.md),
[shell-startup-performance manual](../../docs/shell-startup-performance.md).

## Context

A profiling pass into "why does a new tmux pane feel slow" (timestamped
`zsh -x` traces, per-subprocess timing, `STARSHIP_LOG=trace`) found that
every interactive zsh start forks five external tools via `eval "$(cmd)"` to
pick up their shell integration, none of them cached: `brew shellenv`
(~29ms), `direnv hook zsh` (~7ms), `zoxide init` (~5ms), `fzf --zsh` (~5ms),
`starship init zsh` (~9ms). `brew shellenv`'s output is deterministic for a
given brew install (a fixed set of `HOMEBREW_*` exports and an `fpath`
prepend) and only changes if Homebrew itself is reinstalled/relocated — it
was the single largest of the five and the easiest to cache safely.
`darwin.zsh` already carried the identical fix for `determinate-nixd
completion zsh` (documented inline as "~300ms per shell to emit the same
static script").

## Decision

Extend the same cache-and-refresh-on-mtime-change pattern from
determinate-nixd to brew: write `brew shellenv`'s output to
`$ZDOTDIR/.brew-shellenv.zsh` once, and only regenerate it when
`/opt/homebrew/bin/brew` is newer than the cache file (`[[ ! -f $cache ||
$bin -nt $cache ]]`). Source the cache file instead of `eval`-ing the live
command.

`direnv`/`zoxide`/`fzf` were left uncached — each costs ~5-7ms, and the
caching machinery (a stat + conditional regen + a second file to keep in
sync with the underlying tool) isn't obviously worth it at that size. The
pattern is already proven twice in this file if one of them regresses later.

## Consequences

Warm `zsh -i -c exit` dropped from ~150-190ms to a consistent ~120ms.
End-to-end tmux pane-ready time barely moved (~510-560ms → ~500-520ms) — the
dominant cost there is starship rendering the prompt twice per line and
recomputing git status each time (~130-150ms, see the manual), which this
change doesn't touch and was deliberately left alone (fixing it trades away
git info in the prompt, a UX call rather than a bug fix). A stray
root-owned `.cache/` directory found during the same investigation (making
every `git status` in this repo print a permission-denied warning) was
removed and gitignored (`/.cache`) as a separate, unrelated cleanup.

## Citations

- [`docs/shell-startup-performance.md`](../../docs/shell-startup-performance.md) — full profiling methodology and numbers.
