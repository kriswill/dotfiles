# Determinate Nix owns /etc/nix/nix.conf on every darwin host (installed by
# the Determinate installer; nix-darwin's own nix management is off in
# core.nix). Its nix-darwin module lets the custom settings that land in
# /etc/nix/nix.custom.conf be declared here instead of hand-edited — other
# modules add to `determinateNix.customSettings` the way nixos modules add to
# `nix.settings` (e.g. devenv.nix's upstream caches). Twin of
# modules/nixos/determinate.nix.
#
# The installer had written nix.custom.conf itself (lazy-trees +
# download-buffer-size); those two are reproduced below so nothing is lost,
# and its sha256 is registered so nix-darwin agrees to take the file over.
# Universal.
{ inputs, ... }:
{
  flake.modules.darwin.determinate = {
    imports = [ inputs.determinate.darwinModules.default ];

    determinateNix.customSettings = {
      lazy-trees = true;
      download-buffer-size = 524288000; # 500MB
    };

    environment.etc."nix/nix.custom.conf".knownSha256Hashes = [
      # nix-installer's original file
      "ef6dd315c097a0937df8c20e45c6868114e2718ae994f49f9e35c266c510b21f"
    ];
  };
}
