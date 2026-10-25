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

A third `ExecStopPost` entry, `nixploit-report-html`, renders
`/var/lib/nixploit/report.html` (also 0640). It's a copy of the standalone
viewer `modules/hosts/nebula/nixploit-report.html` with the latest report
embedded at its marker line, so it opens straight from `file://`. Browsers
block `fetch()` from a `file://` page, so a viewer next to `report.json`
couldn't load it. The renderer escapes every `<` in the JSON as `<`
(it only appears inside strings), so advisory text can't close the script
tag. Opened without embedded data, the template falls back to a file picker
and drag-and-drop. The viewer shows:

- summary cards;
- affected/unknown/suppressed tabs;
- severity and known-exploited filters;
- one row per package/version/vulnerability (collapsing the same finding
  across derivations);
- a per-package view;
- per-finding evidence, with a copyable `services.nixploit.settings.ignore`
  entry.

Its "fixed in" column re-derives nixploit's `fixed_in` from the serialized
claims, which the JSON report doesn't include.

The renderer also runs `nixploit-report-graph` (`nixploit-report-graph.sh`,
a separate program so its failure only drops the analysis). It embeds about
300 KB of graph data:

- the running system's reference graph, from `nix path-info --recursive
  --json`;
- which system generations hold each path.

The page uses it to answer, for every build of a finding:

- **Who pulls it in.** Climb its referrers up to the entries the system
  lists directly: `system-path` children (environment.systemPackages),
  `system-units`/`user-units` children (units; a non-unit child there comes
  from `systemd.packages`), `etc` entries, and direct toplevel references.
  Restart-trigger nodes are skipped, because they reference everything.
- **Which package owns it.** Either the outermost dominator below the
  toplevel (every route passes through it, as with Lutris's FHS runtime), or
  a consumer every other consumer depends on (Determinate Nix for the Nix
  tools and services built on it).
- **The shortest route**, preferring the systemPackages branch.
- **Whether a fixed copy of the same package is already installed.** If so,
  the vulnerable one is a separately pinned duplicate.
- **Which generations keep it.**

From these it writes rule-based "What to do" advice and "When it runs"
exposure hints, and groups findings in a Causes view. Builds whose `.drv`
nixploit listed without outputs (duplicate derivers) are skipped.
Exploitability stays the reader's call. Dev shells and other GC roots aren't
covered: they're outside the `--system` scan, and the service user isn't
trusted to list them.

This file is merged straight into the host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). It is a
host-side enable gate like
[nebula-codebase-memory-mcp](nebula-codebase-memory-mcp.md).

## Source

- Module: [`modules/hosts/nebula/nixploit.nix`](../../modules/hosts/nebula/nixploit.nix)

[^nixploit-readme]: nixploit README (NixOS section)
[^node-exporter-listen]: NixOS option: services.prometheus.exporters.node.listenAddress
