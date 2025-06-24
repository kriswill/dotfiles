_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.32";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-Awpu3DQz0yi4ZMtgU7JdxpJyWi3j8tyyflgoxO4KLx4=";
    };
  });
}
