---
type: Pattern
title: Module Option Pattern
description: Feature modules expose kriswill.<feature>.enable (or programs.<name> via mkProgramOption) and gate all config behind lib.mkIf.
resource: modules/darwin/nh.nix
tags: [nix, module, convention]
timestamp: '2026-07-02T00:00:00-07:00'
---

Every darwin feature module has the same shape: wrap the body in
`flake.modules.darwin.<name>`, declare an enable option, and gate `config`
behind `lib.mkIf`. Hosts then compose features declaratively by flipping
options — see [k](../hosts/k.md).

```nix
{
  flake.modules.darwin.<name> =
    { lib, pkgs, config, ... }:
    {
      options.kriswill.<name>.enable = lib.mkEnableOption "<name>";
      config = lib.mkIf config.kriswill.<name>.enable { ... };
    };
}
```

Conventions:

- Option namespace is `kriswill.<feature>.*`; program-shaped modules use the
  custom `lib.mkProgramOption` helper instead, which generates a
  `programs.<name>` option set with `enable` + `package`
  ([nh](../modules/nh.md) is the canonical reference module).
- `mkProgramOption` and `kanagawa` live in `lib/default.nix`, merged onto
  `nixpkgs.lib` by the [lib](../modules/lib.md) plumbing module — modules call
  them as `lib.mkProgramOption`.
- Package lists use `builtins.attrValues { inherit (pkgs) ...; }`.
- One bare `<name>.nix` per feature; a directory only when the module bundles
  adjacent files ([claude-account-selector](../modules/claude-account-selector.md),
  [yazi](../modules/yazi.md)).

Discovery is automatic per the [Dendritic module layout](dendritic-modules.md);
the steps are codified in the [add-module playbook](../playbooks/add-module.md).
