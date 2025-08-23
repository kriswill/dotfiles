_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.89";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-ULOL4emd7VZNvHD5Hk3YI1Cyb1Q1YMCcDDxlRDUM1dc=";
    };
  });
}
