---
type: NixOS Module
title: ASTRO MixAmp Priority
description: 'WirePlumber monitor.alsa.rules drop-in raising the ASTRO MixAmp Pro headset nodes'' priority.session above the motherboard USB audio, so nebula falls back to the headset when a suspend/resume renames it.'
resource: modules/hosts/nebula/astro-mixamp.nix
tags: [nixos-module, host-specific, audio, pipewire, suspend]
generated: { by: claude-code/opus-5.5, at: 2026-10-02T19:40:00-07:00 }
sources:
  - id: wireplumber-alsa-configuration
    resource: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html
    title: 'WirePlumber — ALSA configuration (`monitor.alsa.rules`, `priority.session`)'
  - id: wireplumber-extraconfig-option-reference
    resource: https://search.nixos.org/options?channel=unstable&show=services.pipewire.wireplumber.extraConfig&query=services.pipewire.wireplumber.extraConfig
    title: '`services.pipewire.wireplumber.extraConfig` option reference'
  - id: docs-suspend-md
    resource: ../../docs/suspend.md
    title: '`docs/suspend.md`'
---

On resume from S3, nebula's Promontory 21 xHCI controllers reinit, and the
ASTRO MixAmp Pro can re-enumerate twice in a row. The second card appears
before the first is torn down, so WirePlumber's alsa monitor deduplicates the
device name (`alsa_card.usb-Astro_…-00` → `…-00.2`), and every node name
inherits the suffix (`alsa_output.usb-Astro_…-00.2.analog-stereo`). The
configured default and the default-nodes history
(`~/.local/state/wireplumber/default-nodes`) both store the un-suffixed name,
so neither matches. Selection then falls through to the highest
`priority.session`, which belonged to the motherboard's Generic USB Audio
pro-audio nodes (sink 1600, source 2600, against the MixAmp's 1109 and 2100).
On 2026-10-02 this left Discord capturing from an empty motherboard jack.[^docs-suspend-md]

This file adds a `monitor.alsa.rules` entry[^wireplumber-alsa-configuration]
through `services.pipewire.wireplumber.extraConfig`.[^wireplumber-extraconfig-option-reference]
The entry matches both MixAmp nodes by a `node.name` regex that tolerates the
suffix and sets `priority.session = 3000`, so the fallback lands on the
headset either way.

Gotchas:

- Priority only decides the default when no configured or remembered node is
  present. An explicit default choice still wins. Keep the value below 15000:
  above that, WirePlumber's best-node hook treats the pick as final.
- If the Generic USB Audio is ever set as the default, it enters the history
  stack at 20000-range priority. A renamed MixAmp would then lose to it, and
  this rule can't help.
- NixOS ships the drop-in through the user `wireplumber.service`'s
  `XDG_DATA_DIRS`, not `/etc`. A switch doesn't restart user units, so run
  `systemctl --user restart wireplumber` to load it. The same restart is also
  the live recovery: it recreates the nodes without the suffix.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). Sibling
resume workaround: [oled-resume-bump](oled-resume-bump.md).

## Source

- Module: [`modules/hosts/nebula/astro-mixamp.nix`](../../modules/hosts/nebula/astro-mixamp.nix)

[^wireplumber-alsa-configuration]: WirePlumber — ALSA configuration (`monitor.alsa.rules`, `priority.session`)
[^wireplumber-extraconfig-option-reference]: `services.pipewire.wireplumber.extraConfig` option reference
[^docs-suspend-md]: `docs/suspend.md` — Learned behaviours (2026-10-02 entry)
