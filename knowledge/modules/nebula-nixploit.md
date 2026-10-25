---
type: NixOS Module
title: Nixploit
description: 'Turns on nixploit''s daily vulnerability scan on nebula with upstream''s recommended settings plus the OSV provider (and with it the upstream-history check), and keeps the node_exporter the module brings in bound to loopback.'
resource: modules/hosts/nebula/nixploit.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T23:30:00-07:00 }
sources:
  - id: nixploit-readme
    resource: https://github.com/manic-systems/nixploit
    title: 'nixploit README (NixOS section)'
  - id: node-exporter-listen
    resource: https://search.nixos.org/options?channel=unstable&query=services.prometheus.exporters.node.listenAddress
    title: 'NixOS option: services.prometheus.exporters.node.listenAddress'
---

Turns on [nixploit](nixploit.md) on [nebula](../hosts/nebula.md) with the
README's recommended block, `enable = true; calendar = "daily";`, and adds
`providers = [ "nvd" "osv" ]`.[^nixploit-readme] That means:

- NVD is imported from 2002 on.
- OSV downloads all five dumps (PyPI, npm, crates.io, Go and GIT). OSV
  claims only match packages built by the matching nixpkgs language builder.
- GIT's commit ranges turn `history.enable` on by default. Before each scan,
  `nixploit history` refreshes commit-only clones of the upstreams named by
  affected findings (kernel excluded) and suppresses findings whose fix is
  already in the installed release's tag.
- The kernel Kbuild filter is on (nebula's kernel has a `configfile`).
- Build dependencies are off.

The NVD-only baseline scan (2026-10-24, run before OSV was added) found 397
unique package/version/CVE matches: 17 critical and none known-exploited.
Most critical findings came from Determinate Nix's own bundled closure (curl,
openssl and wasmtime that our nixpkgs already ships fixed) and from the
Steam/Lutris/WowUp FHS sandboxes.

One deviation: the module enables node_exporter, which listens on
`0.0.0.0:9100` by default. Nebula has no Prometheus and nothing scrapes it
from another host. The firewall already keeps the port closed, so the file
sets `listenAddress = "127.0.0.1"` as an extra guard.[^node-exporter-listen]

The file also adds k to the module's `nixploit` group so the report can be
read without sudo. Membership alone isn't enough, because upstream's
`report.nu` creates each report with `install --mode=0600`. So the file
appends `-chmod g+r /var/lib/nixploit/report.json` to the unit's
`ExecStopPost`. That list merges with the module's own `report.nu finish`
string, and both run.

This file is merged straight into the host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). It is a
host-side enable gate like
[nebula-codebase-memory-mcp](nebula-codebase-memory-mcp.md).

## Source

- Module: [`modules/hosts/nebula/nixploit.nix`](../../modules/hosts/nebula/nixploit.nix)

[^nixploit-readme]: nixploit README (NixOS section)
[^node-exporter-listen]: NixOS option: services.prometheus.exporters.node.listenAddress
