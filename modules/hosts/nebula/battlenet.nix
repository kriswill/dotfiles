{
  configurations.nixos.nebula.module = {
    # Battle.net in GE-Proton without Steam or umu (modules/nixos/battlenet.nix,
    # from ./flakes/battlenet): `battlenet` and a "Battle.net" desktop entry.
    # The prefix is the module's default, ~/.local/share/battlenet. It moved
    # there from Steam's compatdata/3082075026 on 2026-10-25, so Steam can't
    # touch it (see knowledge/modules/nebula-battlenet.md).
    programs.battlenet = {
      enable = true;
      icon = "/home/k/Downloads/wow-icon.png";
    };
  };
}
