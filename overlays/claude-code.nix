final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.10";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-DcHlxeOOIKDe/Due952rH5qGT3KX+lUx84ctuj2/3aw=";
    };
  });
}
