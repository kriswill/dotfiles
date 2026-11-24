# ai-usage on nix-darwin: the collector (pkgs/ai-usage) plus its daemon as a
# launchd user agent, writing ~/.cache/ai-usage/usage.json for `ai-usage` in a
# terminal and for the herdr-app mod (the macs run Herdr too, with the same
# stowed layout, so its panel waits on this agent). Accounts:
# ~/.config/ai-usage/config.json (the `ai-usage` stow package, deployed on
# both OSes); its claude account lists ~/.claude-me first, the personal
# profile the account selector uses here.
#
# Host-selective: flip `services.ai-usage.enable` in a host's default.nix.
# Claude's OAuth login is read from the keychain via /usr/bin/security (the
# first read may ask to allow it); the Admin key via Homebrew's `op`.
# NixOS twin: modules/nixos/ai-usage.nix.
{
  flake.modules.darwin.ai-usage =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.services.ai-usage = {
        enable = lib.mkEnableOption "the ai-usage AI account usage daemon";
        gcpBilling.enable = lib.mkEnableOption "the shared read-only Herdr GCP billing configuration";
      };

      config = lib.mkMerge [
        (lib.mkIf (config.services.ai-usage.enable || config.services.ai-usage.gcpBilling.enable) {
          environment.systemPackages = [ pkgs.ai-usage ];
        })
        (lib.mkIf config.services.ai-usage.gcpBilling.enable {
          sops.secrets = lib.genAttrs [ "ai-usage-gcp-config" "ai-usage-gcp-credentials" ] (_: {
            sopsFile = ../hosts/ai-usage-gcp.json;
            format = "json";
            owner = config.system.primaryUser;
            mode = "0400";
          });
        })
        (lib.mkIf config.services.ai-usage.enable {
          launchd.user.agents.ai-usage.serviceConfig = {
            ProgramArguments = [
              (lib.getExe pkgs.ai-usage)
              "daemon"
            ];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Background";
            ThrottleInterval = 30;
            EnvironmentVariables.PATH = "/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
            StandardOutPath = "/Users/${config.system.primaryUser}/Library/Logs/ai-usage.log";
            StandardErrorPath = "/Users/${config.system.primaryUser}/Library/Logs/ai-usage.log";
          };
        })
      ];
    };
}
