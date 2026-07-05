---
type: Nix Package
title: Podman
description: 'Podman — the daemonless, Docker-compatible container engine; on macOS packaged from the official prebuilt darwin_arm64 remote client (nixpkgs'' podman refuses to evaluate on darwin) with vfkit + gvproxy bundled in, primarily serving minikube''s podman driver for work Kubernetes.'
resource: pkgs/podman.nix
tags: [package, containers, kubernetes]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Podman](https://podman.io) is a daemonless, Docker-CLI-compatible engine
for containers, pods, and images. On macOS the `podman` binary is a remote
client driving a Linux VM (a "podman machine"), which is why the package
story below is about helper binaries and VM backends rather than the engine
itself.

## Why it's packaged this way

nixpkgs' podman sets `meta.platforms = lib.platforms.linux` and refuses to
evaluate on aarch64-darwin, so `pkgs/podman.nix` fetches the official
`podman-remote-release-darwin_arm64.zip` as a fixed-output derivation and
installs the adhoc-signed Mach-O binaries verbatim (`dontFixup` — stripping
or re-signing would invalidate the signature and macOS would refuse to exec
them). The machine helpers podman needs, vfkit + gvproxy, are bundled into
`$out/libexec/podman`, where podman's compiled-in darwin default
(`$BINDIR/../libexec/podman`) finds them — no `containers.conf` override.
The [overlay](../../overlays/podman.nix) replaces `pkgs.podman` and is
internally platform-guarded: Linux hosts keep nixpkgs' podman. Full
rationale and history:
[Podman From the Official Binary](../decisions/podman-official-binary.md).

**Machine backend is applehv** (Apple Virtualization.framework via vfkit),
set in the stow-managed `containers.conf` — libkrun was abandoned because
nixpkgs' libkrun-efi ships no EFI firmware (krunkit fails with "can't find
a firmware to load") and M1 has no nested virtualization for libkrun's
extra features to exploit.

## What it's for

The primary workload is **minikube with the
[podman driver](https://minikube.sigs.k8s.io/docs/drivers/podman/)** —
local Kubernetes for work — with `k9s` alongside it in the same host
package lists. minikube itself is not nix-managed; this package provides
the engine it drives. Installed on [k](../hosts/k.md) and
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md) together with
[podman-desktop](../modules/podman-desktop.md); mini deliberately carries
no podman stack.

## Source

- Package: [`pkgs/podman.nix`](../../pkgs/podman.nix)
- Version at last scaffold: `6.0.0`
- Overlay: [`overlays/podman.nix`](../../overlays/podman.nix) — exposes/replaces `pkgs.podman`

## Citations

- [podman.io](https://podman.io) — official site
- [minikube podman driver](https://minikube.sigs.k8s.io/docs/drivers/podman/)
- [Podman From the Official Binary](../decisions/podman-official-binary.md)
  (commits `07684b6`, `4dc74e4`, `f3fb252`)
