# claude-account-selector

A zsh wrapper that auto-selects which Claude Code **account/profile** to use based on the
directory you launch from — so a personal Claude Max account and a corporate Enterprise
account can coexist on one machine, even in two terminals at the same time.

It defines a `claude` shell function that shadows the real `claude` binary, picks a profile,
sets `CLAUDE_CONFIG_DIR` (isolated config/history/MCP/plugins per profile) and, if available,
`CLAUDE_CODE_OAUTH_TOKEN` (isolated login), then execs the real CLI.

## Why

Claude Code isolates everything *except* the login when you change `CLAUDE_CONFIG_DIR`.
On macOS the OAuth credential lives in a single shared Keychain item, so without a
per-profile token the two accounts fight over one login. This module pairs each profile
config dir with its own Keychain-stored token to give true simultaneous use.

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

## How a profile is chosen

Resolution order:

1. Explicit `me` / `work` as the first argument — wins, for that run only.
2. **Longest-prefix match** of the current path against the rule table.
3. Fallback: `me`.

The rule table is the union of:

- **Module rules:** the `rules` nix option (default: `~/src/perforce → work`) — declarative
  and version-controlled. See [Configuration](#configuration-nix-options).
- **Your pins:** `$XDG_STATE_HOME/claude/profile-map.tsv` (defaults to
  `~/.local/state/claude/profile-map.tsv`).

Longest matching prefix wins, so a more-specific pin overrides a broader rule — e.g. with
the built-in `~/src/perforce → work`, a pin of `~/src/perforce/cto/oss → me` makes just that
subtree use `me`. The TSV is plain `path<TAB>profile`, one rule per line; edit it by hand or
via `claude pin` / `claude unpin`.

```text
/Users/k/src/clientX            work
/Users/k/src/perforce/cto/oss   me
```

## Configuration (nix options)

All inputs are nix options under `kriswill.claude-account-selector`. The module passes them
to the wrapper as shell variable assignments prepended to it — `wrapper.zsh` stays a plain
zsh file with built-in fallbacks, so it also runs standalone (e.g. under test).

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | `false` | Install the `claude` wrapper (see [Enable / disable](#enable--disable)). |
| `defaultProfile` | str | `"me"` | Profile used when no rule matches. |
| `profiles` | list of str | `[ "me" "work" ]` | Accepted profile names → `~/.claude-<name>` and keychain `claude-token-<name>`. |
| `rules` | attrs (path → profile) | `{ "<home>/src/perforce" = "work"; }` | Built-in path-prefix rules; longest match wins. `{ }` for none. |

```nix
home-manager.users.<user>.kriswill.claude-account-selector = {
  enable = true;
  defaultProfile = "me";
  profiles = [ "me" "work" "oss" ];
  rules = {
    "${config.home.homeDirectory}/src/perforce" = "work";
    "${config.home.homeDirectory}/clients"      = "work";
    "${config.home.homeDirectory}/oss"          = "oss";
  };
};
```

Rule prefixes are matched against the realpath of the launch directory, so use absolute
paths (the default uses `config.home.homeDirectory`). Runtime `claude pin` entries are merged
on top of these and, being more specific, win by longest-prefix.

## One-time setup

The module only installs the wrapper. Create the profiles and stash a token for each once:

```sh
# 1. Seed the work profile from your current config (keeps plugins/MCP/history).
cp -a ~/.claude       ~/.claude-work
cp -a ~/.claude.json  ~/.claude-work/.claude.json   # account/state lives inside the config dir

# 2. Mint + stash a long-lived token per account (order matters: do whichever account
#    is currently logged in first, since /login rewrites the shared macOS Keychain item).
CLAUDE_CONFIG_DIR=~/.claude-work claude setup-token
security add-generic-password -U -s claude-token-work -a "$USER" -w '<paste-token>'

CLAUDE_CONFIG_DIR=~/.claude-me claude               # /login as the other account
CLAUDE_CONFIG_DIR=~/.claude-me claude setup-token
security add-generic-password -U -s claude-token-me   -a "$USER" -w '<paste-token>'
```

If a token isn't present for a profile, the wrapper still works — it just falls back to the
shared interactive Keychain login (you lose only the simultaneous-use property for that
profile).

## Enable / disable

**Opt-in — disabled by default**, so a `darwin-rebuild switch` never silently redirects your
existing `claude`. Complete the one-time setup above *first*, then enable it in your host
module (e.g. `modules/hosts/<host>.nix`):

```nix
home-manager.users.<user>.kriswill.claude-account-selector.enable = true;
```

## Notes & caveats

- `claude setup-token` may be blocked by Enterprise org policy. If the work token can't be
  minted, only the work profile loses simultaneous use; config/history isolation still holds.
- An explicit `CLAUDE_CONFIG_DIR` in the environment is respected and bypasses profile
  resolution entirely (this is what makes the one-time-setup commands above target the dir
  you name rather than the `$PWD`-resolved profile).
- The injected token is visible in the process environment to your own session (as with any
  env-based token). Fine for a single-user laptop.
- zsh gotcha (already handled in `wrapper.zsh`): never declare a `local path` — `path` is the
  special array bound to `$PATH`; shadowing it empties `$PATH` inside the function.
