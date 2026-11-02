# ai-usage — AI account usage collector (Claude Max, Anthropic API, ChatGPT).
# See pkgs/ai-usage/package.nix.
_final: prev: {
  ai-usage = prev.callPackage ../pkgs/ai-usage/package.nix { };
}
