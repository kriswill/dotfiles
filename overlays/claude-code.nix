_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.56";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-q/17LfP5MWeKpt8akPXwMvkZ6Qhc+9IGpM6N34JuExY=";
    };
  });
}
