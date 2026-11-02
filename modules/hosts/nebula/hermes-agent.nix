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
    { config, pkgs, ... }:
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
        # CODEX_HOME feeds explicit Codex CLI login import/recovery; it does
        # not auto-register a provider. `hermes auth add openai-codex` creates
        # an independent session and avoids sharing rotating refresh tokens.
        environment.CODEX_HOME = "/home/k/.codex";
        # Model selection belongs to Hermes (/model, including --global).
        # Do not partially override model here: activation would keep stale
        # base_url/api_mode fields from a different runtime-selected provider.

        # extraPackages reaches both the gateway and k's login-shell PATH.
        # The package wrapper's PATH alone does not reach terminal tools.
        extraPackages = [
          pkgs.ffmpeg
          pkgs.nixd
        ];
        settings.lsp.servers.nixd.command = [ "${pkgs.nixd}/bin/nixd" ];
        # The passive startup check reports a bogus "Update available" on every
        # Nix build: a store path has no git origin, so default_channel() falls
        # back to `main` (not `stable`) and compares the pinned tag against
        # main's moving tip. Updates come from bumping ./flakes/hermes-agent.
        settings.updates.check = false;
      };
    };
}
