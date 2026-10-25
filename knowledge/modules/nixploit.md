---
type: NixOS Module
title: Nixploit
description: 'Re-export of the nixploit sub-flake''s NixOS module: upstream''s scheduled vulnerability scanner (the running system''s Nix closure matched against NVD, plus optional OSV/VulnCheck, published as a JSON report and node_exporter metrics) plus services.nixploit.report for the HTML viewer and its readers; enabled on nebula.'
resource: modules/nixos/nixploit.nix
tags: [nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T23:30:00-07:00 }
sources:
  - id: nixploit-readme
    resource: https://github.com/manic-systems/nixploit
    title: 'nixploit README (usage, configuration, NixOS module)'
  - id: nixploit-module
    resource: https://github.com/manic-systems/nixploit/blob/master/nix/module.nix
    title: 'nixploit NixOS module source (services.nixploit.*)'
  - id: subflake-readme
    resource: ../../flakes/nixploit/README.md
    title: 'flakes/nixploit/README.md (the report options)'
---

A one-line re-export of `inputs.nixploit.nixosModules.nixploit`, from the
[nixploit sub-flake](../packages/nixploit.md). That module imports upstream's
module and adds `services.nixploit.report.{enable,readers}` and
`services.nixploit.rescanOnSwitch`.[^subflake-readme]
`services.nixploit.package` defaults to upstream's own build, so no overlay is
needed. It builds from source, because upstream has no binary
cache.[^nixploit-readme]

Enabling upstream's part brings in more than a timer:[^nixploit-module]

- **`nixploit.service`** is a oneshot running as the `nixploit` system user.
  A nushell script (`report.nu`) drives its steps, so nushell joins the
  closure. Each run updates the configured feeds into `/var/cache/nixploit`,
  then scans with `--system --config <toml>`. The last completed report is
  kept at `/var/lib/nixploit/report.json`. A failed update still scans against
  the cache, and a failed scan keeps the previous report.
- **`nixploit.timer`** fires on `calendar`, plus 2 min after activation, with
  `Persistent` and 15 min of jitter. A switch restarts it (and so rescans)
  only when its unit file changes: upstream's `X-Job` key covers the job
  config, and `rescanOnSwitch`'s `X-Packages` key covers the installed
  packages.
- **node_exporter** is force-enabled with the textfile collector reading
  `/var/lib/nixploit/metrics`. Its default listen address is `0.0.0.0:9100`.
  Nebula's host file pins it to loopback.
- **`kbuild.enable`** defaults on whenever the kernel exposes `configfile`. It
  builds a `linux-kbuild` derivation (every `Kbuild`/`Makefile` plus the
  `.config`, about 4 MiB) so the scanner can suppress CVEs whose fixes only
  touch files the config never compiles.

Exit codes: `0` means clean, `1` means unsuppressed `affected` findings, and
`2` means an error. `unknown` findings never change the exit code. Turning on
`providers = [ "nvd" "osv" ]` also makes `history.enable` default on. That
keeps commit-only clones of the upstream projects, so findings already fixed
on a release branch are suppressed.[^nixploit-readme]

Enabled on [nebula](../hosts/nebula.md) via
[nebula-nixploit](nebula-nixploit.md). Imported on every NixOS host but inert
until enabled (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)). The
re-export has the same shape as [codebase-memory-mcp](codebase-memory-mcp.md).
Auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/nixploit.nix`](../../modules/nixos/nixploit.nix)
- Options under: `services.nixploit`

[^nixploit-readme]: nixploit README (usage, configuration, NixOS module)
[^nixploit-module]: nixploit NixOS module source (services.nixploit.*)
[^subflake-readme]: flakes/nixploit/README.md (the report options)
