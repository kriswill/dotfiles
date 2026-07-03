---
type: Darwin Module
title: Apple Container
description: 'Apple''s native macOS container CLI, mounted into hosts k + SOC.'
resource: modules/hosts/apple-container.nix
tags: [darwin-module, host-mounted]
timestamp: '2026-07-03T10:23:09-07:00'
---

Apple's native macOS container CLI, mounted into hosts k + SOC. The nix-darwin module ships with the sub-flake (./flakes/apple-container/darwin-module.nix) and defaults services.apple-container.package to the sub-flake's own package, so no overlay or pkgs wiring is needed.

Host-mounted feature ([SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md), [k](../hosts/k.md)) — merged
straight into the hosts' configurations per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/apple-container.nix`](../../modules/hosts/apple-container.nix)
