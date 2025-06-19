final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.30";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-DwzSXpDrNV8FhfqrRQ3OK/LjmiXd+VHEW91jnyds2P4=";
    };
  });
}
