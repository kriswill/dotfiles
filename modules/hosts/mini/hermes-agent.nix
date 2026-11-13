# Hermes Agent on mini: the sub-flake's nix-darwin module (re-exported by
# modules/darwin/hermes-agent.nix). The gateway (cron, memory, messaging
# platforms; none configured) is a launchd user agent running as k, and the
# wrapped `hermes` CLI on PATH shares its HERMES_HOME
# (~/.hermes-agent/.hermes).
#
# Direct access remains confined to the system, agent state, private TMPDIR,
# and opted-in ~/src checkouts. Socket exceptions below grant desktop-driver
# access and FULL Herdr core access. The latter intentionally allows commands
# outside Seatbelt and interaction with local/remote agent sessions; this is
# not an end-to-end confinement boundary once hc is connected.
# Started outside readable paths, Hermes uses ~/.hermes-agent/workspace.
#
# The model provider is OpenAI through the ChatGPT/Codex login, as on nebula:
# `hermes auth add openai-codex` (device code) once on the machine, then
# `/model ... --global`. That is an OAuth session whose refresh token rotates,
# so it lives in $HERMES_HOME/auth.json, not in sops.
#
# API keys, when one is wanted, come from sops: the `hermes-env` secret in
# ./hermes-secrets.yaml holds KEY=value lines (ANTHROPIC_API_KEY=sk-...),
# sourced from 1Password. sops-nix decrypts it root-only under /run/secrets, which the
# sandbox cannot read; activation (root) copies it into $HERMES_HOME/.env.
# The file is separate from ./secrets.yaml so it can be rewritten with only
# mini's public recipient (the command is in
# knowledge/modules/mini-hermes-agent.md). Until it is committed the secret
# is not declared, so the host still builds, and Hermes runs without a key.
let
  sopsFile = ./hermes-secrets.yaml;
  haveSecrets = builtins.pathExists sopsFile;
in
{
  configurations.darwin.mini.module =
    { config, lib, ... }:
    {
      imports = [ ../../../flakes/hermes-agent/nix/cua-calculator-module.nix ];

      sops.secrets = lib.mkIf haveSecrets {
        hermes-env = { inherit sopsFile; };
      };

      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        # Idle/working/blocked status in the Herdr app's Agents list.
        herdr.enable = true;
        # Official signed immutable bundle + reviewed manual user-side launcher.
        # No startup/approval assertion is performed by activation or Hermes.
        cuaCalculator.enable = true;
        # Every checkout under ~/src, read and write. That includes this
        # repo, which `nrs` builds and activates as root: review what the
        # agent changed here before rebuilding.
        sandbox.readWritePaths = [ "/Users/k/src" ];
        # Explicit desktop-control boundary: connect to the user-launched
        # Calculator-only CuaDriver without enabling LaunchServices or Apple events.
        # This grants access to the daemon, not merely a filesystem path;
        # keep its authorization policy enabled. No GUI auto-start here.
        sandbox.unixSockets = [
          # The helper grants only its dedicated hermes-cua-calculator/driver.sock;
          # the unrestricted/default CuaDriver endpoint is deliberately absent.
          # Full access to the existing desktop core: deliberately permits
          # unsandboxed commands, other terminals, and configured machines.
          "/Users/k/.local/state/herdr-core/default/default.sock"
        ];
        # Shared environment is loaded by both the CLI and launchd gateway.
        # HOME stays confined; hc must not discover a separate core there.
        # The desktop app owns core startup; no new launchd service is added.
        environment.HC_SOCKET = "/Users/k/.local/state/herdr-core/default/default.sock";
        environmentFiles = lib.optional haveSecrets config.sops.secrets.hermes-env.path;
        # Model selection belongs to Hermes (/model, including --global); see
        # nebula's file for why it is not declared here.

        # The passive startup check reports a bogus "Update available" on
        # every Nix build (it compares the pinned tag with main's tip).
        # Updates come from bumping ./flakes/hermes-agent.
        settings.updates.check = false;
      };
    };
}
