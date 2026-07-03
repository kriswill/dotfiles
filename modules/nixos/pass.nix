{
  flake.modules.nixos.pass =
    # Installs `pass` (the standard unix password manager) as the pass-xdg
    # wrapper from pkgs/pass-xdg.nix (exposed as pkgs.pass-xdg via its
    # overlay). The wrapper is itself named `pass`, so it shadows the
    # plain binary on PATH and defaults PASSWORD_STORE_DIR to
    # $XDG_DATA_HOME/password-store (~/.local/share/password-store) — see that
    # file for the fallback logic. Don't also add pkgs.pass here or the two
    # `pass` binaries collide in the system profile.
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.pass-xdg ];
    };
}
