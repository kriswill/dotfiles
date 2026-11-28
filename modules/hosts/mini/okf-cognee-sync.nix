# One-way read-only mirror of committed knowledge/ OKF docs into Cognee's
# shared `dotfiles-knowledge` dataset on mini.
#
# Runs as a user LaunchAgent under k (every 30 min, Background/LowPriorityIO),
# reading the dedicated `dotfiles-sync` API key from ~/.config/cognee/keys/
# and dataset UUID from ~/.config/cognee/dotfiles-knowledge.id (or explicit
# --dataset-id). Exits 0 quietly when unconfigured or when git HEAD is unchanged.
{
  configurations.darwin.mini.module =
    { pkgs, ... }:
    let
      syncCli = pkgs.writeShellApplication {
        name = "okf-cognee-sync";
        runtimeInputs = [
          pkgs.bun
          pkgs.git
        ];
        text = ''
          exec bun ${./okf-cognee-sync.ts} "$@"
        '';
      };
    in
    {
      users.users.k.packages = [ syncCli ];

      launchd.user.agents.okf-cognee-sync = {
        command = "${syncCli}/bin/okf-cognee-sync --allow-missing-config";
        serviceConfig = {
          RunAtLoad = false;
          StartInterval = 1800;
          ProcessType = "Background";
          LowPriorityIO = true;
          StandardOutPath = "/Users/k/Library/Logs/okf-cognee-sync.log";
          StandardErrorPath = "/Users/k/Library/Logs/okf-cognee-sync.err.log";
        };
      };
    };
}
