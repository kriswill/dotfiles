_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.120";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-bdARSCZzoMmo/FOAYs20Kz6pR7cM+TyJ+MTbKWBpuGs=";
    };
  });
}
