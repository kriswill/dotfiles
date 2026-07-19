{
  flake.modules.nixos.atuin-desktop =
    # atuin-desktop — Tauri GUI companion to the atuin CLI (see zsh.nix):
    # local-first, executable runbook editor. Ships its own .desktop entry
    # and icons, so systemPackages alone is enough for launchers to see it.
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.atuin-desktop ];
    };
}
