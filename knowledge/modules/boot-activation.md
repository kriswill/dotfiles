---
type: Darwin Module
title: Boot Activation
description: 'Boot activation restores /etc and keyboard settings; full rebuild probes belong to nrs, where applications, users, Homebrew, and Nix can change.'
resource: modules/darwin/boot-activation.nix
tags: [darwin-module]
generated: { by: codex/gpt-6, at: 2026-11-13T13:52:03-08:00 }
sources:
  - id: upstream-boot
    resource: https://github.com/nix-darwin/nix-darwin/blob/ff0e21a414d4547183396da1b44a66f2577b65e9/modules/services/activate-system/default.nix
    title: Pinned nix-darwin boot activation service
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin configuration options
  - id: startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Measured boot timeline and startup fixes
---

The upstream boot job restores `/run/current-system`, `/etc`, and keyboard
settings, yet also runs the probes used by full rebuilds.[^upstream-boot]
On [mini](../hosts/mini.md), App Management denied its app-write probe and
stopped activation before `/etc` repair. The boot script now sets a local
flag that skips `system.checks.text`; the separate `/etc` conflict/hash
checks still run. Normal [nrs](nrs.md) activation and check-only mode retain
all rebuild checks. See [Darwin early boot](../decisions/darwin-early-boot.md)
for the merge-order dependency and validation.

Launchd sends both output streams to `/var/log/nix-darwin-boot.log`, using
its `StandardOutPath`/`StandardErrorPath` options.[^darwin-options] The
script records a UTC start timestamp, exit status, and elapsed seconds;
the timer excludes waiting for the store and interpreter to become usable.
Check this log and `launchctl print system/org.nixos.activate-system` after
a reboot: `nrs --status` only compares generations.[^startup-manual]

[Zsh](zsh.md) separately provides a persistent-profile PATH fallback so
noninteractive SSH tools can start while this job is still pending.

Verified after mini activated generation 26: the job ran once during the
switch, exited 0, and logged `elapsed=0s` at whole-second precision. All
24 managed `/etc` links matched the active generation. The subsequent
13:45:15.361 PST reboot completed activation at +10.2 s with
`status=0 elapsed=1s`; launchd reported one run, exit 0, and all 24 entries
still matched. hc was active at +16.4 s, versus +47.1 s in the prior
boot.[^startup-manual]

Mounted ungated on every darwin host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/boot-activation.nix`](../../modules/darwin/boot-activation.nix)

[^upstream-boot]: Boot restores runtime links, then runs checks, etc, and keyboard activation fragments.
[^darwin-options]: The launchd daemon's serviceConfig exposes both log-path options.
[^startup-manual]: Generation-25 timing evidence, fixture tests, and generation-26 activation verification, 2026-11-13.
