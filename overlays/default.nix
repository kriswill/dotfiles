{ inputs, ... }:
{
  claude-code = import ./claude-code.nix;
  nh = inputs.nh.overlays.default;
  # kitty = import ./kitty.nix;
  gh-actions-language-server = final: prev: {
    gh-actions-language-server = final.callPackage ../pkgs/gh-actions-language-server { };
  };
}
