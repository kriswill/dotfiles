# slack-leave-devopsinc — leave the Slack devopsinc-N incident channels on
# demand: `slack-leave-devopsinc` on PATH, "Leave devopsinc Channels" in
# Spotlight. environment.systemPackages (not users.users.k.packages) because
# nix-darwin only copies systemPackages' Applications/ into
# /Applications/Nix Apps, where Spotlight indexes them.
# Derivation in pkgs/slack-leave-devopsinc.nix, exposed via its overlay.
{
  flake.modules.darwin.slack-leave-devopsinc =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.slack-leave-devopsinc ];
    };
}
