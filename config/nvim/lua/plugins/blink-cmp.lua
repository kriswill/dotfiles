return {
  src = "https://github.com/saghen/blink.cmp",
  version = vim.version.range("1.*"),
  trigger = "now",
  deps = {
    { src = "https://github.com/rafamadriz/friendly-snippets" },
  },
  setup = function()
    require("blink.cmp").setup({
      keymap = { preset = "super-tab" },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true } },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
        },
      },
    })
  end,
}
