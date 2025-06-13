final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.22";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-Gn+AzZysuYsZDMzcXlzDMWSWeJS3L7itvlGJq4kYha0=";
    };
  });
}
