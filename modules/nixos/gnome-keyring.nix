{
  flake.modules.nixos.gnome-keyring =
    # Secret Service (org.freedesktop.secrets) provider. Nothing in this repo
    # needed one until atuin-desktop: its "Accept" on Hub-connect has no
    # try/catch around the keyring-save call, so with no Secret Service
    # running it fails silently and the dialog can never dismiss. ly's own
    # NixOS module already sets `security.pam.services.ly.enableGnomeKeyring
    # = mkDefault config.services.gnome.gnome-keyring.enable`, so enabling
    # this alone is enough — login auto-unlocks it, no separate PAM wiring
    # needed here.
    {
      services.gnome.gnome-keyring.enable = true;
    };
}
