---
type: Decision
title: Make Darwin SSH Startup Independent of Boot Activation
description: 'Initialize the persistent system PATH in every Zsh shell and reserve rebuild probes for full activation while preserving boot-time /etc overwrite checks.'
tags: [darwin, boot, zsh, performance]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T13:52:03-08:00 }
sources:
  - id: startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Measured mini reboot timeline and regression checks
  - id: upstream-boot
    resource: https://github.com/nix-darwin/nix-darwin/blob/ff0e21a414d4547183396da1b44a66f2577b65e9/modules/services/activate-system/default.nix
    title: Pinned nix-darwin boot activation service
---

**Where:** [Zsh](../modules/zsh.md) and
[boot activation](../modules/boot-activation.md).

## Context

[mini](../hosts/mini.md)'s generation-25 reboot mounted `/nix` at +11 s,
accepted early SSH sessions at +15.5 s, and created `/run/current-system`
at +24.1 s. [Herdr](../modules/herdr.md)'s successful retry started its
core at +47.1 s. The interactive-only PATH fallback did not help SSH
commands; the observed 30-second retry gap matches hc's reconnect ceiling.
This is strong evidence for the cause, although the early command's stderr
was not retained.[^startup-manual]

The boot job then failed an App Management write probe at +28.2 s. Its
actual work only restores runtime links, `/etc`, and keyboard settings;
it does not install applications.[^upstream-boot]

## Decision

Append the persistent system-profile bin directory in Darwin's
`programs.zsh.shellInit` with a builtin, idempotent array check. This reaches
noninteractive shells without changing inherited project PATH priorities.
Remove the old `.zshrc` copy. Tools still require `/nix` to be mounted.

Mark only the boot script with `NIX_DARWIN_BOOT_ACTIVATION=1` and wrap
`system.checks.text` in a condition. Keep the full
`system.activationScripts.checks` fragment: upstream appends `/etc` hash
and conflict checks there, outside `system.checks.text`. This preserves
overwrite protection during boot. [nrs](../modules/nrs.md) activation and
check-only mode run the full probes with a cleared environment.

Use `mkBefore` for the opening condition and `mkOrder 2000` for its closing
`fi`, after the upstream application probe's `mkAfter` (1500). This avoids
copying or patching the upstream activation script. When updating
nix-darwin, inspect the merged script for new check contributions outside
these orders or movement of the `/etc` checks.

Log boot output, UTC start time, exit status, and elapsed seconds to
`/var/log/nix-darwin-boot.log`. The timer begins inside the Nix Bash script,
so mount/interpreter startup delays still need unified logs.

## Consequences

The existing generation retains its `/etc` overwrite protection at boot
without requiring GUI app-write permission. SSH can find hc in the gap
before the runtime profile appears, avoiding a likely unnecessary reconnect
wait. Keep hc's demand-driven startup and reconnect policy unchanged.

The mini dry build, all Darwin host evaluations, and fixture checks passed:
missing managed links are restored, unfamiliar content is preserved with
exit 2, and normal/check-only probes still reject denied app writes.
PATH tests cover missing `/run`, inherited priorities, repeated sourcing,
and nested shells. Warm noninteractive medians stayed about 3.5 ms.
`nrs` activated mini generation 26; the boot job ran during the switch
with exit 0 and logged `elapsed=0s` at whole-second precision. Live shell
tests and all 24 managed `/etc` links passed. The 13:45:15.361 PST cold reboot then completed boot activation at
+10.2 s with `status=0 elapsed=1s`; all 24 `/etc` entries matched. The first
observed SSH login succeeded at +15.5 s and hc was active at +16.4 s, versus
+47.1 s in generation 25. This is one before/after observation; the runtime
profile already existed before SSH, so it does not independently exercise
the fallback PATH branch.[^startup-manual]

[^startup-manual]: Machine evidence, fixture checks, and generation-26 activation verification on 2026-11-13.
[^upstream-boot]: nix-darwin ff0e21a boot activation scope.
