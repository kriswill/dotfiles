{
  configurations.darwin.mini.module =
    { config, lib, ... }:
    let
      sopsFile = ./cognee-secrets.yaml;
      haveSecrets = builtins.pathExists sopsFile;
    in
    {
      sops.secrets = lib.mkIf haveSecrets {
        cognee-env = {
          inherit sopsFile;
          owner = "_cognee";
          mode = "0400";
        };
      };

      services.cognee = {
        enable = true;
        secretsFile = lib.mkIf haveSecrets config.sops.secrets.cognee-env.path;
        environment = {
          EMBEDDING_PROVIDER = "fastembed";
          EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5";
        }
        // lib.optionalAttrs haveSecrets {
          LLM_PROVIDER = "openai";
          LLM_MODEL = "openai/gpt-5.6-luna";
          GRAPH_EXTRACTOR = "llm";
        };
      };
    };
}
