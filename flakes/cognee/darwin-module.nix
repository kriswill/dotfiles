self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cognee;
  pg = cfg.postgresql;
  proxy = cfg.https;
  ui = cfg.frontend;
  appUser = "_cognee";
  pgUser = "_cognee-postgres";
  proxyUser = "_cognee-proxy";
  uiUser = "_cognee-frontend";
  uiState = "${cfg.stateDirectory}-frontend";
  group = "_cognee";
  passwordFile = "${pg.stateDirectory}/password";
  postgres = pkgs.postgresql_17.withPackages (ps: [ ps.pgvector ]);
  emptyEnvironment = pkgs.writeText "cognee-empty.env" "";
  apiAddress = "127.0.0.1:${toString cfg.port}";
  httpsOrigin = "https://${proxy.hostName}:${toString proxy.port}";
  pgPort = toString pg.port;
  cogneeJob = lib.escapeShellArg "system/${config.launchd.daemons.cognee.serviceConfig.Label}";

  postgresEnvironment = {
    DB_PROVIDER = "postgres";
    DB_HOST = "127.0.0.1";
    DB_PORT = pgPort;
    DB_NAME = "cognee";
    DB_USERNAME = "cognee";
    VECTOR_DB_PROVIDER = "pgvector";
    VECTOR_DATASET_DATABASE_HANDLER = "pgvector_shared";
    VECTOR_DB_HOST = "127.0.0.1";
    VECTOR_DB_PORT = pgPort;
    VECTOR_DB_NAME = "cognee";
    VECTOR_DB_USERNAME = "cognee";
  };

  mkUser = uid: home: {
    inherit uid home;
    gid = cfg.uid;
  };
  daemon = user: logPath: {
    UserName = user;
    GroupName = group;
    RunAtLoad = true;
    KeepAlive = true;
    ExitTimeOut = 30;
    ThrottleInterval = 10;
    StandardOutPath = logPath;
    StandardErrorPath = logPath;
    Umask = 63; # 077
  };
  postgresLauncher = pkgs.writeShellApplication {
    name = "cognee-postgresql";
    runtimeInputs = [
      postgres
      pkgs.coreutils
    ];
    text = builtins.readFile ./postgresql.sh;
  };
  caddyConfig = pkgs.writeText "cognee.Caddyfile" ''
    {
      admin off
      auto_https disable_redirects
      skip_install_trust
    }

    ${httpsOrigin} {
      bind ${proxy.listenAddress}
      tls internal

      route {
        @register path /api/v1/auth/register /api/v1/auth/register/
        respond @register 404
        ${
          if ui.enable then
            ''
              @api path /api/v1 /api/v1/* /health /health/* /docs /docs/* /redoc /openapi.json
              handle @api {
                reverse_proxy ${apiAddress}
              }
              handle {
                reverse_proxy 127.0.0.1:${toString ui.port}
              }
            ''
          else
            "reverse_proxy ${apiAddress}"
        }
      }
    }
  '';
  directory = lib.types.strMatching "/[a-zA-Z0-9._/-]+";
in
{
  options.services.cognee = {
    enable = lib.mkEnableOption "the native Cognee memory API";
    package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "cognee" { };
    uid = lib.mkOption {
      type = lib.types.ints.positive;
      default = 451;
      description = "UID of _cognee and GID of the shared _cognee group.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Loopback port for the Cognee REST API.";
    };
    stateDirectory = lib.mkOption {
      type = directory;
      default = "/var/lib/cognee";
      description = "Persistent Cognee state, ingested files, and model cache.";
    };
    secretsFile = lib.mkOption {
      type = lib.types.nullOr directory;
      default = null;
      example = "/run/secrets/cognee-env";
      description = "Runtime dotenv file readable by _cognee for signing secrets and provider credentials.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Non-secret Cognee settings inherited by the API process.";
    };
    frontend = {
      enable = lib.mkEnableOption "the Cognee web dashboard behind its HTTPS proxy";
      package =
        lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "cognee-frontend"
          { };
      uid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 454;
        description = "UID and GID of the _cognee-frontend service account.";
      };
      port = lib.mkOption {
        type = lib.types.ints.between 1024 65535;
        default = 3000;
        description = "Loopback port for the Cognee web dashboard.";
      };
    };
    postgresql = {
      enable = lib.mkEnableOption "Cognee's dedicated PostgreSQL 17 and pgvector LaunchDaemon";
      uid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 452;
        description = "UID of the _cognee-postgres service account.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 55432;
        description = "Loopback port for Cognee's dedicated PostgreSQL server.";
      };
      stateDirectory = lib.mkOption {
        type = directory;
        default = "/var/lib/cognee-postgresql";
        description = "Persistent PostgreSQL cluster and generated database credential.";
      };
    };
    https = {
      enable = lib.mkEnableOption "a LAN HTTPS endpoint using Caddy's internal CA";
      uid = lib.mkOption {
        type = lib.types.ints.positive;
        default = 453;
        description = "UID of the _cognee-proxy service account.";
      };
      hostName = lib.mkOption {
        type = lib.types.strMatching "[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?";
        description = "LAN DNS name presented by the HTTPS endpoint.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.strMatching "[0-9a-fA-F:.]+";
        description = "Local LAN IP address on which Caddy listens.";
      };
      port = lib.mkOption {
        type = lib.types.ints.between 1024 65535;
        default = 8443;
        description = "Unprivileged LAN HTTPS port.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !proxy.enable || cfg.secretsFile != null;
            message = "services.cognee.https requires a runtime secretsFile.";
          }
          {
            assertion =
              !pg.enable || (cfg.uid != pg.uid && cfg.port != pg.port && cfg.stateDirectory != pg.stateDirectory);
            message = "Cognee and its managed PostgreSQL need distinct UIDs, ports, and state directories.";
          }
          {
            assertion = !proxy.enable || (proxy.uid != cfg.uid && (!pg.enable || proxy.uid != pg.uid));
            message = "The Cognee HTTPS proxy needs its own UID.";
          }
          {
            assertion = !ui.enable || proxy.enable;
            message = "services.cognee.frontend requires services.cognee.https.enable.";
          }
          {
            assertion =
              !ui.enable
              || (
                ui.uid != cfg.uid
                && ui.uid != proxy.uid
                && ui.port != cfg.port
                && ui.port != proxy.port
                && (!pg.enable || (ui.uid != pg.uid && ui.port != pg.port))
              );
            message = "The Cognee web dashboard needs its own UID and port.";
          }
        ];

        users.knownUsers = [ appUser ];
        users.knownGroups = [ group ];
        users.groups.${group}.gid = cfg.uid;
        users.users.${appUser} = mkUser cfg.uid cfg.stateDirectory;

        # nix-darwin creates users before processing the system launchd jobs.
        system.activationScripts.launchd.text = lib.mkBefore ''
          /usr/bin/install -d -m 0700 -o ${appUser} -g ${group} ${lib.escapeShellArg cfg.stateDirectory} || exit 1
        '';

        launchd.daemons.cognee = {
          environment = {
            LANG = "en_US.UTF-8";
            TELEMETRY_DISABLED = "1";
            GRAPH_EXTRACTOR = "llm";
            GLINER_AUTO_INSTALL = "false";
            DATASET_QUEUE_MAX_CONCURRENT = "2";
            DATABASE_MAX_LRU_CACHE_SIZE = "2";
            KUZU_NUM_THREADS = "2";
            KUZU_BUFFER_POOL_SIZE = "268435456";
            POOL_ARGS = builtins.toJSON {
              pool_size = 2;
              max_overflow = 2;
            };
            VECTOR_POOL_ARGS = builtins.toJSON {
              pool_size = 2;
              max_overflow = 1;
            };
          }
          // cfg.environment
          // {
            HOME = cfg.stateDirectory;
            DATA_ROOT_DIRECTORY = "${cfg.stateDirectory}/data";
            SYSTEM_ROOT_DIRECTORY = "${cfg.stateDirectory}/system";
            HF_HOME = "${cfg.stateDirectory}/cache/huggingface";
            COGNEE_ENV_FILE = toString emptyEnvironment;
            COGNEE_LOG_FILE = "false";
            ENABLE_BACKEND_ACCESS_CONTROL = "true";
            HASH_API_KEY = "true";
          }
          // lib.optionalAttrs proxy.enable { AUTH_TOKEN_COOKIE_SECURE = "true"; }
          // lib.optionalAttrs pg.enable postgresEnvironment;
          script = ''
              set -euo pipefail
            ${lib.optionalString (cfg.secretsFile != null) ''
              if [[ ! -r ${lib.escapeShellArg cfg.secretsFile} ]]; then
                echo 'Cognee runtime secrets file is unreadable.' >&2
                exit 1
              fi
            ''}
              ${lib.optionalString pg.enable ''
                export DB_PASSWORD
                DB_PASSWORD="$(/bin/cat ${lib.escapeShellArg passwordFile})"
                export VECTOR_DB_PASSWORD="$DB_PASSWORD"

                for attempt in {1..20}; do
                  if PGPASSWORD="$DB_PASSWORD" PGCONNECT_TIMEOUT=2 \
                    ${postgres}/bin/psql -XAt -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" \
                      -d "$DB_NAME" -c 'SELECT 1' >/dev/null 2>&1; then
                    break
                  fi
                  if [[ "$attempt" == 20 ]]; then
                    echo 'Cognee PostgreSQL did not accept an authenticated connection.' >&2
                    exit 1
                  fi
                  /bin/sleep 1
                done
              ''}
              exec ${cfg.package}/bin/uvicorn cognee.api.client:app \
                --host 127.0.0.1 --port ${toString cfg.port} --workers 1 \
                --timeout-graceful-shutdown 10 \
                ${lib.optionalString (
                  cfg.secretsFile != null
                ) "--env-file ${lib.escapeShellArg cfg.secretsFile}"}
          '';
          serviceConfig = daemon appUser "${cfg.stateDirectory}/cognee.log" // {
            WorkingDirectory = cfg.stateDirectory;
          };
        };
      }
      (lib.mkIf (cfg.secretsFile != null) {
        # sops-nix installs its runtime files at order 1500. The receipt under
        # /var/run records what was last handed to launchd, even after a failed activation.
        system.activationScripts.postActivation.text = lib.mkOrder 1900 ''
          (
            set -euo pipefail
            umask 077
            cognee_receipt=/var/run/cognee-secrets.sha256
            cognee_digest=$(/usr/bin/shasum -a 256 < ${lib.escapeShellArg cfg.secretsFile})
            if [[ -f "$cognee_receipt" && "$(<"$cognee_receipt")" == "$cognee_digest" ]]; then
              exit 0
            fi

            # KeepAlive starts a new process after Cognee drains its work on SIGTERM.
            /bin/launchctl kill SIGTERM ${cogneeJob} 2>/dev/null || /bin/launchctl kickstart ${cogneeJob}

            cognee_receipt_tmp=$(/usr/bin/mktemp "$cognee_receipt.XXXXXX")
            trap '/bin/rm -f "$cognee_receipt_tmp"' EXIT
            printf '%s\n' "$cognee_digest" > "$cognee_receipt_tmp"
            /bin/mv -f "$cognee_receipt_tmp" "$cognee_receipt"
          )
        '';
      })
      (lib.mkIf pg.enable {
        users.knownUsers = [ pgUser ];
        users.users.${pgUser} = mkUser pg.uid "${pg.stateDirectory}/cluster";
        system.activationScripts.launchd.text = lib.mkBefore ''
            cognee_pg_state=${lib.escapeShellArg pg.stateDirectory}
          /usr/bin/install -d -m 0750 -o root -g ${group} "$cognee_pg_state" || exit 1
          /usr/bin/install -d -m 0700 -o ${pgUser} -g ${group} "$cognee_pg_state/cluster" || exit 1
            if [[ ! -s "$cognee_pg_state/password" ]]; then
              if [[ -e "$cognee_pg_state/cluster/data/PG_VERSION" ]]; then
                echo 'Restore the Cognee PostgreSQL password file for the existing cluster.' >&2
                exit 1
              fi
              (
                set -euo pipefail
                password_tmp="$(/usr/bin/mktemp "$cognee_pg_state/password.XXXXXX")"
                trap '/bin/rm -f "$password_tmp"' EXIT
                ${pkgs.openssl}/bin/openssl rand -hex 32 > "$password_tmp"
                /usr/sbin/chown root:${group} "$password_tmp"
                /bin/chmod 0440 "$password_tmp"
                /bin/mv -f "$password_tmp" "$cognee_pg_state/password"
              ) || exit 1
            fi
        '';
        launchd.daemons.cognee-postgresql = {
          command = "${postgresLauncher}/bin/cognee-postgresql";
          environment = {
            COGNEE_PG_STATE = pg.stateDirectory;
            COGNEE_PG_PORT = pgPort;
            LC_ALL = "C";
          };
          serviceConfig = daemon pgUser "${pg.stateDirectory}/cluster/cognee-postgresql.log" // {
            WorkingDirectory = "${pg.stateDirectory}/cluster";
          };
        };
      })
      (lib.mkIf ui.enable {
        users.knownUsers = [ uiUser ];
        users.knownGroups = [ uiUser ];
        users.groups.${uiUser}.gid = ui.uid;
        users.users.${uiUser} = mkUser ui.uid uiState // {
          gid = ui.uid;
        };
        system.activationScripts.launchd.text = lib.mkBefore ''
          /usr/bin/install -d -m 0700 -o ${uiUser} -g ${uiUser} ${lib.escapeShellArg uiState} || exit 1
        '';
        launchd.daemons.cognee-frontend = {
          command = "${lib.getExe ui.package}";
          environment = {
            HOME = uiState;
            HOSTNAME = "127.0.0.1";
            PORT = toString ui.port;
            COGNEE_BACKEND_URL = httpsOrigin;
            COGNEE_INTERNAL_BACKEND_URL = "http://${apiAddress}";
          };
          serviceConfig = daemon uiUser "${uiState}/cognee-frontend.log" // {
            GroupName = uiUser;
            WorkingDirectory = uiState;
          };
        };
      })
      (lib.mkIf proxy.enable {
        users.knownUsers = [ proxyUser ];
        users.knownGroups = [ proxyUser ];
        users.groups.${proxyUser}.gid = proxy.uid;
        users.users.${proxyUser} = mkUser proxy.uid "${cfg.stateDirectory}-proxy" // {
          gid = proxy.uid;
        };
        system.activationScripts.launchd.text = lib.mkBefore ''
          /usr/bin/install -d -m 0700 -o ${proxyUser} -g ${proxyUser} ${lib.escapeShellArg "${cfg.stateDirectory}-proxy"} || exit 1
        '';
        launchd.daemons.cognee-proxy = {
          command = "${pkgs.caddy}/bin/caddy run --config ${caddyConfig} --adapter caddyfile";
          environment = {
            HOME = "${cfg.stateDirectory}-proxy";
            XDG_DATA_HOME = "${cfg.stateDirectory}-proxy";
          };
          serviceConfig = daemon proxyUser "${cfg.stateDirectory}-proxy/cognee-proxy.log" // {
            GroupName = proxyUser;
          };
        };
      })
    ]
  );
}
