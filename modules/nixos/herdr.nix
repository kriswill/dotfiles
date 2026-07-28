{
  flake.modules.nixos.herdr =
    # herdr — agent multiplexer that lives in your terminal (from nixpkgs).
    # Darwin twin: the herdr entry in modules/darwin/user-packages.nix.
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.herdr ];
    };
}
