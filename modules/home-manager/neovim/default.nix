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
      withPython3 = false;

      extraPackages =
        let
          ## Formatters  ──────────────────────────────────────────────
          formatters = builtins.attrValues {
            inherit (pkgs)
              biome # JS / TS / JSON (replaces prettier_d for these)
              black # Python
              gofumpt # stricter gofmt
              isort # Python
              libxml2 # provides xmllint for XML
              nixfmt
              prettierd # HTML / markdown via efm
              rustfmt # Rust
              shfmt
              stylua # Lua
              yamlfmt # YAML
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
              efm-langserver # generic LSP that wraps CLI linters (see linters)
              go # golang
              go-tools
              gopls # Go
              lua-language-server # Lua (lua_ls)
              lua5_1
              luarocks
              zk # Markdown LSP (Go-based, replaces marksman which requires .NET/Swift)
              nil
              tofu-ls # opentofu/terraform
              pyright
              rust-analyzer # Rust
              vscode-langservers-extracted # json, HTML, CSS, ESLint
              vtsls # LSP wrapper for typescript extension of vscode
              yaml-language-server # YAML (yamlls)
              ;
            typescript = pkgs.typescript;
          };
          ## Linters (invoked by efm-langserver)  ─────────────────────
          linters = builtins.attrValues {
            inherit (pkgs)
              gitlint # gitcommit
              hadolint # Dockerfile
              rumdl # markdown
              shellcheck # sh / bash / zsh
              yamllint # yaml
              ;
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
        formatters ++ lsp-servers ++ linters ++ tools;
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
      };
  };
}
