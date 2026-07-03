---
type: NixOS Module
title: Console Quiet
description: Sets boot.consoleLogLevel = 3 so the benign AMD i2c_piix4 SMBus probe-NAK errors stop flashing over the ly greeter; journald still records everything.
resource: modules/hosts/nebula/console-quiet.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Sets `boot.consoleLogLevel = 3` so KERN_ERR messages stop rendering on the
VT. The trigger: on this AMD board the i2c_piix4 SMBus ports (i2c-1/i2c-2,
the RAM-SPD & sensors bus — not the NVIDIA monitor DDC buses) emit
err-priority probe NAKs a few seconds into boot ("i2c i2c-1: Failed reset at
end of transaction"). They are a well-known benign AMD SMBus quirk, but at
the default `console_loglevel = 4` they render on the VT right as the ly
greeter comes up, reading like a boot failure.

At level 3 only crit/alert/emerg (0–2) reach the console. journald is
unaffected and still records everything (`journalctl -k`), so real
diagnostics are never lost — they just stop flashing on the login screen.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/console-quiet.nix`](../../modules/hosts/nebula/console-quiet.nix)
