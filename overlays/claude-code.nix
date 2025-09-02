_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.100";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-NtxWKpWsKZI2MeR3WPxB7KtDV+QK6/PLf1cV6ImQrrw=";
    };
  });
}
