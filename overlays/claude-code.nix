_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.72";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-1vIElqZ5sk62o1amdfOqhmSG4B5wzKWDLcCgvQO4a5o=";
    };
  });
}
