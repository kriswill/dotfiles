---
type: Pattern
title: Host-Mounted Modules
description: A module mounted into a host is active — no enable options, no lib.mkIf gating; universal features live in flake.modules.darwin.*, host-selective ones mount directly into configurations.darwin.<host>.module.
resource: modules/hosts/podman-desktop.nix
tags: [nix, module, convention]
timestamp: '2026-07-03T00:00:00-07:00'
---

Being mounted is what turns a feature on. No feature module declares an
`enable` option or wraps its config in `lib.mkIf` — the selection happens
entirely through *where the module is mounted* (this replaced the old
`kriswill.<feature>.enable` gating; see the
[decision record](../decisions/remove-option-gating.md)). The arrangement
deliberately mirrors the NixOS config on the `nebula-snowglobe` branch so the
two merge cleanly later.

Two mounting tiers:

- **Universal** (every darwin host): a plain deferred module in
  `flake.modules.darwin.<name>` under `modules/darwin/` —
  [tmux](../modules/tmux.md) is the reference shape. Hosts blanket-import the
  whole set with `builtins.attrValues config.flake.modules.darwin`.

```nix
{
  flake.modules.darwin.<name> =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.<name> ];
    };
}
```

- **Host-selective**: a dendritic file under `modules/hosts/` that merges the
  feature straight into `configurations.darwin.<host>.module` (deferredModule
  definitions merge, so many files can extend one host). One file can mount a
  shared module into several hosts — [podman-desktop](../modules/podman-desktop.md)
  mounts into k + SOC; single-host features live in `modules/hosts/<host>/`
  ([claude-account-selector](../modules/claude-account-selector.md)).

```nix
let
  <name> = { ... };   # the feature module
in
{
  configurations.darwin.k.module = <name>;
  configurations.darwin.SOC-Kris-Williams.module = <name>;
}
```

Conventions:

- Options exist only where genuinely parameterized module APIs live — the
  sub-flakes' `services.apple-container.*` / `services.codebase-memory-mcp.*`
  (idiomatic for modules consumed by other repos); their mount files set
  `enable = true` at the mount site.
- Package lists use `builtins.attrValues { inherit (pkgs) ...; }`.
- One bare `<name>.nix` per feature; a directory only when the module bundles
  adjacent files ([claude-account-selector](../modules/claude-account-selector.md),
  [yazi](../modules/yazi.md)).

Discovery is automatic per the [Dendritic module layout](dendritic-modules.md);
the steps are codified in the [add-module playbook](../playbooks/add-module.md).
