---
type: Sub-flake
title: nixploit
description: 'Sub-flake wrapping the manic-systems/nixploit vulnerability scanner for NixOS: re-exports its package and module and adds services.nixploit.report (an HTML viewer rendered after every scan, which explains why each vulnerable package is installed and what to do about it, plus the users who can read it); enabled on nebula.'
resource: flakes/nixploit/
tags: [sub-flake, package]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T12:00:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/nixploit/README.md
    title: 'flakes/nixploit/README.md (outputs, module options, report step, consumption)'
  - id: nixploit-readme
    resource: https://github.com/manic-systems/nixploit
    title: 'nixploit README (usage, configuration, NixOS module)'
---

The scanner itself is upstream's. The sub-flake pins it as the `upstream`
input in its own `flake.lock` (following the sub-flake's nixpkgs, and through
it the root's) and adds the report step. It exposes:[^subflake-readme]

- `packages.<system>.{nixploit, nixploit-report, nixploit-report-graph}`, for
  `x86_64-linux` and `aarch64-linux` (`default` is `nixploit`). The root
  re-exports the first two in `modules/packages.nix`.
- `nixosModules.{nixploit, default}`. This imports upstream's module and adds
  `services.nixploit.report.enable` and `services.nixploit.report.readers`.
  The root re-exports it as the [nixploit module](../modules/nixploit.md).

The two options:

- **`report.readers`** joins users to the `nixploit` group and runs
  `chmod g+r` on `report.json` after every run, because upstream creates it
  `0600`.
- **`report.enable`** runs `nixploit-report` after every run. It renders
  `/var/lib/nixploit/report.html` (`0640`): the standalone viewer
  `report.html` with the report embedded.

The data is embedded because browsers block `fetch()` from `file://` pages.
Every `<` in the embedded JSON is escaped as `\u003c`, so advisory text can't
close the script tag. Opened alone, the viewer takes a `report.json` by file
picker or drag-and-drop, without the dependency analysis.

Both options add `ExecStopPost` entries as lists, which merge with upstream's
single-string `report.nu finish`, so every entry runs. Builds from source,
because upstream has no binary cache.[^nixploit-readme]

The viewer shows:

- summary cards;
- affected/unknown/suppressed tabs;
- severity and known-exploited filters;
- one row per package/version/vulnerability (collapsing the same finding
  across derivations, and skipping the duplicate output-less derivers nixploit
  emits);
- a per-package view;
- per-finding evidence, with a copyable `services.nixploit.settings.ignore`
  entry.

Its "fixed in" column re-derives nixploit's `fixed_in` from the serialized
claims.

`nixploit-report-graph` runs as the service user and adds about 300 KB:
the running system's reference graph (`nix path-info --recursive --json`) and
which system generations hold each path. It's a separate program, so if it
fails the page still renders, just without the analysis. From the graph, the
page derives for every vulnerable build:

- **Who pulls it in**: `system-path` children, units (a non-unit child of
  `system-units` comes from `systemd.packages`), `etc` entries, and toplevel
  references. Restart-trigger nodes are skipped, because they reference
  everything.
- **Which package owns it**: the outermost dominator, or a consumer every
  other consumer depends on.
- **The shortest route** from the system.
- **Whether a fixed copy** of the same package is already installed.
- **Which generations keep it.**

These drive rule-based "What to do" and "When it runs" advice and a Causes
view. Exploitability is still the reader's call. Dev shells aren't covered,
because they're outside the `--system` scan.

Enabled on [nebula](../hosts/nebula.md) via
[nebula-nixploit](../modules/nebula-nixploit.md). Consumed by the root flake
as a relative-path input; see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). The
module-carrying shape matches [apple-container](apple-container.md).

## Source

- Flake: [`flakes/nixploit/`](../../flakes/nixploit/)
- README: [`flakes/nixploit/README.md`](../../flakes/nixploit/README.md)

[^subflake-readme]: flakes/nixploit/README.md (outputs, module options, report step, consumption)
[^nixploit-readme]: nixploit README (usage, configuration, NixOS module)
