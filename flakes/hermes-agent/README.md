# hermes-agent

Packages Nous Research's [Hermes Agent](https://github.com/NousResearch/hermes-agent)
(the `hermes` CLI and its messaging/cron gateway) and provides a NixOS module
(`services.hermes-agent`) that runs the gateway as the same account that uses
the CLI.

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
| [`flake.nix`](flake.nix) | flake-parts flake for `x86_64-linux` and `aarch64-linux`. The `hermes-agent-src` input is upstream's source at a release tag (`flake = false`). The other inputs are locked to that tag's own `flake.lock`. |
| [`nix/`](nix) | The copied files, under upstream's names and layout. `nix fmt` formats them like the rest of the repo, so compare against upstream run through nixfmt: `nixfmt < <upstream>/nix/<file> \| diff - nix/<file>` shows only our changes. Each changed file says what changed in a comment marked `Ours:`. |

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
nix eval --raw github:NousResearch/hermes-agent/v0.22.5#packages.x86_64-linux.default.drvPath
```

## Flake outputs

- `packages.<system>.hermes-agent` (and `default`): upstream's `full` package,
  with all the portable optional integrations, plus `matrix` on Linux.
  Changes against upstream:
  - `version` is the release tag. Upstream leaves it at `0.0.0`, and
    `hermes --version` printed `v0.0.0`.
  - The desktop app, the dev-shell passthru and the npm-lockfile tooling are
    gone.
  - The TUI and web bundles still build, as passthru.
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
- `nixosModules.default`: the module. It keeps upstream's output name.

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

## Consuming it

```nix
inputs.hermes-agent = {
  url = "./flakes/hermes-agent";
  inputs.flake-parts.follows = "flake-parts";
};
```

Do **not** add `inputs.nixpkgs.follows`. The package autopatchelfs a prebuilt
node from `pm/lock.json`. The root's nixpkgs (2026-10-23) has patchelf 0.19.2,
which corrupts it (NixOS/patchelf#674), and node then segfaults during the TUI
build (`npm config set offline true`, exit 139). The tag's own nixpkgs
(2026-07-29) predates that patchelf. Upstream main carries a patched
patchelf. Once a release tag includes it, `nix/pm-packages.nix` can take it
and the follow can come back.

## Bumping the tag

1. Read upstream's `nix/` changes since the current tag, and port them into
   `nix/` (only the files copied here):
   ```sh
   git -C <hermes-agent checkout> diff v0.22.5 v<new> -- nix/
   ```
2. Point `hermes-agent-src` at the new tag. Set `version` in
   `nix/packages.nix` to match.
3. Lock our inputs to the revs in the new tag's `flake.lock` (`nixpkgs`,
   `pyproject-nix`, `uv2nix`, `pyproject-build-systems`), for example
   `nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/<rev>`.
   Then run `nix flake update hermes-agent` in the root.
4. Check parity (above) with `version = "0.0.0"` against the new tag's
   `default`, then build nebula.
