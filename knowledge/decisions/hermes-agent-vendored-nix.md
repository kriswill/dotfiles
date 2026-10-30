---
type: Decision
title: Vendor Hermes Agent's nix/ into a Sub-flake
description: 'Hermes Agent''s package and NixOS module are built from a trimmed copy of upstream''s nix/ in flakes/hermes-agent, against the release source as a flake = false input, because every workaround nebula needed lived in upstream''s module and its flake carried home-manager, Electron and dev tooling the repo does not use; bumps become manual ports, checked by drv parity.'
tags: [ai-agent, sub-flake]
status: stable
generated: { by: claude-code/opus-5-5, at: 2026-10-30T03:00:00+00:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md'
  - id: upstream-nix-v0-22-5
    resource: https://github.com/NousResearch/hermes-agent/tree/v0.22.5/nix
    title: 'Upstream nix/ at v0.22.5'
---

**Where:** [hermes-agent sub-flake](../packages/hermes-agent.md),
[hermes-agent module](../modules/hermes-agent.md),
[nebula-hermes-agent](../modules/nebula-hermes-agent.md).

## Context

The first cut consumed upstream's flake directly
([hermes-agent-system-service](hermes-agent-system-service.md)). Running it
on nebula took three workarounds in the host file, all of them against
upstream's module:

- a CLI wrapper, because `addToSystemPackages` doesn't work;
- a `chmod g-w` activation snippet that undid upstream's `2770`;
- `createUser = false`, to get rid of the `hermes` system user that upstream
  designed around.

The flake also pulled in home-manager (cut with `follows = ""`),
npm-lockfile-fix, a dev shell, the Electron desktop app and a 1,600-line
checks suite, none of which this repo uses.

Two scopes were weighed. **Module only** copies the module and keeps
consuming upstream's package. **Module + package** also copies the package
derivations. Upstream's package files reach the source tree through `./..`,
so a copy needs the source as a separate input, every path rewritten, and a
manual port on each tag, because upstream changes `nix/` in lock-step with
its build scripts. Module + package was chosen, for full control of the
packaging: its inputs, its outputs, and a later patchelf fix that would let
it follow our nixpkgs.

## Decision

`flakes/hermes-agent/` is a flake-parts sub-flake:

- `hermes-agent-src` is upstream's source at `v0.22.5` (`flake = false`).
  `nixpkgs`, `pyproject-nix`, `uv2nix` and `pyproject-build-systems` are
  locked to that tag's own `flake.lock` revs. None of them follow the root:
  the root's patchelf corrupts the prebuilt node.
- `nix/` holds the copied files under upstream's names. `hermesSrc`, a path
  value at the source root, is handed to every `callPackage` by a scope, and
  `../x` becomes `hermesSrc + "/x"`. Only files that change are copied:
  `tui.nix`, `web.nix` and `configMergeScript.nix` are byte-identical, and
  the node-gyp lockfile is read from the source. Each change carries an
  `Ours:` comment.[^subflake-readme]
- The module is upstream's native mode, single-owner. `user` is required and
  never created; `group` is created with no members; state directories are
  `2750`; `addToSystemPackages` installs the `HERMES_HOME` wrapper; the new
  `herdr.enable` adds herdr's integration plugin. Container mode is gone.
  `settings` lists concatenate, so the plugin doesn't clobber a host's
  `plugins.enabled`.
- `version` is set to the tag. Upstream's `0.0.0` was what
  `hermes --version` printed.

Verified on 2026-10-29. With `version = "0.0.0"` the package is drv-identical
to upstream's `packages.x86_64-linux.default` (`zfdxw3zg…`). The version
bump changes only the install stamp. nebula's evaluated unit, `config.yaml`,
herdr plugin and users/groups are unchanged; tmpfiles and activation differ
only in the planned modes and the removed container/`home/` pieces. The
toplevel builds.

## Consequences

- The host file is plain option settings. Each workaround is a module
  behaviour, documented once in the
  [sub-flake README](../../flakes/hermes-agent/README.md).
- A tag bump is a port: diff upstream's `nix/` between the tags, apply the
  hunks to the copies, re-lock the four inputs to the new tag's lock, then
  re-check parity with `version = "0.0.0"`.[^upstream-nix-v0-22-5] `nix fmt`
  reformats the copies, so compare against `nixfmt`-formatted upstream.
- Upstream lint findings in verbatim lines (statix `inherit` hints, two
  unused lambda args) are left in place, to keep the port diffs small.
- The follow-up that justified copying the package: once a release tag
  ships upstream main's patched patchelf, `nix/pm-packages.nix` can take it
  and the sub-flake can follow the root's nixpkgs, which drops the second
  nixpkgs from nebula's closure.

[^subflake-readme]: flakes/hermes-agent/README.md
[^upstream-nix-v0-22-5]: Upstream nix/ at v0.22.5
