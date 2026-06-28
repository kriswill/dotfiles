{
  flake.modules.nixos.gtk-dark =
    # Force GTK apps to use Adwaita's dark variant.
    #
    # A bare wlroots/Hyprland session has no settings daemon broadcasting a
    # `color-scheme = prefer-dark` preference, so GTK apps (LibreOffice's gtk3 VCL
    # plugin included) default to light and override any in-app "Dark" theme back to
    # light. The `gtk-application-prefer-dark-theme` hint alone is ignored here
    # because no separate Adwaita-dark theme directory is installed for it to resolve
    # to. Explicitly selecting the `:dark` variant — compiled into GTK itself — is
    # the reliable lever and makes the whole GTK app stack render dark.
    #
    # Set as a session variable so it's inherited by the entire graphical session
    # regardless of how an app is launched. Requires a re-login to take effect.
    {
      environment.sessionVariables.GTK_THEME = "Adwaita:dark";
    }

  ;
}
