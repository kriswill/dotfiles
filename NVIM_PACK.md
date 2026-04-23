# Neovim migration: `lazy.nvim` → `vim.pack`

Context and implementation notes for the migration from the third-party
`lazy.nvim` plugin manager to Neovim 0.12's built-in `vim.pack`. Branch:
`lazynvim-to-pack`.

## Why

- Neovim 0.12 ships a native plugin manager (`vim.pack`).
- LSP was already native (`vim.lsp.config/enable` — no `nvim-lspconfig`,
  no `mason`), so `lazy.nvim` was the last third-party orchestrator.
- Dropping `lazy.nvim` removes a bootstrap step and a lockfile.

## `vim.pack` in one paragraph

- `vim.pack.add(specs, { load = false, confirm = true })` — clones
  missing plugins into `stdpath("data")/site/pack/core/opt/<name>/`.
  `load = false` runs `:packadd!` (adds to `runtimepath` without
  sourcing `plugin/`); `load = true` runs `:packadd` (sources them).
- Spec: `{ src = "https://...", name = "...", version = <branch|tag|commit|vim.version.range> }`.
  Globs like `"*"` are **not** valid — must be a concrete ref.
- No lockfile. No `event`/`ft`/`cmd`/`keys`/`priority`/`build` fields.
- Load order = order in the spec list.
- `User PackChanged` autocmd fires after install/update/delete with
  `{ kind, spec, path }`.

## Architecture

```
config/nvim/
├── init.lua                     # require("config")
├── lua/config/
│   ├── init.lua                 # loads: util, options, keymaps,
│   │                            # transparency, pack, plugins,
│   │                            # functions, lsp
│   ├── pack.lua                 # trigger helpers (see below)
│   ├── plugins.lua              # ordered dispatcher
│   └── lsp.lua                  # unchanged — vim.lsp.enable({...})
├── lua/plugins/
│   └── <name>.lua               # one spec per plugin
└── lsp/<server>.lua             # unchanged — one file per LSP server
```

### `lua/config/pack.lua`

Thin helpers around `vim.pack.add`. Each plugin's spec file is returned
as a Lua table and dispatched to one of:

| Trigger              | Behaviour                                                     |
| -------------------- | ------------------------------------------------------------- |
| `"now"`              | `vim.pack.add(...)`, run `setup()` immediately.               |
| `"later"`            | Add at startup, defer `setup()` to a one-shot `UIEnter` autocmd. |
| `{ ft = ... }`       | `vim.pack.add(..., { load = false })`. `setup()` runs on first matching `FileType`. Also triggers immediately if a buffer of that filetype is already open (argv file). |
| `{ cmd = ... }`      | Stub user commands; first invocation loads the plugin and re-runs the command. |
| `{ keys = ... }`     | Stub keymaps; first press loads the plugin and re-feeds the key. |

### Plugin spec shape

```lua
return {
  src = "https://github.com/owner/repo",
  name = "repo",                  -- optional; defaults to repo basename
  version = nil,                  -- optional; branch | tag | commit | vim.version.range
  trigger = "now",                -- see table above
  deps = { { src = "..." } },     -- optional; added to vim.pack.add list before the main src
  setup = function() ... end,     -- replaces lazy.nvim's config/opts/init
}
```

Plain files under `lua/plugins/` with dotted names break Lua's
`require` (dots are path separators), so `oil.nvim.lua`, `blink.cmp.lua`,
`lazydev.nvim.lua`, `mini.splitjoin.lua` were renamed to hyphenated
forms (`oil-nvim.lua`, etc.).

### `lua/config/plugins.lua`

An ordered list of module names under `lua/plugins/`. Dispatches each
to `pack.now/later/on_ft/on_cmd/on_keys` via `pack.dispatch()`. Order
matters: kanagawa first, snacks second, treesitter before
treesitter-textobjects.

## Plugin inventory

| Plugin                      | Trigger              | Notes |
| --------------------------- | -------------------- | ----- |
| kanagawa                    | `now`                | loaded first so colours are ready |
| snacks.nvim                 | `now`                | was `priority = 1000` under lazy — just place it early |
| nvim-highlight-colors       | `now`                | |
| lualine + lualine-so-fancy  | `now`                | dep added in spec |
| oil.nvim + mini.icons       | `now`                | dep added in spec |
| blink.cmp + friendly-snippets | `now`              | `version = vim.version.range("1.*")` |
| nvim-treesitter             | `now`                | main branch (see below) |
| nvim-treesitter-textobjects | `now`                | main branch |
| nvim-treesitter-context     | `later`              | deferred to UIEnter |
| gitsigns, schemastore, fidget, vim-sleuth | `now`  | split out of old `lua/plugins/init.lua` |
| baleia                      | `now`                | plan had `version = "*"`; vim.pack rejects globs — unpinned |
| direnv.nvim, tmux-navigation, AdvancedNewFile, colorful-winsep, mini.splitjoin, conform | `now` | |
| which-key                   | `later`              | |
| lazydev                     | `{ ft = "lua" }`     | |
| nvim-dap + dap-ui + dap-go + nvim-nio | `{ keys = ... }` | stub keymaps; first press loads |

Removed: `lazy-lock.json` (no replacement), `config/lazy.lua`,
`plugins/init.lua` (grouped entries moved to individual files),
`plugins/tiny-inline-diagnostic.lua` and `plugins/mini.statusline.lua`
(both fully commented out upstream).

## `nvim-treesitter` main-branch migration

Upstream's `HEAD` branch is now `main`, a full rewrite that removes
`nvim-treesitter.configs` and the `highlight/indent/ensure_installed`
setup table. The config adopts the new API rather than pinning to the
legacy `master` branch.

- Parser install: `require("nvim-treesitter").install({...})` (async).
  No-op for already-installed parsers.
- Highlight + indent: enabled per-filetype via a `FileType` autocmd:
  ```lua
  pcall(vim.treesitter.start, args.buf)
  vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  ```
- Textobjects: `nvim-treesitter-textobjects.select.select_textobject(query, group)`
  and `.swap.swap_next/previous`, wired as explicit `vim.keymap.set` calls.
  The old `keymaps = {...}` table form inside `configs.setup` is gone.
- Plugin README: *"This plugin does not support lazy-loading"* — so
  `trigger = "now"` stays.
- `:TSUpdate` is still provided by the plugin; the `PackChanged` hook
  runs it after install/update of `nvim-treesitter`.

### Dropped feature

Incremental selection (`<Enter>` to grow, `<Backspace>` to shrink)
is gone — not in the main branch and not built into Neovim 0.12. Can
be reimplemented in ~30 lines using `vim.treesitter.get_node():parent()`
if wanted.

## Nix changes

`modules/home-manager/neovim/default.nix` — dropped the
`"nvim/lazy-lock.json".source` symlink line. No change needed to
`programs.neovim.extraPackages` (LSP servers + formatters still provided
by Nix; `vim.pack` writes into `~/.local/share/nvim/site/pack/core/opt/`
which is outside the Nix store).

## Dashboard footer

The snacks dashboard footer used `require("lazy.stats")` for the
"loaded N/M plugins in Xms" line. Rewritten to use `vim.pack.get()`:

```
⚡ Neovim v0.12.1 with 29 plugins
```

Startup time display dropped — no equivalent metric is exposed by
`vim.pack`.

## Testing commands

All tests were run headlessly and gated on `:messages` for error
surfacing. `defer_fn(…, ms)` waits long enough for async work
(parsers compiling, `UIEnter` firing, etc.) before inspecting state.

**Confirm Neovim version**

```sh
nvim --version | head -1
```

**Clean startup — check for load errors**

```sh
nvim --headless \
  -c 'lua vim.defer_fn(function()
    local msgs = vim.api.nvim_exec2("messages", {output=true}).output
    print(msgs == "" and "CLEAN" or ("ERRORS:\n" .. msgs))
    vim.cmd("qa!")
  end, 1500)' 2>&1 | tail -5
```

**List plugins `vim.pack` knows about**

```sh
nvim --headless -c 'lua vim.defer_fn(function()
  local p = vim.pack.get()
  local names = {}
  for _, s in ipairs(p) do table.insert(names, s.spec.name) end
  print("count:", #names)
  print(table.concat(names, "\n"))
  vim.cmd("qa!")
end, 1500)' 2>&1 | tail -40
```

**Inspect a single plugin's record (path, rev, branches, tags)**

```sh
nvim --headless -c 'lua vim.defer_fn(function()
  for _, s in ipairs(vim.pack.get()) do
    if s.spec.name == "which-key.nvim" then print(vim.inspect(s)) end
  end
  vim.cmd("qa!")
end, 1500)' 2>&1 | tail -20
```

**Simulate `UIEnter` — flushes `later` plugins**

```sh
nvim --headless -c 'doautocmd UIEnter' \
  -c 'lua vim.defer_fn(function()
    local msgs = vim.api.nvim_exec2("messages", {output=true}).output
    print(msgs == "" and "CLEAN" or ("MSGS:\n" .. msgs))
    vim.cmd("qa!")
  end, 2000)' 2>&1 | tail -10
```

**Confirm a `later` plugin's `setup()` did NOT fire at startup**

```sh
nvim --headless -c 'lua vim.defer_fn(function()
  local wk = require("which-key")
  print("wk.config populated:", wk.config ~= nil)
  vim.cmd("qa!")
end, 300)' 2>&1 | tail -3
# expect: wk.config populated: false
```

**Confirm a `ft` plugin loads when the target filetype is open**

```sh
nvim --headless /Users/k/src/dotfiles/config/nvim/init.lua \
  -c 'lua vim.defer_fn(function()
    local cfg = require("lazydev.config")
    print("lazydev.config loaded:", cfg ~= nil and cfg.library ~= nil)
    vim.cmd("qa!")
  end, 800)' 2>&1 | tail -3
# expect: lazydev.config loaded: true
```

**Confirm a `keys` plugin is NOT in runtimepath until a key is pressed**

```sh
nvim --headless -c 'lua vim.defer_fn(function()
  local rtp = vim.o.runtimepath
  print("nvim-dap in rtp at startup:", rtp:find("/nvim%-dap/") ~= nil)
  local km = vim.api.nvim_get_keymap("n")
  local has_stub = false
  for _, k in ipairs(km) do if k.lhs == " dc" then has_stub = true end end
  print("stub <leader>dc installed:", has_stub)
  vim.cmd("qa!")
end, 300)' 2>&1 | tail -5
# expect: in rtp: false; stub installed: true
```

**Verify LSP attaches when opening a file**

```sh
nvim --headless /path/to/file.lua \
  -c 'lua vim.defer_fn(function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    local names = {}
    for _, c in ipairs(clients) do table.insert(names, c.name) end
    print("LSP clients:", table.concat(names, ", "))
    vim.cmd("qa!")
  end, 3000)' 2>&1 | tail -3
```

**Verify treesitter highlight + indent on a buffer**

```sh
nvim --headless /path/to/file.lua \
  -c 'lua vim.defer_fn(function()
    local active = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
    print("TS highlighter active:", active ~= nil)
    print("indentexpr:", vim.bo.indentexpr)
    vim.cmd("qa!")
  end, 500)' 2>&1 | tail -3
```

**Flake evaluates**

```sh
nix build .#darwinConfigurations.k.system --no-link
```

**Apply home-manager (needs sudo; removes the `lazy-lock.json` symlink)**

```sh
sudo darwin-rebuild switch --flake .
```

## Pending

- Run `sudo darwin-rebuild switch --flake .` to remove the
  `~/.config/nvim/lazy-lock.json` symlink.
- After that succeeds: `rm config/nvim/lazy-lock.json` from the repo.
- Optional (deferred from original plan): evaluate
  `creativenull/efmls-configs-nvim` as a linter/formatter source via
  `efm-langserver`. Conform still handles format-on-save; this would
  only be needed to add linting on filetypes without a dedicated LSP.
