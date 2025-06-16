{ config, pkgs, ... }:

with pkgs;
{
  programs.neovim = {
    enable = true;
    package = neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    withRuby = false;

    extraPackages = [
      ## Formatters  ──────────────────────────────────────────────
      black # Python
      gofumpt # stricter gofmt
      isort # Python
      luajitPackages.jsregexp # luasnip
      nixfmt-rfc-style
      prettierd # Multiple language formatter
      shfmt
      stylua # Lua
      yamlfmt

      ## LSP servers  ─────────────────────────────────────────────
      bash-language-server # Bash
      buf # bufls
      docker-compose-language-service # Docker Compose
      gopls # Go
      lua-language-server # Lua (lua_ls)
      lua5_1
      luarocks
      marksman # Markdown
      nil
      nodePackages.typescript
      nodePackages.typescript-language-server # ts_ls
      pyright
      rust-analyzer # Rust
      yaml-language-server # YAML (yamlls)
      gh-actions-language-server # github actions

      go_1_24
      (go-tools.override { buildGoModule = buildGo124Module; })

      ## Tools  ───────────────────────────────────────────────────
      cargo
      cmake
      delve # golang debugger `dlv`
      fswatch # file watcher - replaces libuv.fs_event in neovim v0.10
      fzf
      git
      gnumake
      imagemagick
      nodejs
      sqlite
      tree-sitter
      wget
    ];
  };
}
// (
  let
    # used to link files to .config/nvim/*
    nvimDir = config.home.homeDirectory + "/src/dotfiles/home/programs/neovim/nvim";
    ln = config.lib.file.mkOutOfStoreSymlink;
  in
  {
    xdg.configFile = {
      "nvim/lua".source = ln nvimDir + "/lua";
      "nvim/lsp".source = ln nvimDir + "/lsp";
      "nvim/ftplugin".source = ln nvimDir + "/ftplugin";
      "nvim/init.lua".source = ln nvimDir + "/init.lua";
      "nvim/lazy-lock.json".source = ln nvimDir + "/lazy-lock.json";
    };
  }
)
