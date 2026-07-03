# apple-container

Repackages [Apple's `container`](https://github.com/apple/container) — the native Linux
container runtime for Apple Silicon Macs — as a Nix package.

## How it works

Apple distributes `container` as a flat, signed `.pkg`. `package.nix` fetches the signed
release asset (`container-<version>-installer-signed.pkg`), extracts it with `xar` + `cpio`,
and installs the already-signed Mach-O binaries:

- `bin/container`, `bin/container-apiserver`
- `libexec/container/plugins/*` (runtime / network / images plugins)

We **don't** build from the Swift source — that needs the macOS SDK, Virtualization
entitlements, and re-signing, which don't fit a Nix build. `dontFixup = true` preserves
Apple's code signature and entitlements on the extracted binaries.

### Why `container` is wrapped

`container` locates its plugins under `<install-root>/libexec/container/plugins`, where
`install-root` is the **grandparent of its own executable path**. Per upstream
`InstallRoot.swift`, that path comes from `_NSGetExecutablePath` and is **not**
symlink-resolved. Invoked via the Nix profile (`~/…/bin/container`), the install root would
resolve to the profile directory — which links `bin/` but **not** `libexec/` — so
`container system start` fails with `cannot find any plugins`. We therefore `makeWrapper`
the CLI so it execs from `$out`, fixing the install root to the store path (which has
`libexec/`). `container system start` then bakes that store path into the apiserver's
launchd plist (`CONTAINER_INSTALL_ROOT`) and points `ProgramArguments` at the real,
symlink-resolved `$out/bin/container-apiserver`.

The install root is **read-only** — plugins are only ever read from it. All mutable state
lives under `CONTAINER_APP_ROOT` (`~/Library/Application Support/com.apple.container`:
containers, networks, volumes, kernels, plugin-state) and logs under `CONTAINER_LOG_ROOT`,
so a read-only Nix store path is the correct home for the install root.

### Runtime

This package intentionally ships **only the CLI**. The runtime is managed by Apple's own
tooling: run `container system start` once (it registers a launchd service for the
apiserver and downloads the default Linux kernel on first start). After a version bump the
store path changes, so re-point the service with `container system stop && container system start`.

## nix-darwin module

The flake also exports `darwinModules.apple-container` (alias: `default`), defined in
`darwin-module.nix`. It installs the package and adds two activation-time guards:

- **Foreign-install check** (`system.checks`): refuses to activate over a manual `.pkg`
  or Homebrew install of `container`; a stale pkgutil receipt (binaries already removed)
  only warns. Exercised by `darwin-rebuild check` too.
- **Runtime drift check** (`postActivation`): when the apiserver's launchd plist points
  at an older store path, stops the old runtime (best-effort, in the primary user's
  launchd domain) and reminds you to run `container system start`. Abnormal states warn
  rather than silently skipping.

```nix
{
  inputs.apple-container.url = "./flakes/apple-container"; # or a repo URL after extraction

  # in the nix-darwin configuration:
  modules = [ inputs.apple-container.darwinModules.apple-container ];
}
```

Options: `services.apple-container.enable` (default `false`) and
`services.apple-container.package` (defaults to this flake's package for the host
system — no overlay needed). The module requires `system.primaryUser` to be set.

## Bumping the version

Update `version` (and `hash`) in `package.nix`. The hash is the SRI form of the release
asset's sha256 — GitHub publishes it in the asset's `digest` field, so you can derive it
without downloading:

```
nix hash convert --hash-algo sha256 --to sri <hex-digest-from-github>
```

## Build

```
nix build .#apple-container
```

aarch64-darwin only.
