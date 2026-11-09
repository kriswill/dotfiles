# nix/hermesCli.nix — the `hermes` CLI the modules install, and the Herdr
# integration that rides on it.
#
# Ours: not an upstream file. Both system modules (nixosModules.nix,
# darwinModules.nix) install the same thing, so it is built once here:
#
#   - Every binary of the package defaults HERMES_HOME (--set-default, so an
#     explicit value still wins). Without it the CLI silently creates and uses
#     an unmanaged ~/.hermes.
#   - With `launcher` (the macOS sandbox, darwinSandbox.nix) every binary
#     starts through it, so the CLI and what it spawns are confined exactly
#     like the gateway.
#   - With `herdr`, `hermes` is ./herdr/cli.ts in front of that: it marks the
#     pane for the gateway's shell hook and reports idle/clear to a Herdr app
#     pane itself. The hook (./herdr/hook.ts) maps a session to the pane's
#     pty through the CLI's terminal breadcrumbs and the marker, then writes
#     OSC 7501 to the pty (Herdr app) or runs `herdr pane
#     report-agent-session` (Herdr TUI). Both are TypeScript on bun, not a
#     Hermes plugin: those are Python, loaded into the gateway, which never
#     sees the pane.
{ lib, pkgs }:
{
  # The package the service runs, so a CLI session and the gateway are always
  # the same build.
  package,
  hermesHome,
  herdr ? false,
  # A program that runs its arguments confined, or null.
  launcher ? null,
}:
let
  # The check transpiles both, so a syntax error fails the build.
  herdrScripts = pkgs.runCommandLocal "hermes-herdr-scripts" { nativeBuildInputs = [ pkgs.bun ]; } ''
    cp -r ${./herdr} $out
    HOME=$TMPDIR bun build --target=bun --outdir $TMPDIR/check $out/cli.ts $out/hook.ts >/dev/null
  '';
  herdrHook = pkgs.writeShellScript "hermes-herdr-hook" ''
    exec ${lib.getExe pkgs.bun} ${herdrScripts}/hook.ts
  '';
  herdrHookEvents = [
    "on_session_start"
    "on_session_reset"
    "pre_llm_call"
    "post_llm_call"
    "agent_loop_stopped"
    "on_human_input_request"
    "on_human_input_resolved"
  ];

  cli = pkgs.symlinkJoin {
    name = "hermes-agent-cli";
    paths = [ package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild =
      (
        if launcher == null then
          ''
            for bin in $out/bin/*; do
              wrapProgram "$bin" --set-default HERMES_HOME ${hermesHome}
            done
          ''
        else
          ''
            for bin in $out/bin/*; do
              name=$(basename "$bin")
              rm "$bin"
              makeWrapper ${launcher} "$bin" \
                --set-default HERMES_HOME ${hermesHome} \
                --add-flags ${package}/bin/$name
            done
          ''
      )
      + lib.optionalString herdr ''
        mv $out/bin/hermes $out/bin/.hermes-herdr
        makeWrapper ${lib.getExe pkgs.bun} $out/bin/hermes \
          --set-default HERMES_HOME ${hermesHome} \
          --set HERMES_HERDR_REAL $out/bin/.hermes-herdr \
          --add-flags ${herdrScripts}/cli.ts
      '';
  };

  # Shell hooks run only once consented (shell-hooks-allowlist.json, by
  # (event, command)). Approve exactly ours, and drop approvals of earlier
  # builds' hooks. The gateway rereads it within ~30 s. Also removes the
  # Python plugin this replaced.
  herdrActivation =
    { owner }:
    let
      pluginLink = "${hermesHome}/plugins/herdr-agent-state";
    in
    ''
      allow=${hermesHome}/shell-hooks-allowlist.json
      [ -s "$allow" ] || echo '{"approvals": []}' > "$allow"
      ${lib.getExe pkgs.jq} \
        --arg cmd ${herdrHook} \
        --argjson events '${builtins.toJSON herdrHookEvents}' \
        --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.approvals = ([.approvals[] | select((.command // "") | test("-hermes-herdr-hook$") | not)]
          + [$events[] | {event: ., command: $cmd, approved_at: $now,
                          script_mtime_at_approval: "1970-01-01T00:00:01Z"}])' \
        "$allow" > "$allow.tmp"
      mv "$allow.tmp" "$allow"
      chown ${owner} "$allow"
      chmod 0600 "$allow"

      if [ -L ${pluginLink} ] && [[ "$(readlink ${pluginLink})" == /nix/store/* ]]; then
        rm ${pluginLink}
      fi
    '';

  # `settings.hooks` for the turn events.
  herdrHooks = lib.genAttrs herdrHookEvents (_: [
    {
      command = "${herdrHook}";
      timeout = 5;
    }
  ]);
in
{
  inherit
    cli
    herdrActivation
    herdrHook
    herdrHooks
    ;
}
