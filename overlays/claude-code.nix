_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.43";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-MPnctLow88Muzd9h5c6w/u0tO4Umrl6YJcp/1/BTFD4=";
    };
  });
}
