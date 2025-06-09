final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.17";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-RxbsAehJ4zIt86ppmMB1MPg/XFrGWuumNdQbT+ytg8A=";
    };
  });
}
