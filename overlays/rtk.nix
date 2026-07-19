# rtk — CLI proxy that filters dev command output to cut LLM token usage.
# See pkgs/rtk.nix.
_final: prev: {
  rtk = prev.callPackage ../pkgs/rtk.nix { };
}
