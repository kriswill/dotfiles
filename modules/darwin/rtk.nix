# rtk — CLI proxy that filters dev command output (git, grep, cargo, npm,
# docker, aws, …) before it reaches an LLM's context. Derivation lives in
# pkgs/rtk.nix, exposed as pkgs.rtk via the rtk overlay.
{
  flake.modules.darwin.rtk =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.rtk ];
    };
}
