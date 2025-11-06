{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.kriswill.neovim.enable = lib.mkEnableOption "Kris' neovim";
  config = lib.mkIf config.kriswill.neovim.enable {
    programs.neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;
      viAlias = true;
      vimAlias = true;
      withRuby = false;

      extraPackages =
        let
          ## Formatters  ──────────────────────────────────────────────
          formatters = builtins.attrValues {
            inherit (pkgs)
              black # Python
              gofumpt # stricter gofmt
              isort # Python
              nixfmt-rfc-style
              prettierd # Multiple language formatter
              shfmt
              stylua # Lua
              yamlfmt
              ;
            jsregexp = pkgs.luajitPackages.jsregexp; # luasnip
          };
          ## LSP servers  ─────────────────────────────────────────────
          lsp-servers = builtins.attrValues {
            inherit (pkgs)
              bash-language-server # Bash
              buf # bufls
              docker-compose-language-service # Docker Compose
              dockerfile-language-server # Dockerfile
              go # golang
              go-tools
              gopls # Go
              lua-language-server # Lua (lua_ls)
              lua5_1
              luarocks
              marksman # Markdown
              nil
              tofu-ls # opentofu/terraform
              pyright
              rust-analyzer # Rust
              vscode-langservers-extracted # json, HTML, CSS, ESLint
              vtsls # LSP wrapper for typescript extension of vscode
              yaml-language-server # YAML (yamlls)
              ;
            typescript = pkgs.nodePackages.typescript;
          };
          ## Tools  ───────────────────────────────────────────────────
          tools = builtins.attrValues {
            inherit (pkgs)
              cargo
              cmake
              delve # golang debugger `dlv`
              fswatch # file watcher - replaces libuv.fs_event in neovim v0.10
              git
              gnumake
              ghostscript # needed by snacks to render PDFs with the `gs` command
              imagemagick
              mermaid-cli # mmdc
              nodejs
              sqlite
              tree-sitter
              wget
              ;
          };
        in
        formatters ++ lsp-servers ++ tools;
    };

    xdg.configFile =
      let
        # used to link files from <repo>/config/nvim to ~/.config/nvim
        nvimDir = config.home.homeDirectory + "/src/dotfiles/config/nvim";
        ln = config.lib.file.mkOutOfStoreSymlink;
      in
      {

        "nvim/lua".source = ln nvimDir + "/lua";
        "nvim/lsp".source = ln nvimDir + "/lsp";
        "nvim/ftplugin".source = ln nvimDir + "/ftplugin";
        "nvim/init.lua".source = ln nvimDir + "/init.lua";
        "nvim/lazy-lock.json".source = ln nvimDir + "/lazy-lock.json";
      };
  };
}
