_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.62";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-bzbnLVAtMXr4XHmHqSOn3jxB+6BsFCd3gd/j34Zkwi0=";
    };
  });
}
