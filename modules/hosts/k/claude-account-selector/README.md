# claude-account-selector

A zsh wrapper that auto-selects which Claude Code **account/profile** to use based on the
directory you launch from — so a personal Claude Max account and a corporate Enterprise
account can coexist on one machine, even in two terminals at the same time.

It defines a `claude` shell function that shadows the real `claude` binary, picks a profile,
sets `CLAUDE_CONFIG_DIR` (isolated config/history/MCP/plugins per profile), and prefers that
profile's own interactive login — falling back to its Keychain token (`CLAUDE_CODE_OAUTH_TOKEN`)
only when the profile isn't signed in — then execs the real CLI. A matching `ccglass` function
does the same for the [ccglass](https://github.com/jianshuo/ccglass) traffic inspector (see
[Inspecting traffic with ccglass](#inspecting-traffic-with-ccglass)).

## Why

Older Claude Code stored the OAuth login in a single shared macOS Keychain item, so two
profiles fought over one login even with separate `CLAUDE_CONFIG_DIR`s — a per-profile
Keychain token was the only way to get true simultaneous use. **Claude Code now isolates the
login per `CLAUDE_CONFIG_DIR`** (verified on 2.1.165): each profile dir keeps its own
interactive login, and both accounts can be signed in at once with no token at all.

So the wrapper **prefers each profile's interactive login** and keeps the Keychain token only
as a *fallback* — for a profile with no interactive login yet (fresh dir, expired session, or
an Enterprise account where interactive login isn't available). It detects the login with
`claude auth status --json` (the token blanked for the probe) and injects the token only when
that reports the profile is *not* signed in via `claude.ai`.

## Profiles

| Profile | Config dir        | Keychain token item   |
|---------|-------------------|-----------------------|
| `me`    | `~/.claude-me`    | `claude-token-me`     |
| `work`  | `~/.claude-work`  | `claude-token-work`   |

## Usage

```sh
claude                       # launch; profile chosen by longest-prefix match of $PWD
claude work [args…]          # force the work profile for this run only
claude me   [args…]          # force the me profile for this run only

claude pin work [path]       # remember: path-prefix → work   (default path: cwd)
claude pin me   [path]       # remember: path-prefix → me
claude unpin [path]          # forget a pinned prefix          (default path: cwd)
claude which [path]          # show which profile a path resolves to, and its config dir
claude pins                  # list all rules (built-in + pinned)

command claude …             # bypass the wrapper entirely (use the raw binary)
```

Any non-keyword first argument (e.g. `--dangerously-skip-permissions`, `mcp`, `-p`) is
passed straight through to the real CLI, so existing aliases like `cyolo` still work.

### Reserved first words

`me`, `work`, `pin`, `unpin`, `which`, and `pins` are interpreted by the wrapper only when
they appear as the **first** argument. A leading `me`/`work` is consumed as a profile
selector — so `claude work on the bug` launches the real CLI with `on the bug` under the
*work* profile, **not** the prompt `work on the bug`. To pass such text verbatim, give it as
a flag value (`claude -p "work on the bug"`) or bypass the wrapper (`command claude …`).

### Subcommands are profile-scoped

Stateful subcommands (`claude mcp …`, `claude config …`, `claude update`, `claude doctor`, …)
run against the **resolved profile's** config dir, so their effect is cwd-dependent:
`claude mcp add` under `~/src/perforce/...` edits `~/.claude-work`; the same command elsewhere
edits `~/.claude-me`. This is intentional (profiles are isolated), but it means servers/config
in your original `~/.claude` aren't visible under a profile unless you seeded that profile
from it (see setup). Use `command claude …` to operate on the original `~/.claude`.

## Desktop app (GUI)

The wrapper only covers the **terminal** `claude` binary. The Claude **desktop app** (and
the Claude Code it embeds) is launched from Dock/Spotlight/Finder, which inherits the macOS
launchd *Aqua* session environment — **not** your shell env. So the per-`$PWD` wrapper never
runs for it, and it falls back to the unsegregated `~/.claude`. Neither
`environment.variables` (shell-only) nor `launchd.daemons` (system/root domain) reaches it.

Set `desktopProfile` to pin it. The module then installs a per-user **LaunchAgent** that runs
`launchctl setenv CLAUDE_CONFIG_DIR ~/.claude-<desktopProfile>` at login, in the Aqua domain
the desktop app inherits:

```nix
# settings in the let block of ./default.nix
defaultProfile = "me";
profiles = [ "me" "work" ];
desktopProfile = "me";   # GUI desktop app → ~/.claude-me
```

### The terminal-leak scrub

A session-wide `launchctl setenv` also leaks into every **GUI-launched terminal** (Ghostty,
and any tmux server it spawns). Those shells would then start with `CLAUDE_CONFIG_DIR` already
set, and the wrapper treats any non-empty value as an explicit override — silently disabling
per-`$PWD` switching for *all* terminal `claude`.

To prevent that, when `desktopProfile` is set the module prepends a one-line scrub to the zsh
init: an interactive shell that merely **inherited** this exact value drops it, so the wrapper
resolves by `$PWD` as usual. An explicit `CLAUDE_CONFIG_DIR=… claude` (set *after* init, per
command) is unaffected and still wins.

### Activation & verification

```sh
nrs                                                  # nh darwin switch ~/src/dotfiles
launchctl setenv CLAUDE_CONFIG_DIR ~/.claude-me      # apply now (or just log out/in)
launchctl getenv  CLAUDE_CONFIG_DIR                  # → /Users/<you>/.claude-me
# Cmd-Q and relaunch the Claude desktop app so its next session inherits the env.
# In a fresh Ghostty window, `echo $CLAUDE_CONFIG_DIR` should be EMPTY (scrub working).
```

**Trade-off:** the desktop app gets a single fixed profile — there is no `$PWD` at GUI launch,
so it cannot do the per-directory me/work routing the terminal wrapper does. Pin it to the
account the desktop app is mostly for. Leave `desktopProfile` unset to keep the app on the
default `~/.claude`.

## Inspecting traffic with ccglass

[ccglass](https://github.com/jianshuo/ccglass) is a local logging reverse-proxy that shows
exactly what Claude Code sends to the model. It starts a proxy, points the client at it via
`ANTHROPIC_BASE_URL`, captures every request/response, and forwards to the real upstream.

The catch: ccglass spawns the **real `claude` binary directly** (Node `child_process`, no
shell), so the `claude` function above never runs for it — the child would launch in the
default `~/.claude` scope, ignoring your per-directory profile. To fix this the module also
defines a `ccglass` function that resolves the profile (same rules as `claude`) and exports
`CLAUDE_CONFIG_DIR` (plus the keychain token as a fallback — same prefer-interactive-login
logic as `claude`); ccglass passes its environment straight through to the child, so `claude`
lands in the right account *and* its traffic flows through the proxy.

```sh
ccglass claude              # inspect; profile chosen by $PWD, then watch the dashboard URL
ccglass kimi                # any claude-based ccglass provider works the same way
command ccglass …           # bypass the function (raw binary, default ~/.claude scope)
```

An explicit `CLAUDE_CONFIG_DIR` in the environment is respected and passed through untouched,
exactly like the `claude` wrapper. Notes:

- Auth headers pass through the proxy verbatim, so the OAuth credentials reach Anthropic
  unchanged; ccglass masks `authorization`/`x-api-key` in saved logs by default
  (`--no-redact` to keep them).
- `ccglass` uses the same prefer-interactive-login-then-token logic as `claude`. If a Claude
  Code version ever treats the proxy's `ANTHROPIC_BASE_URL` as a bring-your-own-key provider
  under interactive login, force the token instead with an explicit
  `CLAUDE_CODE_OAUTH_TOKEN=… ccglass …` (an exported token passes straight through), or
  re-scope the helper's prefer-login probe to `claude` only.

## How a profile is chosen

Resolution order:

1. Explicit `me` / `work` as the first argument — wins, for that run only.
2. **Longest-prefix match** of the current path against the rule table.
3. Fallback: `me`.

The rule table is the union of:

- **Module rules:** the `rules` setting in `./default.nix` — declarative
  and version-controlled. See [Configuration](#configuration).
- **Your pins:** `$XDG_STATE_HOME/claude/profile-map.tsv` (defaults to
  `~/.local/state/claude/profile-map.tsv`).

Longest matching prefix wins, so a more-specific pin overrides a broader rule — e.g. with
a rule `~/src/work → work`, a pin of `~/src/work/oss → me` makes just that subtree use `me`.
The TSV is plain `path<TAB>profile`, one rule per line; edit it by hand or via
`claude pin` / `claude unpin`.

```text
/Users/k/src/clientX     work
/Users/k/src/work/oss    me
```

## Configuration

All inputs are plain `let`-bindings at the top of `./default.nix` (they were
`kriswill.claude-account-selector.*` nix options until the module became host-k-only and was
mounted directly into `configurations.darwin.k.module`). The module passes them to the wrapper
as shell variable assignments prepended to it — `wrapper.zsh` stays a plain zsh file with
built-in fallbacks, so it also runs standalone (e.g. under test).

| Setting | Type | Purpose |
|---|---|---|
| `defaultProfile` | str | Profile used when no rule matches. |
| `profiles` | list of str | Accepted profile names → `~/.claude-<name>` and keychain `claude-token-<name>`. |
| `rules` | attrs (path → profile) | Built-in path-prefix rules; longest match wins. `{ }` for none. |
| `desktopProfile` | str | Pin the GUI Claude **desktop app** to `~/.claude-<name>` via a login LaunchAgent. See [Desktop app (GUI)](#desktop-app-gui). |

```nix
# in the let block of ./default.nix
defaultProfile = "me";
profiles = [ "me" "work" "oss" ];
rules = {
  "/Users/k/src/work" = "work";
  "/Users/k/clients"  = "work";
  "/Users/k/oss"      = "oss";
};
```

Rule prefixes are matched against the realpath of the launch directory, so use literal
absolute paths. Runtime `claude pin` entries are merged on top and, being more specific,
win by longest-prefix.

## One-time setup

The module only installs the wrapper. Create the profiles and stash a token for each once:

```sh
# 1. Seed the work profile from your current config (keeps plugins/MCP/history).
cp -a ~/.claude       ~/.claude-work
cp -a ~/.claude.json  ~/.claude-work/.claude.json   # account/state lives inside the config dir

# 2. Repair absolute ~/.claude/ paths baked into the copy so they point at the
#    NEW config dir (see "Repairing copied config-dir references" below). The
#    `cp -a` above carries verbatim e.g. a SessionStart hook command like
#    "/Users/you/.claude/hooks/...", which would otherwise 404 every session.
sel=~/src/dotfiles/modules/hosts/k/claude-account-selector
"$sel/fix-config-dir-refs.zsh"          ~/.claude-work   # dry-run: preview changes
"$sel/fix-config-dir-refs.zsh" --apply  ~/.claude-work   # write (backs up each file)

# 3. Sign in to each profile interactively — this is the primary login now that Claude Code
#    isolates it per config dir (each /login sticks to its own dir, no token needed):
CLAUDE_CONFIG_DIR=~/.claude-work claude   # /login as the work account
CLAUDE_CONFIG_DIR=~/.claude-me   claude   # /login as the me account

# 4. (Optional) Mint + stash a long-lived Keychain token per account as the *fallback* used
#    when a profile isn't interactively signed in (expired session, Enterprise, fresh dir):
CLAUDE_CONFIG_DIR=~/.claude-work claude setup-token
security add-generic-password -U -s claude-token-work -a "$USER" -w '<paste-token>'
CLAUDE_CONFIG_DIR=~/.claude-me   claude setup-token
security add-generic-password -U -s claude-token-me   -a "$USER" -w '<paste-token>'
```

The wrapper prefers each profile's interactive login; the Keychain token is only the fallback
for a profile that isn't signed in. If a profile has neither, `claude` simply prompts you to
log in — and that login then sticks, scoped to its own config dir.

## Repairing copied config-dir references

`fix-config-dir-refs.zsh` (in this directory) rewrites stale `~/.claude/` paths inside a
profile config dir so they point at that profile's own dir. You need it because `cp -a`
copies config files **verbatim**: an absolute path baked into the source — e.g. a
`SessionStart` hook registered in `settings.json` as
`"/Users/you/.claude/hooks/context-mode-cache-heal.mjs"` — still points at the original
`~/.claude` after the copy. Under a profile that file may not exist, so Claude Code logs a
`SessionStart:startup hook error … No such file or directory` every launch. Worse, the
plugins that write such hooks only re-register when *no* matching hook is present, so they
never self-correct the stale base path — it persists until you fix it.

```sh
# Preview (default) — no writes. Target defaults to $CLAUDE_CONFIG_DIR if omitted.
./fix-config-dir-refs.zsh ~/.claude-work

# Apply — backs up each changed file to <file>.bak-<timestamp> first.
./fix-config-dir-refs.zsh --apply ~/.claude-work

# Options:
#   --from DIR     original dir whose refs to rewrite   (default: ~/.claude)
#   --no-backup    skip the .bak-<ts> copy when applying
#   -h, --help
```

Behaviour and safety:

- **Scope:** only `settings.json` and `settings.local.json` are scanned — the files holding
  hook/`statusLine` command paths. Both absolute (`/Users/you/.claude/…`) and `~`-form
  (`~/.claude/…`) references are rewritten.
- **`.claude.json` is intentionally skipped.** Its `projects` map is keyed by real working
  directories, one of which may legitimately live under `~/.claude` (e.g. a session launched
  from `~/.claude/hooks`); a blanket rewrite would corrupt that state. Fix any genuine path
  there by hand.
- Matches are **anchored on a trailing `/`**, so a sibling profile dir (`~/.claude-work/`,
  `~/.claude-me/`) is never caught by a rewrite targeting `~/.claude/`.
- Each rewrite is **JSON-validated**; if it would produce invalid JSON the file is left
  unchanged. The script is **idempotent** — re-running finds nothing to change.

Run it any time you re-seed a profile from `~/.claude`, not just at first setup.

## Enable / disable

The module is **mounted only into host k** (`configurations.darwin.k.module` in
`./default.nix`) and is active wherever it's mounted — there is no enable flag. Complete the
one-time setup above *before* mounting it on a new host, since a `darwin-rebuild switch` with
the module mounted redirects `claude` immediately. To disable, remove (or stop mounting) the
directory; to adopt it on another host, add a
`configurations.darwin.<host>.module = …` line alongside k's.

## Notes & caveats

- `claude setup-token` may be blocked by Enterprise org policy. That only costs the work
  profile its *fallback* token — with per-dir interactive logins, simultaneous use still works;
  config/history isolation always holds.
- Each non-auth launch runs a quick `claude auth status` probe (~0.2s, offline) to decide
  whether to prefer the interactive login, adding a small startup cost.
- An explicit `CLAUDE_CONFIG_DIR` in the environment is respected and bypasses profile
  resolution entirely (this is what makes the one-time-setup commands above target the dir
  you name rather than the `$PWD`-resolved profile).
- When the fallback token is injected, it's visible in the process environment to your own
  session (as with any env-based token). Fine for a single-user laptop.
- zsh gotcha (already handled in `wrapper.zsh`): never declare a `local path` — `path` is the
  special array bound to `$PATH`; shadowing it empties `$PATH` inside the function.
