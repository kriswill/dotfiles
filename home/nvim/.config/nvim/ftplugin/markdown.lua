-- Markdown specific settings
vim.opt.wrap = true -- Wrap text
vim.opt.breakindent = true -- Match indent on line break
vim.opt.linebreak = true -- Line break on whole words

-- Allow j/k when navigating wrapped lines
vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

-- Spell check
vim.opt.spelllang = 'en_us'
vim.opt.spell = true
-- Words added with `zg` land in the repo (editable without a rebuild) so they
-- stay version-controlled. The compiled .spl is regenerated and git-ignored.
vim.opt.spellfile = vim.fn.expand('~/src/dotfiles/config/nvim/spell/en.utf-8.add')
