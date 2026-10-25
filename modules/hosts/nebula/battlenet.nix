{
  configurations.nixos.nebula.module = {
    # Battle.net in GE-Proton without Steam or umu (modules/nixos/battlenet.nix,
    # from ./flakes/battlenet): `battlenet` and a "Battle.net" desktop entry.
    # It shares the prefix of the stowed umu entry ("Battle.net (umu)") so the
    # WoW install is shared. That prefix has umu's layout: the compat data
    # directory is the Wine prefix itself, with a `pfx -> .` link inside.
    # Alternating the two entries flips pfx/version between Valve's 11.0-100
    # and GE-Proton11-11; Proton upgrades the prefix in place either way.
    programs.battlenet = {
      enable = true;
      prefix = ".local/share/Steam/steamapps/compatdata/3082075026/pfx";
      icon = "/home/k/Downloads/wow-icon.png";
    };
  };
}
