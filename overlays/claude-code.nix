final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.3";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-LjDxVv6KSTuRZhCHztvf81E5DQbkqs8cbrnbbGkCeQU=";
    };
  });
}
