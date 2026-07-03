---
type: Pattern
title: Host-Mounted Modules
description: Universal features are ungated deferred modules in flake.modules.<class>.* (darwin + nixos classes); host-selective features gate behind programs./services. enable options flipped in modules/hosts/<hostname>/default.nix; truly host-specific files live beside the host's registration.
resource: modules/darwin/podman-desktop.nix
tags: [nix, module, convention]
timestamp: '2026-07-03T12:00:00-07:00'
---

Feature selection is expressed at the host, not scattered through a fan-out of
defaults (this replaced the old `kriswill.<feature>.enable` gating driven by
`core.nix`; see the [decision record](../decisions/remove-option-gating.md)).
All feature modules live under `modules/<class>/` (`darwin/`, `nixos/`) in
`flake.modules.<class>.<name>`, and every host blanket-imports its whole class
with `builtins.attrValues config.flake.modules.<class>`. Darwin hosts are
folders — `modules/hosts/<hostname>/default.nix`, exact hostname; the NixOS
host is a registry entry (`modules/hosts/nebula.nix`, hardware metadata
inside) plus a sibling `nebula/` folder of host files — see
[host registry realisers](host-registry-realisers.md). A feature shared by
both OSes is a twin pair, one module per class dir
([cross-OS module twins](cross-os-module-twins.md)).

Three tiers:

- **Universal** (every host of the class): a plain deferred module, no enable
  option, no `lib.mkIf` gate — the blanket import turns it on everywhere.
  [tmux](../modules/tmux.md) is the reference shape. A behavior *setting* is
  fine ([direnv-nom](../modules/direnv-nom.md)'s `programs.direnv-nom.diff`);
  only gating is out. The nixos class is currently all-universal — with a
  single Linux host every `flake.modules.nixos.*` is ungated; retrofit gates
  when a second NixOS host appears (per the
  [unification decision](../decisions/nixos-darwin-unification.md)).

```nix
{
  flake.modules.<class>.<name> =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.<name> ];
    };
}
```

- **Host-selective** (darwin-only today, for the reason above): same location,
  but the config gates behind a single
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
  hardware quirks) skips the class dirs entirely — it's a file beside that
  host's registration merging straight into
  `configurations.<class>.<hostname>.module`
  ([alias-en0](../modules/alias-en0.md) in `modules/hosts/SOC-Kris-Williams/`;
  nebula's [windows-mount](../modules/windows-mount.md) and
  [console-quiet](../modules/console-quiet.md) in `modules/hosts/nebula/`).

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
