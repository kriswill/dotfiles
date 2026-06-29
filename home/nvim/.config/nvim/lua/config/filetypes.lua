-- Map a shebang interpreter (basename) to a filetype. Lets extensionless
-- scripts (e.g. `#!/usr/bin/env bun` tools) get a real filetype, which is what
-- drives LSP attach + treesitter. bun/deno/tsx/ts-node default to typescript
-- (a superset — vtsls/treesitter handle plain JS in a .ts buffer fine).
local shebang_ft = {
  bun = "typescript",
  deno = "typescript",
  tsx = "typescript",
  ["ts-node"] = "typescript",
  node = "javascript",
}

-- Pull the interpreter basename out of a shebang line, handling
-- `#!/usr/bin/env [-S] <interp> [args]` and `#!/abs/path/<interp> [args]`.
local function shebang_interp(line)
  local rest = line:match("^#!%s*(%S.*)$")
  if not rest then
    return nil
  end
  local argv = {}
  for w in rest:gmatch("%S+") do
    argv[#argv + 1] = w
  end
  local i = 1
  if argv[i] and argv[i]:match("env$") then -- /usr/bin/env …
    i = i + 1
    while argv[i] and argv[i]:sub(1, 1) == "-" do -- skip -S and other flags
      i = i + 1
    end
  end
  return argv[i] and argv[i]:match("([^/]+)$") or nil -- basename of interpreter
end

vim.filetype.add({
  extension = {
    gotmpl = "gotmpl",
    templ = "templ",
    tfvars = "terraform-vars",
  },
  filename = {
    ["go.work"] = "gowork",
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
  },
  pattern = {
    -- Extensionless files: resolve filetype from the shebang. Guarded to
    -- extensionless paths so real extensions detect normally; low priority so
    -- any explicit rule still wins.
    --
    -- The key is the catch-all `".+"` rather than `".*"` on purpose:
    -- `vim.filetype.add` overwrites patterns by key, and snacks.nvim's bigfile
    -- feature already claims `".*"`. Using a distinct (but equally catch-all)
    -- key lets both coexist — snacks returns nil for normal files, then this runs.
    [".+"] = {
      function(path, bufnr)
        if vim.fn.fnamemodify(path, ":e") ~= "" then
          return nil
        end
        local first = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]
        if not first then
          return nil
        end
        local interp = shebang_interp(first)
        return interp and shebang_ft[interp] or nil
      end,
      { priority = -10 },
    },
  },
})
