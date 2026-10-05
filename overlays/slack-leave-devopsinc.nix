# slack-leave-devopsinc — leave the Slack devopsinc-N incident channels (CLI +
# Spotlight app). macOS-only, but this only ADDS a lazy attr nixos never
# evaluates. See pkgs/slack-leave-devopsinc.nix.
_final: prev: {
  slack-leave-devopsinc = prev.callPackage ../pkgs/slack-leave-devopsinc.nix { };
}
