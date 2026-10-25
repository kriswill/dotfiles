{
  configurations.nixos.nebula.module = {
    # Battle.net in GE-Proton without Steam or umu (modules/nixos/battlenet.nix,
    # from ./flakes/battlenet): `battlenet` and a "Battle.net" desktop entry.
    # The prefix is the one umu-launcher used before it was dropped
    # (2026-10-25), which holds the WoW install. It keeps umu's layout: the
    # compat data directory is the Wine prefix itself, with a `pfx -> .` link
    # inside, so $prefix/pfx still resolves.
    programs.battlenet = {
      enable = true;
      prefix = ".local/share/Steam/steamapps/compatdata/3082075026/pfx";
      icon = "/home/k/Downloads/wow-icon.png";
    };
  };
}
