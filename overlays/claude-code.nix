final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "1.0.7";
    src = prev.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-mNn2ulcq0WIAQ69ksEmtmWhqyNvncDP8MP07xQ9VYNo=";
    };
  });
}
