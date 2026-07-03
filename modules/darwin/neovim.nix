# Kris' neovim (system-level port of the old home-manager module).
#
# nix-darwin has no programs.neovim, so the editor and its supporting
# LSP/formatter/linter/tool binaries all go on the global PATH — which also
# means EDITOR can be a plain "nvim" instead of home-manager's wrapped
# finalPackage. The Lua config lives in the stow tree (home/nvim/.config/nvim),
# symlinked into ~ by dotfiles-stow.nix.
{
  flake.modules.darwin.neovim =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options.kriswill.neovim.enable = lib.mkEnableOption "Kris' neovim";
      config = lib.mkIf config.kriswill.neovim.enable {
        environment.variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          MANPAGER = "nvim +Man!";
        };

        environment.systemPackages =
          let
            neovim = pkgs.neovim.override {
              viAlias = true;
              vimAlias = true;
              withPython3 = false;
              withRuby = false;
            };
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
                svelte-language-server # Svelte (svelteserver)
                vscode-langservers-extracted # json, HTML, CSS, ESLint
                typescript
                vtsls # LSP wrapper for typescript extension of vscode
                yaml-language-server # YAML (yamlls)
                ;
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
          [ neovim ] ++ formatters ++ lsp-servers ++ linters ++ tools;
      };
    };
}
