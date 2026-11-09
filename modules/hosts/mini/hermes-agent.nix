# Hermes Agent on mini: the sub-flake's nix-darwin module (re-exported by
# modules/darwin/hermes-agent.nix). The gateway (cron, memory, messaging
# platforms; none configured) is a launchd user agent running as k, and the
# wrapped `hermes` CLI on PATH shares its HERMES_HOME
# (~/.hermes-agent/.hermes).
#
# Both run inside the module's Seatbelt sandbox (on by default): the agent
# reads the system but nothing in /Users/k outside ~/.hermes-agent, writes
# only there and in a private TMPDIR, and cannot reach the keychain, launchd,
# other applications or other programs' sockets (tmux, herdr, the ssh and
# git-signing agents). To let it work on a project, list the checkout in
# `sandbox.readWritePaths`; nothing is listed, so it works in
# ~/.hermes-agent/workspace.
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
      sops.secrets = lib.mkIf haveSecrets {
        hermes-env = { inherit sopsFile; };
      };

      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        # Idle/working/blocked status in the Herdr app's Agents list.
        herdr.enable = true;
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
