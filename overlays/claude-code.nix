_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "2.0.12";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-5QkpF9Z1UnfYc+3YFm/R/KR7XxwmQJjYgPceYDqib1k=";
    };
  });
}
