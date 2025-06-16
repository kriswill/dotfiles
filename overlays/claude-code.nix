final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.24";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-12nmnVM0/+rhWrkIQXttASKPZgGQMvrzWF/JDwR7If4=";
    };
  });
}
