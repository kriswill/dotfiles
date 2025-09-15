_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.113";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-N3lKbu3OtF1X65Dr9JghMdgsqQD2RYS/YJUNtPJVyyw=";
    };
  });
}
