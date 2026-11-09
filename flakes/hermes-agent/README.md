# hermes-agent

Packages Nous Research's [Hermes Agent](https://github.com/NousResearch/hermes-agent)
(the `hermes` CLI and its messaging/cron gateway) and provides a NixOS module
and a nix-darwin module (`services.hermes-agent`) that run the gateway as the
same account that uses the CLI. On macOS every Hermes process runs inside a
Seatbelt sandbox.

Upstream ships its own flake, but it doesn't fit this repo. Its NixOS module
assumes a `hermes` system user that interactive users share through a group,
and Hermes refuses that: one uid must own `HERMES_HOME`. Its
`addToSystemPackages` exports `HERMES_HOME` only through
`environment.variables`, which shells inside a running session never read.
The flake also pulls in home-manager, a dev shell, Electron and a checks suite
that this repo doesn't use. So this flake copies the parts of upstream's `nix/`
that build the package and run the service, fixes them, and builds them
against upstream's source at a pinned release tag.

## Layout

| File | Purpose |
| --- | --- |
| [`flake.nix`](flake.nix) | flake-parts flake for `x86_64-linux`, `aarch64-linux` and `aarch64-darwin` (upstream's systems). The `hermes-agent-src` input is upstream's source at a release tag (`flake = false`). The other inputs are locked to that tag's own `flake.lock`. |
| [`nix/`](nix) | The copied files, under upstream's names and layout. `nix fmt` formats them like the rest of the repo, so compare against upstream run through nixfmt: `nixfmt < <upstream>/nix/<file> \| diff - nix/<file>` shows only our changes. Each changed file says what changed in a comment marked `Ours:`. |

Three files are ours alone: `nix/hermesCli.nix` (the wrapped CLI and the
Herdr integration, shared by both modules), `nix/darwinModules.nix` and
`nix/darwinSandbox.nix`.

Upstream's `checks.nix`, `desktop.nix`, `devShell.nix`,
`homeManagerModules.nix`, `overlays.nix`, `sandbox.nix` and `tests/` are not
copied. `node-gyp-11-4-0-package-lock.json` is data, so it is read from the
source input and not copied.

### How the copies reach the source

Upstream's files reach their source tree through `./..`. Here the tree is the
`hermes-agent-src` input, and `nix/packages.nix` turns it into `hermesSrc`, a
path value at its root, which a `lib.makeScope` hands to every `callPackage`.
`../pm/lock.json` upstream is `hermesSrc + "/pm/lock.json"` here. It has to be
a path: `lib.fileset` rejects strings, and copying a path into the store is
what gives each filtered source the same store path that upstream gets.

The original v0.22.5 import was derivation-identical to upstream with `version`
reset to `0.0.0`. Local runtime repairs now intentionally break that parity:
PM dependency receipts and writable bundled-skill copies are packaging fixes.
On a bump, compare the upstream files and port or retire each `Ours:` change;
these commands still show the derivations for comparison:

```sh
nix eval --raw --apply 'p: (p.override { version = "0.0.0"; }).drvPath' \
  ./flakes/hermes-agent#packages.x86_64-linux.hermes-agent
nix eval --raw github:NousResearch/hermes-agent/v0.23.0#packages.x86_64-linux.default.drvPath
```

## Flake outputs

- `packages.<system>.hermes-agent` (and `default`): upstream's `full` package,
  with all the portable optional integrations, plus `matrix` on Linux.
  Changes against upstream:
  - `version` is the release tag. Upstream leaves it at `0.0.0`, and
    `hermes --version` printed `v0.0.0`.
  - The desktop app, the dev-shell passthru and the npm-lockfile tooling are
    gone.
  - The TUI, web and webapp bundles still build, as passthru.
  - `nix/tui-terminal-breadcrumbs.patch` attaches the TypeScript helper in
    `nix/tui-breadcrumbs/` to the TUI's committed session state. Unlike v0.22.5's
    TUI, it maintains the classic CLI's terminal breadcrumbs, so Herdr hooks
    can route working/idle status after create, resume, reset and compaction.
    Superseded attachment responses never write. Writes are atomic and private,
    respect local `session.terminal_continue`, and skip explicit remote gateway
    launches. The helper's regression tests run in the Nix TUI build.
  - PM's pinned ffmpeg/ripgrep and existing node/npm are registered in an
    immutable, digest-bound tool store. The install stamp's `runtimeDir`
    points PM at it, so a fresh profile recognizes the dependencies rather
    than reporting PATH-only executables as missing. The package ships
    ffmpeg 9.0.1 (the PM pin), not nixpkgs' former 8.1.2.
  - `nix/writable-skill-copies.patch` makes bundled and optional skill copies
    owner-writable after copying from the immutable store. It preserves
    executable bits and symlinks without modifying their targets; custom
    skills remain protected by upstream's content-hash checks.
- `nixosModules.default`: the NixOS module. It keeps upstream's output name.
- `darwinModules.default`: the nix-darwin module (ours; upstream covers
  macOS only through Home Manager).

## The NixOS module

```nix
services.hermes-agent = {
  enable = true;
  user = "alice";                   # runs the gateway, owns HERMES_HOME, uses the CLI
  addToSystemPackages = true;       # the wrapped `hermes` CLI + HERMES_HOME
  herdr.enable = true;              # herdr's integration plugin
  environmentFiles = [ config.sops.secrets.hermes-env.path ];
  # Leave settings.model unset to preserve runtime /model selections.
  extraPackages = [ pkgs.ffmpeg pkgs.nixd ];
};
```

Upstream's options keep their meaning, except for these:

- **`user` has no default, and `createUser` is gone.** Hermes is single-owner:
  saving a credential chmods `HERMES_HOME` to `0700`, `state.db`, `auth.json`
  and the locks are `0600`, and the gateway lock and control socket refuse
  files another uid owns. So the gateway runs as the account that uses the
  CLI, and the module doesn't create it. The module also doesn't set linger
  for it; without linger, cron runs unscoped workers.
- **`group` (default `hermes`) is created with no members.** It keeps the
  state and its `0640` `.env` off the user's primary group. Directories are
  setgid, so files the CLI writes there take the group too.
- **Directories are `2750`, not `2770`**, and activation adds no group write
  to files. The CLI refuses to reach the gateway through a group-writable
  `HERMES_HOME` (`unsafe_control_permissions`) unless the group is the
  owner's private group.
- **`addToSystemPackages` installs a wrapped CLI.** Every binary gets
  `--set-default HERMES_HOME`, and the variable is still exported.
  `environment.variables` alone is skipped by every process under a running
  session: they inherit `__NIXOS_SET_ENVIRONMENT_DONE=1`. The CLI then
  silently creates an unmanaged `~/.hermes`, whose own gateway refuses
  sessions with `storage_unavailable`. `config.yaml` stays `0640`; upstream
  made it `0660` for group members.
- **`herdr.enable`** (new) is a Herdr integration in TypeScript on bun
  ([`nix/herdr`](nix/herdr)), replacing the Python plugin
  `herdr integration install hermes` writes. That plugin reads the pane from
  its own process environment, but the `hermes` CLI is a gateway client and
  every hook runs in the gateway, so it never fired. Two parts:
  - `cli.ts` is the `hermes` CLI (needs `addToSystemPackages`). For an
    interactive chat in a Herdr pane it writes a marker naming the pane's pty
    (`$HERMES_HOME/herdr-panes/`), and in a Herdr app pane reports `idle` at
    launch, so the Agents list shows Hermes before the first prompt, and
    `state=clear` at exit (herdr-core otherwise keeps a status until the
    pane's shell exits).
  - `hook.ts` is a gateway shell hook (`settings.hooks`) on the turn events.
    It maps the session to a pty through the CLI's terminal breadcrumbs
    (`$HERMES_HOME/terminal-sessions/`, so `session.terminal_continue` must
    stay on) and the live marker, then writes OSC 7501
    working/idle/blocked to the pty (Herdr app) or runs
    `herdr pane report-agent-session` (Herdr TUI).
  Activation approves exactly this build's hook in
  `shell-hooks-allowlist.json` (shell hooks need consent) and drops earlier
  builds' approvals; the gateway rereads it within ~30 s. It also removes the
  old plugin's `plugins/herdr-agent-state` link. The config merge also removes
  only that retired name from `plugins.enabled`, preserving unrelated entries.
- **Model ownership.** Leave `settings.model` unset when `/model --global`
  should persist across rebuilds. If Nix owns the model instead, declare its
  full provider/endpoint/API-mode mapping: deep merge preserves unspecified
  fields, including stale transport fields from a runtime provider switch.
- **Terminal dependencies.** `extraPackages` populates both the gateway PATH
  and the user's per-user profile. Login-shell terminal tools replace the
  gateway wrapper's PATH, so dependencies needed there must be in the profile.
- **`settings` lists concatenate** across definitions. Upstream's
  `recursiveUpdate` kept only the last module's list, so `herdr.enable`
  would have dropped a host's own `plugins.enabled` entries.
- **Container mode is gone**, with its options and `stateDir/home`.

`hermes setup`, `hermes config set` and `hermes gateway install` refuse to
run in managed mode, as upstream intends. Change settings in Nix.

## The nix-darwin module

```nix
services.hermes-agent = {
  enable = true;                    # user defaults to system.primaryUser
  addToSystemPackages = true;
  herdr.enable = true;
  sandbox.readWritePaths = [ "/Users/alice/src/project" ];
  environmentFiles = [ config.sops.secrets.hermes-env.path ];
};
```

The same options and the same single-owner layout as the NixOS module, with
these differences:

- **`stateDir` defaults to `~/.hermes-agent`**, mode `0700`, with no group.
  It holds `HERMES_HOME` (`.hermes`) and the default workspace, and is `HOME`
  for every Hermes process, so what the agent's tools write to `~` lands
  there.
- **The gateway is a launchd user agent** (`org.nixos.hermes-agent`, logs in
  `~/Library/Logs/hermes-agent{,.err}.log`). It runs while the user is logged
  in. `gateway.enable = false` leaves only the CLI, which then starts its own.
  `backend.mode` adds a second agent, as on NixOS.
- **The agent runs `hermes gateway run --external-supervisor`.** Hermes
  recognises launchd only by an `ai.hermes` job label, and ours is
  `org.nixos.hermes-agent`.
- **Only the agent can be the gateway.** A CLI that finds no gateway starts
  its own, which holds the lock while that CLI stays open, and the agent then
  exits every five seconds for as long (seen on mini). `--replace` can't fix
  it: each launch is its own sandbox, Seatbelt allows signals only inside
  one, and the SIGTERM is refused. So with `gateway.enable` the CLI's profile
  denies writes to `gateway.lock`, `gateway.pid` and the host lock
  directory. A CLI started while the agent is down says `Gateway could not
  start`; run it again once the agent is back. For the same reason `hermes
  gateway stop|restart` can't signal the agent's gateway: use `launchctl
  kickstart -k gui/$(id -u)/org.nixos.hermes-agent`.
- **Activation runs as root** after the other activation scripts, so it can
  read a root-only `environmentFiles` secret, and hands what it creates to
  the user.
- **`.managed` still says `nixos`.** Hermes knows only `nixos` and
  `home-manager`, so its refusals name `nixos-rebuild`.
- **The Herdr wrapper and the TUI's breadcrumb helper find the pty with
  `/usr/bin/tty`** (macOS has no `/proc`). Without the second, the hook
  can't map a session to its pane, and the pane stays `idle` in Herdr.
- **A fresh install has no model, and no session starts without one.** The
  TUI shows `error: storage_unavailable` (the log: `invalid policy at
  restore_policy`), and `/model … --global` answers `no active session`.
  Either declare `settings.model` in full, or seed `config.yaml` once by
  hand and restart the gateway
  (`launchctl kickstart -k gui/$(id -u)/org.nixos.hermes-agent`).

### The sandbox

`sandbox.enable` (default on) starts the gateway, the backend and every
binary of the installed CLI through `nix/darwinSandbox.nix`: a
deny-by-default Seatbelt profile applied with `/usr/bin/sandbox-exec`. The
kernel enforces it on every descendant, and a sandboxed process can't apply
another profile or leave. Upstream's alternative, the `docker` terminal
backend, confines the agent's shell commands but not the agent, and needs a
container runtime.

| | Allowed |
| --- | --- |
| Read | `/nix`, `/usr`, `/bin`, `/sbin`, `/opt`, `/System`, `/Library`, `/Applications`, `/etc`, `/var/{db,run,select}`, `/dev`, and `sandbox.readPaths` |
| Read + write | `stateDir`, a private `TMPDIR` (`$(getconf DARWIN_USER_TEMP_DIR)hermes-agent`), `sandbox.readWritePaths`, the terminal devices |
| Network | IP out anywhere, listen on loopback; unix sockets only in the writable paths, plus mDNSResponder, syslog and `sandbox.unixSockets` |
| Environment | `TERM`, locale, `PATH`, `HERMES_*`, `HERDR_*`, `HC_*` and a few more, plus `sandbox.passEnvironment`; everything else in the caller's shell is dropped |

Checked on macOS 26.4.1 (2026-11-09), from inside the sandbox:

| Attempt | Result |
| --- | --- |
| `cat ~/.ssh/config`, `ls /Users/k`, `ls /private/tmp` | Operation not permitted |
| write to `/Users/k`, `/tmp` | Operation not permitted |
| `ssh-add -l` against the 1Password and git-signing agent sockets | Operation not permitted |
| `tmux ls` (socket in `/tmp`) | Operation not permitted |
| `security find-generic-password`, `security list-keychains` | fails (no keychain access) |
| `osascript -e 'tell application "Finder" ...'`, `open -a` | fails (no Apple events, no LaunchServices) |
| `launchctl submit`, `launchctl bootstrap gui/501` | job never created |
| `sudo`, `crontab` (setuid) | Operation not permitted |
| `defaults write` | refused |
| nested `sandbox-exec` | `sandbox_apply: Operation not permitted` |
| `GH_TOKEN=x hermes ...` | variable absent inside |
| `curl https://api.anthropic.com`, `git ls-remote https://...`, nixpkgs python `urlopen` | work |
| `hermes --version`, `hermes gateway`, `hermes gateway status`, the Herdr hook on bun | work |

What it does not do:

- **The network is open.** The agent can send anything it can read to any
  host. What it can read is the system, its own state (provider keys in
  `.env` and `auth.json` included) and the listed paths.
- **Reads of `/nix/store` are allowed**, as for every local user. Keep
  secrets out of the store.
- **A listed path is fully trusted.** A checkout in `readWritePaths` whose
  hooks, `.envrc` or build scripts you later run outside the sandbox is a way
  out.
- **`sandbox.unixSockets` entries are doors.** The nix daemon socket is not
  listed by default: with it the agent can build and run derivations as the
  nix build users. Without it `nix eval` works and `nix build` does not.
- **Tools that sandbox themselves fail inside**: Chromium-based browsers and
  `nix build --sandbox`, because Seatbelt profiles don't nest.
- **`HERMES_SANDBOX=1` in the caller's environment skips the launcher.** That
  is how a `hermes` started inside the sandbox avoids applying it twice. It
  isn't a way out from inside, only a way not to enter.
- `sandbox-exec` is deprecated by Apple but is what nix, Chromium and the
  other agent CLIs use.
- Later the same day, on mini with a Codex login, a live agent's own
  terminal and file tools gave the same results (home unreadable, workspace
  writable, network up, no keychain), and Herdr showed working/idle.

Xcode's `/usr/bin` shims (git, python3) cache their tool lookup as
`xcrun_db*` in the real temp directory, not `TMPDIR`; the profile allows
exactly those files. `/bin/ps` is
setuid and refused, so the launcher puts nixpkgs' unprivileged `ps` first on
`PATH`; Hermes uses `ps` to recognise gateway processes.

The control socket lives in `HERMES_HOME` when the path fits `sun_path`
(about 100 bytes). A longer `stateDir` makes Hermes fall back to `/tmp`,
which the sandbox refuses, and the gateway exits with `control listener
unavailable`. Keep `stateDir` short.

To see what the sandbox refused:

```sh
log show --last 5m --style compact \
  --predicate 'sender == "Sandbox" AND eventMessage CONTAINS "deny"' | grep -E 'python|hermes|bun'
```

## Consuming it

```nix
inputs.hermes-agent = {
  url = "./flakes/hermes-agent";
  inputs.flake-parts.follows = "flake-parts";
};
```

There is no `inputs.nixpkgs.follows`: the inputs are locked to the tag's own
`flake.lock`, so the package is the derivation upstream tested. Up to v0.22.5
the follow was impossible, because patchelf 0.19.2 corrupted the prebuilt
node from `pm/lock.json` (NixOS/patchelf#674). Since v0.23.0
`nix/pm-packages.nix` patches patchelf itself, so a follow could come back.
It has not been tried: it needs a Linux build to check, and a nixpkgs the
release was not tested with.

## Bumping the tag

1. Read upstream's `nix/` changes since the current tag, and port them into
   `nix/` (only the files copied here):
   ```sh
   git -C <hermes-agent checkout> diff v0.23.0 v<new> -- nix/
   ```
2. Point `hermes-agent-src` at the new tag. Set `version` in
   `nix/packages.nix` to match.
3. Lock our inputs to the revs in the new tag's `flake.lock` (`nixpkgs`,
   `pyproject-nix`, `uv2nix`, `pyproject-build-systems`), for example
   `nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/<rev>`.
   Then run `nix flake update hermes-agent` in the root.
4. Check that both source patches still apply
   (`git -C <checkout> apply --check nix/*.patch`), compare the derivation
   (above) with `version = "0.0.0"` against the new tag's `default`, then
   build nebula and a mac.
