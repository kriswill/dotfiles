---@brief
---
--- [OpenTofu Language Server](https://github.com/opentofu/tofu-ls)
---

---@type vim.lsp.Config
return {
  cmd = { "tofu-ls", "serve" },
  filetypes = { "terraform", "terraform-vars", "opentofu", "opentofu-vars" },
  root_markers = { ".terraform", ".git" },
}
