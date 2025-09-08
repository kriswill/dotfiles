_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.108";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-PHTT5kb6/MuxqqMWXwqdmpI+4ZSubRUNDp/ENEjcFBE=";
    };
  });
}
