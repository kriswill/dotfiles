{
  configurations.darwin.mini.module =
    { config, lib, pkgs, ... }:
    let
      sopsFile = ./cognee-secrets.yaml;
      haveSecrets = builtins.pathExists sopsFile;
      capacityDir = "/var/lib/cognee-capacity";
      pageDir = "/var/lib/cognee-capacity-page";
      pageSocketDir = "/var/lib/cognee-capacity-web-socket";
      pageSocket = "${pageSocketDir}/page.sock";
      page = "${pkgs.bun}/bin/bun ${./cognee-capacity-page.js}";
      history = "/Users/k/.hermes-agent/.hermes/state/cognee-capacity/history.sqlite";
    in
    {
      # Publish aggregates only; the monitor needs no access to the private DB.
      system.activationScripts.launchd.text = lib.mkBefore ''
        /usr/bin/install -d -o _cognee -g staff -m 0750 ${capacityDir} || exit 1
        /usr/bin/install -d -o k -g _www -m 0750 ${pageDir} || exit 1
        test ! -L ${pageSocketDir} || exit 1
        /usr/bin/install -d -o _www -g _www -m 0755 ${pageSocketDir} || exit 1
      '';
      launchd.daemons.cognee-capacity-publish = {
        command = "${page} publish ${pageDir}/history.json ${history}";
        serviceConfig = { UserName = "k"; RunAtLoad = true; StartInterval = 300; ProcessType = "Background"; };
      };
      launchd.daemons.cognee-capacity-web = {
        command = "${pkgs.bun}/bin/bun --env-file=${pageDir}/viewer.env ${./cognee-capacity-page.js} serve ${pageDir}/history.json ${pageSocket} ${config.services.cognee.https.capacityApiSocket}";
        serviceConfig = {
          UserName = "_www";
          GroupName = "_www";
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
      launchd.daemons.cognee-capacity = {
        command = "${pkgs.python3}/bin/python3 -I ${./cognee-capacity.py} ${config.services.cognee.stateDirectory} ${capacityDir}/latest.json";
        serviceConfig = {
          UserName = "_cognee";
          GroupName = "_cognee";
          StartInterval = 3600;
          RunAtLoad = true;
          ProcessType = "Background";
          LowPriorityIO = true;
        };
      };
      sops.secrets = lib.mkIf haveSecrets {
        cognee-env = {
          inherit sopsFile;
          owner = "_cognee";
          mode = "0400";
        };
      };

      services.cognee = {
        enable = true;
        frontend.enable = true;
        https = {
          enable = true;
          hostName = "mini.home.lan";
          capacitySocket = pageSocket;
          listenAddress = "192.168.0.79";
        };
        secretsFile = lib.mkIf haveSecrets config.sops.secrets.cognee-env.path;
        environment = {
          EMBEDDING_PROVIDER = "fastembed";
          EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5";
          # Ingestion and the dashboard's polling can borrow connections at the same time.
          POOL_ARGS = builtins.toJSON {
            pool_size = 4;
            max_overflow = 4;
          };
        }
        // lib.optionalAttrs haveSecrets {
          LLM_PROVIDER = "openai";
          LLM_MODEL = "openai/gpt-5.6-luna";
          GRAPH_EXTRACTOR = "llm";
        };
      };
    };
}
