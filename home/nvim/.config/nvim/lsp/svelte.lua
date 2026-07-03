---@type vim.lsp.Config
return {
  cmd = { "svelteserver", "--stdio" },
  filetypes = { "svelte" },
  root_markers = { "svelte.config.js", "svelte.config.mjs", "svelte.config.ts", "package.json", ".git" },
}
