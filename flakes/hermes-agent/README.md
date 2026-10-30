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

That makes parity checkable. With `version` reset to upstream's `0.0.0`, the
package is the same derivation as upstream's `packages.x86_64-linux.default`
at v0.22.5:

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
- `nixosModules.default`: the module. It keeps upstream's output name.

## The NixOS module

```nix
services.hermes-agent = {
  enable = true;
  user = "alice";                   # runs the gateway, owns HERMES_HOME, uses the CLI
  addToSystemPackages = true;       # the wrapped `hermes` CLI + HERMES_HOME
  herdr.enable = true;              # herdr's integration plugin
  environmentFiles = [ config.sops.secrets.hermes-env.path ];
  settings.model = { provider = "anthropic"; default = "claude-opus-5-5"; };
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
- **`herdr.enable`** (new) generates herdr's Hermes integration with
  `herdr.package`'s own `herdr integration install hermes`. It links the
  plugin at `plugins/herdr-agent-state`, where `herdr integration status`
  finds it, and adds it to `settings.plugins.enabled`.
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
