# zsh/tmux startup performance (SOC-Kris-Williams, macOS)

Investigation into "why is opening a new tmux pane with zsh slow." Findings
are machine-verified on `SOC-Kris-Williams` (aarch64-darwin); the zsh config
being profiled (`home/zsh/.config/zsh/`) is shared across all hosts/both OSes,
so the structural findings (starship's double-invocation, uncached `eval`s)
apply everywhere — only the specific numbers and the stray `.cache` directory
were local to this machine. Maintained for Claude's use: keep it accurate,
re-measure rather than trust stale numbers, and record new findings in
**Learned behaviours** at the bottom.

## Baseline (before fixes, 2026-07-16)

- `zsh -i -c exit`, warm: **~150-190ms**
- End-to-end tmux `new-session` → pane accepts input, warm server, cwd =
  this repo: **~510-560ms** (measured via a sentinel file written by
  `send-keys`, not `new-session`'s return — `new-session -d` returns as soon
  as the pty is forked, well before rc files finish, so it under-measures).
- First invocation after a cold cache (fresh boot, or right after this
  session's tool calls warmed nothing yet) can spike to **1-6s** — this is
  dyld/`/nix/store` first-touch overhead, not representative of the steady
  state, and not what was fixed here.

## Where the ~510-560ms warm cost goes

Found via `PS4='+%D{%s.%6.} %N:%i> ' zsh -ix` (timestamped xtrace) run both
directly and inside a real tmux pane, cross-checked against standalone
timing of each subprocess and `STARSHIP_LOG=trace starship prompt`.

1. **Starship renders the prompt twice per line, recomputing git state each
   time (~130-150ms).** `starship init zsh` sets `PROMPT` and `RPROMPT` to
   two separate `$(starship prompt ...)` / `$(starship prompt --right ...)`
   command substitutions — two full process spawns per prompt draw. Trace
   breakdown of a single call:
   - `git_status`: ~49ms
   - `git_branch`: ~10ms
   - `git_state`: ~11ms
   - everything else combined: <2ms

   This is upstream starship+zsh architecture, not a misconfiguration — the
   repo's `starship.toml` only disables `aws`/`gcloud`. It recurs on *every*
   prompt draw in a git repo, not just pane startup. Not changed here (would
   mean losing git info from the prompt, a UX tradeoff left to the user).

2. **A stray root-owned `.cache/` was sitting in this repo root**, mode
   `700`, owned by `root:staff`, dated Jul 15 12:44 (likely a `sudo`'d tool
   run from this cwd — `sudo yazi` appears near that point in
   `~/.zsh_history`, though the cwd at that moment isn't recoverable to
   confirm it). It was untracked and un-gitignored, so every `git status` in
   this repo (and thus every starship `git_status` call) tried to read it and
   printed `warning: could not open directory '.cache/': Permission denied`.
   **Fixed:** removed (`sudo rm -rf .cache`) and added `/.cache` to
   `.gitignore` so a recurrence doesn't silently re-eat this cost. Net effect
   on `git status --porcelain=v2 --branch` in this repo was smaller than
   expected (~28ms → ~25ms) — most of that call's cost is inherent tree-walk
   over the repo's other directories, not this one bad entry.

3. **Five external tools get `eval`'d fresh every shell start, uncached
   (~55-90ms).** `brew shellenv` (~29ms), `direnv hook zsh` (~7ms), `zoxide
   init` (~5ms), `fzf --zsh` (~5ms), `starship init zsh` (~9ms — the one-time
   hook setup, not the per-prompt render cost above). None were cached, even
   though `darwin.zsh` already documents and fixes the identical problem for
   `determinate-nixd completion zsh` ("takes ~300ms per shell... cache it and
   refresh only when the binary changes"). **Fixed:** `brew shellenv` now
   uses the same cache-and-refresh-on-mtime-change pattern, writing to
   `$ZDOTDIR/.brew-shellenv.zsh`. Measured saving: warm `zsh -i -c exit`
   dropped from ~150-190ms to a consistent **~120ms**. `direnv`/`zoxide`/`fzf`
   were left uncached — each is small enough (~5-7ms) that the caching
   machinery's own upkeep cost isn't obviously worth it, but the pattern is
   there in `darwin.zsh` if one of them regresses later.

4. **compinit's `compaudit` security scan** stats every completion dir/file
   on `$fpath` every start (~20-40ms real; xtrace-inflated numbers looked much
   higher but that's tracing overhead on zsh's own loop, not real wall time).
   **Not a bug** — confirmed `.zcompdump`'s mtime is unchanged across repeated
   `zsh -i -c exit` runs, so the expensive full dump rebuild only happens when
   the cache is genuinely stale (a nix profile change adding/removing
   completions), as intended. Left alone.

5. Remainder (~150-250ms): process/pty fork overhead, and zsh parsing
   `/etc/zshenv` → `/etc/zshrc` → `.zshrc` → `aliases.zsh`/`yazi.sh`/
   `functions.zsh`/`darwin.zsh`/`integrations.zsh` in sequence. Not
   independently itemized further.

## Net result of fixes applied (2026-07-16)

- `zsh -i -c exit` warm: ~150-190ms → **~120ms**.
- End-to-end tmux pane-ready: ~510-560ms → still **~500-520ms**. The two
  fixes here (brew caching, `.cache` removal) only ever accounted for a
  modest slice of the total — the dominant cost (starship's double
  git-aware render, #1 above) was intentionally left alone. If the ~500ms
  floor needs to come down further, the lever is tuning/disabling starship's
  `git_status`/`git_branch`/`git_state` modules (a prompt-content decision,
  not a bug fix) or switching prompt tools.

## How this was tested

```sh
# Timestamped xtrace of a full interactive shell start (direct):
PS4='+%D{%s.%6.} %N:%i> ' zsh -ix -c exit 2>trace.log
# then diff consecutive %D timestamps per line to find the slowest gaps.

# Same, but inside a real tmux pane (to catch pty-specific effects):
tmux new-session -d -s trc "PS4='+%D{%s.%6.} %N:%i> ' zsh -ix 2>trace.log"

# End-to-end "pane is actually ready for input" timing — new-session -d
# returns before rc finishes, so use a sentinel file via send-keys instead:
tmux new-session -d -s perf -x 200 -y 50
tmux send-keys -t perf "date +%s%N > ready.txt" Enter
# poll for ready.txt, diff against the new-session start time

# Per-subprocess cost of the `eval "$(...)"` calls in integrations.zsh/darwin.zsh:
time ( for i in 1 2 3 4 5; do brew shellenv >/dev/null; done )   # etc.

# Starship's own module-level breakdown:
STARSHIP_LOG=trace starship prompt --terminal-width=200 2>&1 >/dev/null \
  | grep -oE 'Took [0-9.]+(µs|ms|ns) to compute module "[a-z_]+"'
```

Never touched the user's real tmux server — all timing used disposable
`perf<N>`/`trc`/`warmup` sessions on the default socket, killed after each
trial (`tmux kill-session`/`kill-server`), and `tmux ls` was checked first
each time to confirm nothing of the user's was running before any
`kill-server`.

## Learned behaviours & workarounds

- **xtrace timestamps lie about absolute cost, not relative order.** `-x`
  adds overhead proportional to the *number of interpreted lines* a step
  executes, not to real subprocess wall time. `compdump`'s internal loops
  looked wildly expensive under trace (~120ms) but the dump file's mtime
  proved it wasn't even rebuilding — the inflation was tracing overhead on
  zsh's own bytecode loop. Subprocess `fork`/`exec` costs (starship, brew,
  compaudit's `stat()`s) are *not* inflated the same way and can be trusted
  directly against standalone timing. Cross-check any surprising xtrace
  number against a standalone timing of that exact step before believing it.
  (2026-07-16)
- **`tmux new-session -d` returns before the shell is usable.** It only
  blocks until the pty is forked, not until rc files finish. Any latency
  measurement that stops the clock there under-counts by the full rc-load
  time. Use a `send-keys` sentinel file instead. (2026-07-16)
- **`stat -f` means two different things** depending on which `stat` is
  first on `$PATH`: BSD `stat -f '<format>'` vs GNU coreutils' `stat -f`
  (filesystem info, `df`-like) — if `nix`'s coreutils shadows `/usr/bin/stat`,
  a BSD-style format string silently gets ignored and you get `df` output
  instead. Use `/usr/bin/stat` explicitly when you need BSD semantics.
  (2026-07-16)

## Sources

- Repo: `home/zsh/.config/zsh/.zshrc`, `darwin.zsh`, `integrations.zsh`;
  `home/starship/.config/starship.toml`.
- [starship's zsh init script](https://starship.rs) (`starship init zsh`) —
  confirms the `PROMPT`/`RPROMPT` dual-invocation design.
- Machine-verified on `SOC-Kris-Williams`, 2026-07-16: all commands under
  "How this was tested" above, run live against this repo and a disposable
  tmux server.
