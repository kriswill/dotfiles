_final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "1.0.83";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-h6bAP6nMifQ6cfM80A1QxSYM53LYbEX1WsyPiNPby0M=";
    };
  });
}
