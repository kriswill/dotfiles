{
  flake.modules.nixos.gnome-keyring =
    # Secret Service (org.freedesktop.secrets) provider. Added for
    # atuin-desktop (removed since): its Hub-connect "Accept" hung with no
    # Secret Service running. Kept because gh, Helium ("Chromium Safe
    # Storage") and Noctalia now store their keys in the login collection;
    # dropping it would strand those. ly's own NixOS module already sets
    # `security.pam.services.ly.enableGnomeKeyring = mkDefault
    # config.services.gnome.gnome-keyring.enable`, so enabling this alone is
    # enough — login auto-unlocks it, no separate PAM wiring needed here.
    {
      services.gnome.gnome-keyring.enable = true;
    };
}
