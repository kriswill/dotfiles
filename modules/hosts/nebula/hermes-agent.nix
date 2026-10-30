# Hermes Agent on nebula: the sub-flake's NixOS module (re-exported by
# modules/nixos/hermes-agent.nix), with the gateway (cron, memory, messaging
# platforms; none configured) running as k out of /var/lib/hermes. The
# wrapped `hermes` CLI on PATH (addToSystemPackages) uses that same
# HERMES_HOME, so k's interactive sessions share the gateway's sessions,
# skills and memory instead of starting a separate ~/.hermes.
#
# The service runs as k because hermes is single-owner by design (see the
# module's header): a separate service user's home can't be shared with k's
# CLI, and a separate service user can't see k's projects. The unit stays
# ProtectSystem=strict (writes only under /var/lib/hermes); it reads with
# k's access. The module's `hermes` group has no members, so the state dir
# and its 0640 .env stay off the shared `users` group.
#
# config.yaml is rendered from `settings` and deep-merged on every activation:
# keys set here win, keys hermes or the agent add at runtime survive. The CLI's
# config-mutating commands (`hermes setup`, `hermes config set`, `hermes
# gateway install`) refuse to run under the module; change settings here.
#
# The Anthropic key lives in the `hermes-env` sops secret as KEY=value lines
# (ANTHROPIC_API_KEY=sk-ant-...). Activation (root) merges it into
# $HERMES_HOME/.env, so the secret itself stays root-only. sops-nix validates
# declared keys at build time, so the key must exist before a rebuild.
{
  configurations.nixos.nebula.module =
    { config, ... }:
    {
      sops.secrets.hermes-env = { };

      services.hermes-agent = {
        enable = true;
        user = "k";
        addToSystemPackages = true;
        # herdr's Hermes integration: reports the session id to the herdr pane
        # so herdr can resume Hermes sessions.
        herdr.enable = true;
        environmentFiles = [ config.sops.secrets.hermes-env.path ];
        settings.model = {
          provider = "anthropic";
          default = "claude-opus-5-5";
        };
      };
    };
}
