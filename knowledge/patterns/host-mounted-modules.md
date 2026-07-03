---
type: Pattern
title: Host-Mounted Modules
description: Universal features are ungated deferred modules in flake.modules.darwin.*; host-selective features gate behind programs./services. enable options flipped in modules/hosts/<hostname>/default.nix; truly host-specific files live beside the host's default.nix.
resource: modules/darwin/podman-desktop.nix
tags: [nix, module, convention]
timestamp: '2026-07-03T00:00:00-07:00'
---

Feature selection is expressed at the host, not scattered through a fan-out of
defaults (this replaced the old `kriswill.<feature>.enable` gating driven by
`core.nix`; see the [decision record](../decisions/remove-option-gating.md)).
All feature modules live under `modules/darwin/` in
`flake.modules.darwin.<name>`, and every host blanket-imports the whole set
with `builtins.attrValues config.flake.modules.darwin`. Hosts are folders —
`modules/hosts/<hostname>/default.nix`, exact hostname, definable as darwin or
(after the `nebula-snowglobe` merge) nixos.

Three tiers:

- **Universal** (every darwin host): a plain deferred module, no enable
  option, no `lib.mkIf` gate — the blanket import turns it on everywhere.
  [tmux](../modules/tmux.md) is the reference shape. A behavior *setting* is
  fine ([direnv-nom](../modules/direnv-nom.md)'s `programs.direnv-nom.diff`);
  only gating is out.

```nix
{
  flake.modules.darwin.<name> =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.<name> ];
    };
}
```

- **Host-selective**: same location, but the config gates behind a single
  enable option that wanting hosts flip in their `default.nix` — namespace
  `programs.<name>.*` for user-facing programs
  ([podman-desktop](../modules/podman-desktop.md),
  [claude-account-selector](../modules/claude-account-selector.md)),
  `services.<name>.*` for daemons and sub-flake re-exports
  ([apple-container](../modules/apple-container.md),
  [codebase-memory-mcp](../modules/codebase-memory-mcp.md) — their options
  ship inside the sub-flakes' darwin modules). Never a personal namespace.

```nix
{
  flake.modules.darwin.<name> =
    { lib, config, ... }:
    {
      options.programs.<name>.enable = lib.mkEnableOption "<name>";
      config = lib.mkIf config.programs.<name>.enable { ... };
    };
}
```

- **Host-specific**: config that only ever applies to one machine (fixed IPs,
  hardware quirks) skips `modules/darwin/` entirely — it's a file beside that
  host's `default.nix` merging straight into
  `configurations.darwin.<hostname>.module`
  ([alias-en0](../modules/alias-en0.md) in `modules/hosts/SOC-Kris-Williams/`).

Conventions:

- **Overriding a universal module from a host:** override-prone scalars
  (dnsmasq's enable/bind/addresses, homebrew's enable/onActivation,
  macos-defaults, neovim's EDITOR/VISUAL/MANPAGER, oksh's ENV, zsh's history
  settings) carry `lib.mkDefault`, so a host `default.nix` can override them
  with a plain assignment. Anything else is set at normal module priority —
  overriding it needs `lib.mkForce` (a bare conflicting value is a hard eval
  error).
- Package lists use `builtins.attrValues { inherit (pkgs) ...; }`.
- One bare `<name>.nix` per feature; a directory only when the module bundles
  adjacent files ([claude-account-selector](../modules/claude-account-selector.md),
  [yazi](../modules/yazi.md)).

Discovery is automatic per the [Dendritic module layout](dendritic-modules.md);
the steps are codified in the [add-module playbook](../playbooks/add-module.md).
