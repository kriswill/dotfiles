_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.86";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-mVXS75KgeKgD7EI5t9X6+TkwjBFyBLOo4/m50sS9XdA=";
    };
  });
}
