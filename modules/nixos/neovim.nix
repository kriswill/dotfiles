{
  flake.modules.nixos.neovim =
    { pkgs, lib, ... }:
    {
      # snowglobe-lib disables nixpkgs' programs/neovim and ships its own minimal
      # module (enable / package / viAlias / vimAlias). `enable` installs pkgs.neovim
      # globally; the supporting LSP/formatter/linter/tool binaries go on PATH below.
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
      };

      environment.sessionVariables.EDITOR = lib.mkDefault "nvim";

      environment.systemPackages =
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
              svelte-language-server # Svelte (svelteserver)
              vscode-langservers-extracted # json, HTML, CSS, ESLint
              yaml-language-server # YAML (yamlls)
              ;
            inherit (pkgs) typescript;
            # LSP wrapper for the vscode typescript extension. Upstream builds
            # against nodejs-slim_22 and drags it into the closure; rebuild against
            # the system node (24+, current LTS) so only one node version is present.
            vtsls = pkgs.vtsls.override { nodejs-slim_22 = pkgs.nodejs-slim_24; };
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
              gcc # provides `cc` — nvim-treesitter compiles parsers with it
              git
              gnumake
              ghostscript # needed by snacks to render PDFs with the `gs` command
              imagemagick
              mermaid-cli # mmdc
              # nodejs is provided system-wide by node-runtime.nix (node 24 LTS)
              sqlite
              tree-sitter
              wget
              ;
          };
        in
        formatters ++ lsp-servers ++ linters ++ tools;
    }

  ;
}
