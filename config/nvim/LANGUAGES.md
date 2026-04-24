# Language support matrix

Snapshot of every filetype's LSP, linter, and formatter in this Neovim
config. Source files referenced below are relative to `config/nvim/`.
Binaries are provisioned by `modules/home-manager/neovim/default.nix`
under `programs.neovim.extraPackages`.

LSP registration uses Neovim 0.11+'s native `vim.lsp.config` /
`vim.lsp.enable` — see `lua/config/lsp.lua`. Each server is configured
by a single file under `lsp/<name>.lua`; `vim.lsp.enable("<name>")`
resolves that file automatically.

## LSP servers

| Name            | Filetypes                                                | Binary                          | Config file               | Notes |
| --------------- | -------------------------------------------------------- | ------------------------------- | ------------------------- | ----- |
| `bash`          | sh, bash, zsh, .zshrc                                    | `bash-language-server`          | `lsp/bash.lua`            | `settings.bashIde.shellcheckPath = ""` disables its built-in shellcheck; efm owns shell lint. |
| `buf_ls`        | proto                                                    | `buf` (subcommand `beta lsp`)   | `lsp/buf_ls.lua`          | |
| `css`           | css, scss, less                                          | `vscode-css-language-server`    | `lsp/css.lua`             | `init_options.provideFormatter = true` (LSP formatting not used — filtered out on save). |
| `dockerfile`    | dockerfile                                               | `docker-langserver`             | `lsp/dockerfile.lua`      | |
| `efm`           | See [efm matrix](#efm-umbrella-lintformat) below         | `efm-langserver`                | `lsp/efm.lua`             | Umbrella wrapping CLI tools via `creativenull/efmls-configs-nvim`. Owns all format-on-save. |
| `gopls`         | go, gomod, gowork, gotmpl                                | `gopls`                         | `lsp/gopls.lua`           | |
| `html`          | html, templ                                              | `vscode-html-language-server`   | `lsp/html.lua`            | Embedded CSS + JS handled by the server. |
| `json`          | json, jsonc                                              | `vscode-json-language-server`   | `lsp/json.lua`            | No formatter wired — format-on-save is a no-op for JSON. |
| `luals`         | lua                                                      | `lua-language-server`           | `lsp/luals.lua`           | Libraries auto-discovered from `runtimepath`. |
| `nil_ls`        | nix                                                      | `nil`                           | `lsp/nil_ls.lua`          | `settings.formatting.command = { "nixfmt" }` — present but not used (efm owns format). |
| `rust_analyzer` | rust                                                     | `rust-analyzer`                 | `lsp/rust_analyzer.lua`   | |
| `tofu_ls`       | terraform, terraform-vars, opentofu, opentofu-vars       | `tofu-ls` (subcommand `serve`)  | `lsp/tofu_ls.lua`         | |
| `vtsls`         | javascript, javascriptreact, javascript.jsx, typescript, typescriptreact, typescript.tsx | `vtsls` | `lsp/vtsls.lua` | Inlay hints + workspace-local TS SDK. biome owns format, not vtsls. |
| `yaml`          | yaml, yaml.docker-compose                                | `yaml-language-server`          | `lsp/yaml.lua`            | Uses SchemaStore for schema validation. yamllint (via efm) owns style lint. |

Disabled but present: `lsp/terraform.lua` (commented out in
`lua/config/lsp.lua`; `tofu_ls` supersedes it).

Provisioned in Nix but not enabled: `pyright` (pull into
`vim.lsp.enable({...})` to activate). Python buffers currently get
format-only treatment via efm.

## efm umbrella (lint/format)

efm attaches on any filetype in this table and runs the listed tools.
Tool modules come from `creativenull/efmls-configs-nvim` (see
`lsp/efm.lua`). Project config column shows the files efm's
`rootMarkers` look for — when one is found, the tool is invoked from
that project root so its own config discovery kicks in.

| Filetype        | Linter (binary)               | Formatter (binary)                  | Project config (`rootMarkers`)                          |
| --------------- | ----------------------------- | ----------------------------------- | ------------------------------------------------------- |
| bash            | shellcheck (`shellcheck`)     | shfmt (`shfmt`)                     | `.editorconfig`                                         |
| dockerfile      | hadolint (`hadolint`)         | —                                   | `.hadolint.yaml`                                        |
| gitcommit       | gitlint (`gitlint`)           | —                                   | —                                                       |
| html            | —                             | prettier_d (`prettierd`)            | `.prettierrc*`, `prettier.config.*`                     |
| javascript      | —                             | biome (`biome`)                     | `biome.json`, `biome.jsonc`, `rome.json`                |
| javascriptreact | —                             | biome (`biome`)                     | `biome.json`, `biome.jsonc`, `rome.json`                |
| lua             | —                             | stylua (`stylua`)                   | `.stylua.toml`, `stylua.toml`                           |
| markdown        | markdownlint (`markdownlint`) | prettier_d (`prettierd`)            | `.prettierrc*`, `prettier.config.*`                     |
| nix             | —                             | nixfmt (`nixfmt`)                   | —                                                       |
| python          | —                             | isort → black (`isort`, `black`)    | `.isort.cfg`, `pyproject.toml`, `setup.cfg`, `setup.py` |
| rust            | —                             | rustfmt (`rustfmt`)                 | `rustfmt.toml`                                          |
| sh              | shellcheck (`shellcheck`)     | shfmt (`shfmt`)                     | `.editorconfig`                                         |
| typescript      | —                             | biome (`biome`)                     | `biome.json`, `biome.jsonc`, `rome.json`                |
| typescriptreact | —                             | biome (`biome`)                     | `biome.json`, `biome.jsonc`, `rome.json`                |
| xml             | —                             | xmllint (`xmllint`, from `libxml2`) | —                                                       |
| yaml            | yamllint (`yamllint`)         | yamlfmt (`yamlfmt`)                 | `.yamlfmt`, `.yamlfmt.yaml`, `.yamlfmt.yml`             |
| zsh             | shellcheck (`shellcheck`)     | shfmt (`shfmt`)                     | `.editorconfig`                                         |

Chained tools run in list order: python gets isort first (import
sorting), then black (format).

Entries prefixed `efm/` in diagnostic output come from the linter
column; entries with plain source names (e.g. `markdownlint`) come
from their respective tools' output format.

## Format-on-save

`lua/config/lsp.lua` registers a `BufWritePre` autocmd that calls
`vim.lsp.buf.format` with `filter = function(c) return c.name == "efm" end`.
Consequences:

- Only efm formats on save; other servers that advertise formatting
  capability (vtsls, rust-analyzer, gopls, lua-ls, css-ls, html-ls,
  nil_ls) never run their formatter via this hook.
- Filetypes absent from efm's language table (go, proto, terraform,
  json, etc.) don't auto-format. Manually invoke `<leader>cf` or
  `:lua vim.lsp.buf.format()` if needed.

The `<leader>cf` keymap (see `lua/config/keymaps.lua`) also filters to
efm, so manual and automatic format paths agree.

## Linter / formatter binaries in Nix

All binaries are installed via `programs.neovim.extraPackages` in
`modules/home-manager/neovim/default.nix`. They land on nvim's PATH
only — not the user's shell PATH — so `which shellcheck` from a normal
terminal returns nothing. Use `:!which <bin>` inside nvim, or
`vim.fn.exepath(<bin>)`, to confirm a binary is reachable by the
server.
