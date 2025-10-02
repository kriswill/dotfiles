_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "2.0.5";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-ZAolpT/NW48NpIoY2jUzbBlcHmyNcw+G1GhZ40qtJoY=";
    };
  });
}
