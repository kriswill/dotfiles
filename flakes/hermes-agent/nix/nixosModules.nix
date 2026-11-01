# nix/nixosModules.nix — the NixOS module for hermes-agent
#
# Ours: upstream's NixOS module, made single-owner. Hermes allows one owner
# per HERMES_HOME. Saving a credential chmods it to 0700 even in managed mode,
# state.db, auth.json and the locks are forced to 0600, the gateway lock and
# control socket refuse files another uid owns, and the gateway refuses
# sessions whose cwd it can't see. Upstream's default, a `hermes` system user
# whose home interactive users share through a 2770 group, can't work for a
# CLI user. The changes against upstream:
#
#   - `user` is the account that runs the gateway and the CLI. It has no
#     default, and the module never creates it (no createUser, no linger).
#     `group` is created with no members, which keeps HERMES_HOME and its
#     0640 .env off the user's shared primary group.
#   - Directories are 2750, not 2770, and activation adds no group write to
#     files. The CLI refuses a group-writable HERMES_HOME
#     (`unsafe_control_permissions`) unless the group is the owner's private
#     group.
#   - addToSystemPackages installs a wrapped CLI that defaults HERMES_HOME
#     (--set-default, so an explicit value still wins). environment.variables
#     alone reaches a shell only if it sources /etc/set-environment. Every
#     process under a running session inherits __NIXOS_SET_ENVIRONMENT_DONE=1
#     and skips it, and the CLI then silently creates and uses an unmanaged
#     ~/.hermes.
#   - herdr.enable adds a Herdr integration, for the Herdr TUI and the Herdr
#     app alike: a `hermes` CLI wrapper and a gateway shell hook, both
#     TypeScript on bun (nix/herdr).
#   - Container mode is gone, and with it stateDir/home.
#
# Usage:
#   services.hermes-agent = {
#     enable = true;
#     user = "alice";
#     addToSystemPackages = true;
#     settings.model.default = "anthropic/claude-sonnet-4";
#     environmentFiles = [ config.sops.secrets."hermes/env".path ];
#   };
#
{ inputs, ... }:
{
  flake.nixosModules.default =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:

    let
      cfg = config.services.hermes-agent;
      common = import ./moduleCommon.nix { inherit lib; };

      effectivePackage = common.effectivePackage cfg;
      hermes-agent = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.default;

      hermesHome = "${cfg.stateDir}/.hermes";

      # The CLI that addToSystemPackages installs. It wraps effectivePackage,
      # the package the unit runs, so a CLI session and the gateway always
      # run the same build.
      hermesCli = pkgs.symlinkJoin {
        name = "hermes-agent-cli";
        paths = [ effectivePackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for bin in $out/bin/*; do
            wrapProgram "$bin" --set-default HERMES_HOME ${hermesHome}
          done
        ''
        # With herdr.enable, `hermes` is ./herdr/cli.ts in front of the
        # wrapped CLI: it marks the pane for the hook and reports idle/clear
        # to a Herdr app pane itself.
        + lib.optionalString cfg.herdr.enable ''
          mv $out/bin/hermes $out/bin/.hermes-herdr
          makeWrapper ${lib.getExe pkgs.bun} $out/bin/hermes \
            --set-default HERMES_HOME ${hermesHome} \
            --set HERMES_HERDR_REAL $out/bin/.hermes-herdr \
            --add-flags ${herdrScripts}/cli.ts
        '';
      };

      # The Herdr integration, in TypeScript on bun (./herdr). Not a Hermes
      # plugin: those are Python, loaded into the gateway. Instead
      #   - cli.ts is the `hermes` CLI (above) in a Herdr pane: it leaves a
      #     marker naming the pane's pty, and in a Herdr app pane reports
      #     idle at launch and clears the status at exit;
      #   - hook.ts is a gateway shell hook (`hooks:`) for the turn events: it
      #     maps the session to the pty through the CLI's terminal
      #     breadcrumbs and the marker, then writes OSC 7501 to the pty
      #     (Herdr app) or runs `herdr pane report-agent-session` (Herdr TUI).
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
      # Where the plugin this replaced was linked; activation removes it.
      herdrPluginLink = "${hermesHome}/plugins/herdr-agent-state";

      # The hardening and the environment that the gateway unit and the
      # backend unit share.
      commonServiceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.workingDirectory;

        Restart = cfg.restart;
        RestartSec = cfg.restartSec;

        # Upstream's value, which made new files group-writable for a
        # shared group. Here the group has no members, so its bits grant
        # nothing.
        UMask = "0007";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [
          cfg.stateDir
          cfg.workingDirectory
        ];
        PrivateTmp = true;
      };

      commonUnitEnvironment = {
        HOME = cfg.stateDir;
      }
      // common.processEnvironment { inherit hermesHome; };

      unitPath = common.processPath { inherit pkgs cfg; };

      # Whether the service uid gets a systemd user manager, and with it the
      # user bus that restart-safe cron workers need. Read back off `config`
      # rather than assumed: the module does not set linger for `user`.
      lingerEnabled = ((config.users.users.${cfg.user} or { }).linger or false) == true;

    in
    {
      options.services.hermes-agent =
        common.sharedOptions {
          defaultPackage = hermes-agent;
          defaultPackageText = lib.literalExpression "hermes-agent.packages.\${system}.default";
          defaultWorkingDirectory = "${cfg.stateDir}/workspace";
          defaultWorkingDirectoryText = lib.literalExpression ''"''${cfg.stateDir}/workspace"'';
        }
        // (with lib; {
          # ── Service identity ───────────────────────────────────────────
          user = mkOption {
            type = types.str;
            example = "alice";
            description = ''
              The existing account that runs the gateway and owns
              HERMES_HOME. Hermes allows one owner per HERMES_HOME, so
              this is also the account whose CLI shares it. The module
              does not create the account.
            '';
          };

          group = mkOption {
            type = types.str;
            default = "hermes";
            description = ''
              The group of the gateway and of the state files. The module
              creates it. Leave it without members: it keeps the state,
              .env included, off the user's primary group.
            '';
          };

          # ── Directories ────────────────────────────────────────────────
          stateDir = mkOption {
            type = types.str;
            default = "/var/lib/hermes";
            description = "State directory. Contains .hermes/ subdir (HERMES_HOME).";
          };

          addToSystemPackages = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Add the hermes CLI to environment.systemPackages, wrapped to
              default HERMES_HOME to the service's, and export HERMES_HOME
              system-wide (via environment.variables), so interactive
              shells share state with the gateway service.
            '';
          };

          # ── herdr ─────────────────────────────────────────────────────
          herdr = {
            enable = mkEnableOption ''
              the Herdr integration (./herdr, TypeScript on bun). In a Herdr
              TUI pane it reports the session id so herdr can resume Hermes
              sessions; in a Herdr app (herdr-core) pane it reports
              idle/working/blocked status, from launch to exit. Needs
              addToSystemPackages: the wrapped `hermes` CLI marks the pane
            '';
          };
        });

      config = lib.mkIf cfg.enable (
        lib.mkMerge [

          # ── Merge MCP servers into settings ────────────────────────────────
          (lib.mkIf (cfg.mcpServers != { }) {
            services.hermes-agent.settings.mcp_servers = common.mcpServersToConfig cfg.mcpServers;
          })

          # ── Group ─────────────────────────────────────────────────────────
          {
            users.groups.${cfg.group} = { };
          }

          # ── Host CLI ──────────────────────────────────────────────────────
          # Add the wrapped hermes CLI to the system PATH and export
          # HERMES_HOME system-wide, so interactive shells share state
          # (sessions, skills, cron) with the gateway service instead of
          # creating a separate ~/.hermes/.
          (lib.mkIf cfg.addToSystemPackages {
            environment.systemPackages = [ hermesCli ];
            environment.variables.HERMES_HOME = hermesHome;
          })

          # ── Assertions ─────────────────────────────────────────────────────
          {
            assertions =
              common.pluginNameAssertions {
                inherit cfg;
                optionPath = "services.hermes-agent";
              }
              ++ common.workspaceFilesAssertions {
                inherit cfg;
                opt = options.services.hermes-agent.workingDirectory;
                optionPath = "services.hermes-agent";
              }
              ++ common.backendBindAssertions {
                inherit cfg;
                optionPath = "services.hermes-agent";
              };
          }

          # ── Per-user profile for extraPackages ───────────────────────────
          # Wire extraPackages into the user's per-user profile so the
          # login-shell snapshot (which rebuilds PATH from NixOS profiles) sees
          # them.  The systemd service PATH also includes them for direct access.
          (lib.mkIf (cfg.extraPackages != [ ]) {
            # listOf options are merged by the NixOS module system — this
            # appends to the packages the user's own definition assigns.
            users.users.${cfg.user}.packages = cfg.extraPackages;
          })

          # ── Directories ───────────────────────────────────────────────────
          {
            systemd.tmpfiles.rules = [
              "d ${cfg.stateDir}                2750 ${cfg.user} ${cfg.group} - -"
              "d ${hermesHome}                  2750 ${cfg.user} ${cfg.group} - -"
              "d ${cfg.workingDirectory}        2750 ${cfg.user} ${cfg.group} - -"
            ]
            ++ map (d: "d ${hermesHome}/${d} 2750 ${cfg.user} ${cfg.group} - -") common.stateSubdirs;
          }

          # ── Activation: link config + auth + documents ────────────────────
          {
            system.activationScripts."hermes-agent-setup" =
              lib.stringAfter
                ([ "users" ] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
                ''
                  # Ensure directories exist (activation runs before tmpfiles)
                  mkdir -p ${hermesHome}
                  mkdir -p ${cfg.workingDirectory}
                  chown ${cfg.user}:${cfg.group} ${cfg.stateDir} ${hermesHome} ${cfg.workingDirectory}
                  chmod 2750 ${cfg.stateDir} ${hermesHome} ${cfg.workingDirectory}

                  # Create subdirs with setgid, so files the CLI writes there
                  # also take the group.
                  for _subdir in ${lib.concatStringsSep " " common.stateSubdirs}; do
                    mkdir -p "${hermesHome}/$_subdir"
                    chown ${cfg.user}:${cfg.group} "${hermesHome}/$_subdir"
                    chmod 2750 "${hermesHome}/$_subdir"
                  done

                  ${common.mkStateScript {
                    inherit pkgs cfg hermesHome;
                    workingDirectory = cfg.workingDirectory;
                    owner = "${cfg.user}:${cfg.group}";
                    stateDirs = common.stateSubdirs;
                    modes = {
                      config = "0640";
                      env = "0640";
                      managed = "0644";
                      auth = "0600";
                      document = "0640";
                    };
                  }}

                  chown -h ${cfg.user}:${cfg.group} ${hermesHome}/plugins/nix-managed-* 2>/dev/null || true
                '';
          }

          # ── herdr integration ─────────────────────────────────────────────
          (lib.mkIf cfg.herdr.enable {
            assertions = [
              {
                assertion = cfg.addToSystemPackages;
                message = "services.hermes-agent.herdr.enable needs addToSystemPackages: the wrapped hermes CLI marks the pane.";
              }
            ];
            services.hermes-agent.settings.hooks = lib.genAttrs herdrHookEvents (_: [
              {
                command = "${herdrHook}";
                timeout = 5;
              }
            ]);

            # Shell hooks run only once consented (shell-hooks-allowlist.json,
            # by (event, command)). Approve exactly ours, and drop approvals of
            # earlier builds' hooks. The gateway rereads it within ~30 s.
            system.activationScripts.hermes-agent-herdr = lib.stringAfter [ "hermes-agent-setup" ] ''
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
              chown ${cfg.user}:${cfg.group} "$allow"
              chmod 0600 "$allow"

              # The Python plugin this replaced.
              if [ -L ${herdrPluginLink} ] && [[ "$(readlink ${herdrPluginLink})" == /nix/store/* ]]; then
                rm ${herdrPluginLink}
              fi
            '';
          })

          # ══════════════════════════════════════════════════════════════════
          # The gateway: native systemd service
          # ══════════════════════════════════════════════════════════════════
          {
            systemd.services.hermes-agent = {
              description = "Hermes Agent Gateway";
              wantedBy = [ "multi-user.target" ];
              # linger-users.service is the unit that runs `loginctl
              # enable-linger` for a declared `users.users.<name>.linger`.
              after = [
                "network-online.target"
              ]
              ++ lib.optional lingerEnabled "linger-users.service";
              wants = [
                "network-online.target"
              ]
              ++ lib.optional lingerEnabled "linger-users.service";

              # cfg.environment and cfg.environmentFiles are written to
              # $HERMES_HOME/.env by the activation script. load_hermes_dotenv()
              # reads them at Python startup — no systemd EnvironmentFile needed.
              environment = commonUnitEnvironment;

              # Wait for the user bus that `systemd-run --user --scope` connects
              # to. Ordering after linger-users.service is not enough on its own:
              # `loginctl enable-linger` returns before logind has finished
              # starting user@<uid>.service, and run_gateway() resolves
              # XDG_RUNTIME_DIR / DBUS_SESSION_BUS_ADDRESS exactly once at
              # startup — so a bus that appears after ExecStart is a bus this
              # process never sees, for its whole lifetime.
              #
              # Bounded and non-fatal: a gateway without cron beats no gateway.
              preStart = lib.mkIf lingerEnabled ''
                for _ in $(seq 1 50); do
                  [ -S "/run/user/$(id -u)/bus" ] && break
                  sleep 0.2
                done
                if [ ! -S "/run/user/$(id -u)/bus" ]; then
                  echo "hermes-agent: no user bus at /run/user/$(id -u)/bus after 10s;" \
                       "restart-safe cron dispatch will fail for the life of this process" >&2
                fi
              '';

              serviceConfig = commonServiceConfig // {
                ExecStart = lib.escapeShellArgs (common.gatewayArgv cfg);
              };

              path = unitPath;
            };
          }

          # ── The backend: hermes serve or hermes dashboard ─────────────────
          # This is a different process from the gateway. Both use one
          # HERMES_HOME.
          (lib.mkIf (cfg.backend.mode != "none") {
            systemd.services.hermes-backend = {
              description = common.backendDescription cfg;
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              environment = commonUnitEnvironment;

              serviceConfig = commonServiceConfig // {
                ExecStart = lib.escapeShellArgs (common.backendArgv { inherit pkgs cfg; });
              };

              path = unitPath;
            };
          })
        ]
      );
    };
}
