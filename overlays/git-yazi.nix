# git.yazi — bump nixpkgs' pinned snapshot (0-unstable-2026-08-03, written
# for the pre-26.8 fetcher API) to upstream HEAD. Under yazi 26.8.15 the old
# plugin's fetch() contract leaves fetcher tasks permanently pending, so yazi
# accumulates "git" background tasks and prompts to abort them on quit.
# Upstream rewrote the plugin for the new fetcher API on 2026-08-18
# ("simplify with new fetcher API", yazi-rs/plugins@6f26ae0); nixpkgs hasn't
# picked it up yet. Drop this once nixpkgs' yaziPlugins.git is at or past
# that commit.
_final: prev: {
  yaziPlugins = prev.yaziPlugins // {
    git = prev.yaziPlugins.git.overrideAttrs (_old: {
      version = "0-unstable-2026-08-19";
      src = prev.fetchFromGitHub {
        owner = "yazi-rs";
        repo = "plugins";
        rev = "efa4d79da8ada35380ede5788d3f3b0ee9f70306";
        hash = "sha256-uRjuzA58DtxKW8kpTpe0pM54cAnyu5zQoPxJUeiSKL0=";
      };
    });
  };
}
