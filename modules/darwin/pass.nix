{
  flake.modules.darwin.pass =
    # Installs `pass` (the standard unix password manager) as the pass-xdg
    # wrapper from pkgs/pass-xdg.nix (exposed as pkgs.pass-xdg via its overlay)
    # — the darwin twin of modules/nixos/pass.nix. The wrapper is itself named
    # `pass`, so it shadows the plain binary on PATH and defaults
    # PASSWORD_STORE_DIR to $XDG_DATA_HOME/password-store
    # (~/.local/share/password-store). Don't also add pkgs.pass here or the two
    # `pass` binaries collide in the system profile. Decryption is backed by
    # gpg-agent (modules/darwin/gpg.nix).
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.pass-xdg ];
    };
}
