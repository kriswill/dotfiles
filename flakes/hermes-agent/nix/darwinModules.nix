# nix/darwinModules.nix — the nix-darwin module for hermes-agent
#
# Ours: not an upstream file. Upstream covers macOS only through its Home
# Manager module, which this repo does not use. This is the NixOS module's
# twin (same `services.hermes-agent` options from moduleCommon.nix, same
# single-owner layout), with launchd in place of systemd and a Seatbelt
# sandbox in place of the unit hardening:
#
#   - `user` owns the state and runs everything. It defaults to
#     system.primaryUser. No group: the state is 0700/0600.
#   - `stateDir` holds HERMES_HOME (`.hermes`) and the workspace, and is
#     HOME for every Hermes process, so what the agent's tools write to "~"
#     lands there.
#   - The gateway is a launchd user agent. It needs the user's session
#     (launchd user agents start at login), like upstream's Home Manager one.
#   - `sandbox.enable` (default on) starts the gateway, the backend and the
#     CLI through ./darwinSandbox.nix. That file says what the sandbox grants.
#   - `herdr.enable` is the NixOS module's Herdr integration (./hermesCli.nix).
#
# Usage:
#   services.hermes-agent = {
#     enable = true;
#     addToSystemPackages = true;
#     sandbox.readWritePaths = [ "/Users/alice/src/project" ];
#     environmentFiles = [ config.sops.secrets."hermes/env".path ];
#   };
{ inputs, ... }:
{
  flake.darwinModules.default =
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
      owner = "${cfg.user}:staff";
      logDir = "/Users/${cfg.user}/Library/Logs";

      mkSandbox =
        extraProfile:
        import ./darwinSandbox.nix { inherit lib pkgs; } {
          inherit (cfg) stateDir workingDirectory;
          inherit (cfg.sandbox)
            readPaths
            readWritePaths
            unixSockets
            passEnvironment
            ;
          extraProfile = cfg.sandbox.extraProfile + extraProfile;
        };

      # The launchd agents' sandbox.
      sandbox = mkSandbox "";

      # The CLI's sandbox. Each launch is a sandbox of its own, and Seatbelt
      # allows signals only inside one, so the launchd gateway can never stop
      # a gateway that a CLI started (`--replace` is refused the SIGTERM).
      # A CLI that finds no gateway starts one, which holds the lock while
      # that CLI stays open, and the agent then exits every ThrottleInterval
      # for as long. So with the agent on, a CLI's sandbox cannot take the
      # gateway locks: its own gateway fails, and it waits for the agent's.
      cliSandbox = mkSandbox (
        lib.optionalString cfg.gateway.enable ''
          (deny file-write*
            (literal "${hermesHome}/gateway.lock")
            (literal "${hermesHome}/gateway.pid")
            (subpath "${cfg.stateDir}/.local/state/hermes/gateway-locks"))
        ''
      );
      launcher = if cfg.sandbox.enable then cliSandbox.launcher else null;
      confined = argv: lib.optional cfg.sandbox.enable "${sandbox.launcher}" ++ argv;

      hermesCliParts = import ./hermesCli.nix { inherit lib pkgs; } {
        package = effectivePackage;
        inherit hermesHome launcher;
        herdr = cfg.herdr.enable;
      };

      agentPath = "${
        lib.makeBinPath (common.processPath { inherit pkgs cfg; })
      }:/etc/profiles/per-user/${cfg.user}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin";

      mkAgent =
        {
          argv,
          logName,
          environment ? { },
        }:
        {
          serviceConfig = {
            ProgramArguments = confined argv;
            EnvironmentVariables =
              common.processEnvironment { inherit hermesHome; }
              // environment
              // {
                HOME = cfg.stateDir;
                PATH = agentPath;
              };
            WorkingDirectory = cfg.workingDirectory;
            RunAtLoad = true;
            KeepAlive =
              if cfg.restart == "always" then
                true
              else
                {
                  SuccessfulExit = false;
                  Crashed = true;
                };
            ThrottleInterval = cfg.restartSec;
            # 0077: the state has one owner.
            Umask = 63;
            StandardOutPath = "${logDir}/${logName}.log";
            StandardErrorPath = "${logDir}/${logName}.err.log";
            ProcessType = "Background";
          };
        };
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
          user = mkOption {
            type = types.str;
            default = config.system.primaryUser;
            defaultText = literalExpression "config.system.primaryUser";
            description = ''
              The existing account that owns the state and runs the gateway
              and the CLI. Hermes allows one owner per HERMES_HOME.
            '';
          };

          stateDir = mkOption {
            type = types.str;
            default = "/Users/${cfg.user}/.hermes-agent";
            defaultText = literalExpression ''"/Users/''${cfg.user}/.hermes-agent"'';
            description = ''
              State directory. Contains the .hermes/ subdir (HERMES_HOME) and
              by default the workspace, and is HOME for every Hermes process.
              With the sandbox it is the one place they can write, so give
              the canonical path (no symlink in it).
            '';
          };

          addToSystemPackages = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Add the hermes CLI to environment.systemPackages, wrapped to
              default HERMES_HOME to the service's and, with the sandbox, to
              start inside it.
            '';
          };

          gateway.enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Run the gateway (cron, memory, messaging platforms) as a
              launchd user agent. Without it the CLI starts its own.
            '';
          };

          herdr.enable = mkEnableOption ''
            the Herdr integration (./herdr, TypeScript on bun): an
            interactive `hermes` in a Herdr pane reports idle/working/blocked
            status. Needs addToSystemPackages: the wrapped CLI marks the pane
          '';

          sandbox = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Confine the gateway, the backend and the CLI with a
                deny-by-default Seatbelt profile (`sandbox-exec`): they read
                the system but not the user's home, write only `stateDir`, a
                private TMPDIR and `readWritePaths`, and reach the network
                but no other program's unix socket, the keychain, launchd or
                other applications. Only an allow-listed part of the
                caller's environment crosses into it.
              '';
            };

            readPaths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "/Users/alice/src" ];
              description = "Canonical paths the sandbox may also read.";
            };

            readWritePaths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "/Users/alice/src/project" ];
              description = ''
                Canonical paths the sandbox may also read and write, such as
                a project the agent works on. The agent can then also serve
                and reach unix sockets there.
              '';
            };

            unixSockets = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "/nix/var/nix/daemon-socket/socket" ];
              description = ''
                Unix sockets outside the writable paths the sandbox may
                connect to. Each one is a way into the program serving it:
                the nix daemon socket lets the agent build and run
                derivations as the nix build users.
              '';
            };

            passEnvironment = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "EDITOR" ];
              description = ''
                More environment variable names to pass from the CLI's
                caller into the sandbox. Secrets belong in environmentFiles.
              '';
            };

            extraProfile = mkOption {
              type = types.lines;
              default = "";
              description = "Seatbelt (SBPL) rules appended to the profile.";
            };
          };
        });

      config = lib.mkIf cfg.enable (
        lib.mkMerge [

          (lib.mkIf (cfg.mcpServers != { }) {
            services.hermes-agent.settings.mcp_servers = common.mcpServersToConfig cfg.mcpServers;
          })

          (lib.mkIf cfg.addToSystemPackages {
            environment.systemPackages = [ hermesCliParts.cli ];
          })

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
              }
              ++ [
                {
                  # The interface poll reads `ip`, which is iproute2's.
                  assertion = cfg.backend.waitFor != "interface";
                  message = "services.hermes-agent.backend.waitFor = \"interface\" works on Linux only. Use \"hostname\" on Darwin.";
                }
              ];
          }

          # The agent runs these tools from login shells, which rebuild PATH
          # from the profiles.
          (lib.mkIf (cfg.extraPackages != [ ]) {
            users.users.${cfg.user}.packages = cfg.extraPackages;
          })

          # ── Activation: directories, config, secrets, documents ───────────
          # Runs as root (it reads root-only environmentFiles), late, so a
          # secret sops-nix installs in this activation exists. Everything it
          # creates is handed to the owner.
          {
            system.activationScripts.postActivation.text = lib.mkOrder 2000 ''
              echo "setting up hermes-agent state in ${cfg.stateDir}..." >&2
              (
                # GNU install: mkStateScript uses `install -D`.
                PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:$PATH
                umask 077

                ${common.mkStateScript {
                  inherit
                    pkgs
                    cfg
                    hermesHome
                    owner
                    ;
                  inherit (cfg) workingDirectory;
                  stateDirs = common.stateSubdirs;
                  modes = {
                    config = "0600";
                    env = "0600";
                    managed = "0600";
                    auth = "0600";
                    document = "0600";
                  };
                }}

                chown ${owner} ${
                  lib.escapeShellArgs (
                    [
                      cfg.stateDir
                      hermesHome
                      cfg.workingDirectory
                      "${hermesHome}/config.yaml"
                    ]
                    ++ map (d: "${hermesHome}/${d}") common.stateSubdirs
                  )
                }
                chmod 0700 ${
                  lib.escapeShellArgs [
                    cfg.stateDir
                    hermesHome
                  ]
                }
                chown -h ${owner} ${hermesHome}/plugins/nix-managed-* 2>/dev/null || true

                ${lib.optionalString cfg.herdr.enable (hermesCliParts.herdrActivation { inherit owner; })}
              )
            '';
          }

          (lib.mkIf cfg.herdr.enable {
            assertions = [
              {
                assertion = cfg.addToSystemPackages;
                message = "services.hermes-agent.herdr.enable needs addToSystemPackages: the wrapped hermes CLI marks the pane.";
              }
            ];
            services.hermes-agent.settings.hooks = hermesCliParts.herdrHooks;
          })

          # ── The gateway and the backend: launchd user agents ──────────────
          # cfg.environment and cfg.environmentFiles reach them through
          # $HERMES_HOME/.env, which activation writes.
          (lib.mkIf cfg.gateway.enable {
            launchd.user.agents.hermes-agent = mkAgent {
              # Not common.gatewayArgv (a bare `hermes gateway`): Hermes
              # recognises launchd only by an `ai.hermes` job label, and ours
              # is org.nixos.hermes-agent. Declared, an in-chat restart exits
              # back to launchd rather than spawning a detached replacement.
              # No --replace: it stops the other gateway with a signal, which
              # the sandbox refuses (see cliSandbox).
              argv = [
                "${effectivePackage}/bin/hermes"
                "gateway"
                "run"
                "--external-supervisor"
              ]
              ++ cfg.extraArgs;
              logName = "hermes-agent";
            };
          })

          (lib.mkIf (cfg.backend.mode != "none") {
            launchd.user.agents.hermes-backend = mkAgent {
              argv = common.backendArgv { inherit pkgs cfg; };
              logName = "hermes-backend";
              environment = common.backendSessionEnvironment { inherit cfg; };
            };
          })
        ]
      );
    };
}
