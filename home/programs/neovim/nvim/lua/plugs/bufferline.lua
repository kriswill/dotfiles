local bufferline = require('bufferline')
bufferline.setup({
  options = {
    mode = 'buffers',
    style_preset = { bufferline.style_preset.minimal },
    sort_by = 'insert_after_current',
    move_wraps_at_ends = true,
    indicator = { style = 'underline' },
    show_close_icon = false,
    hover = { enabled = true, reveal = { 'close' } },
    groups = {
      options = { toggle_hidden_on_enter = true },
      items = {
        bufferline.groups.builtin.pinned:with({ icon = '' }),
        bufferline.groups.builtin.ungrouped,
        {
          name = 'docs',
          icon = '',
          matcher = function(buf)
            if vim.bo[buf.id].filetype == 'man' or buf.path:match('man://') then return true end
            for _, ext in ipairs({ 'md', 'txt', 'org', 'norg', 'wiki' }) do
              if ext == vim.fn.fnamemodify(buf.path, ':e') then return true end
            end
          end,
        },
      },
    },
  },
})

map('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Cycle to next buffer' })
map('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Cycle to previous buffer' })
map('n', '<leader>bd', '<cmd>bdelete<cr>', {desc = 'Delete Buffer'})
map('n', '<leader>bb', '<cmd>e #<cr>', {desc = 'Switch to Other Buffer'})
map('n', '<leader>br', '<cmd>BufferLineCloseRight<cr>', {desc = 'Delete buffers to the right'})
map('n', '<leader>bl', '<cmd>BufferLineCloseLeft<cr>', {desc = 'Delete buffers to the left'})
map('n', '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', {desc = 'Delete other buffers'})
map('n', '<leader>bp', '<cmd>BufferLineTogglePin<cr>', { desc = 'Toggle pin' })
map('n', '<leader>bP', '<cmd>BufferLineGroupClose ungrouped<cr>',{ desc = 'Delete non-pinned buffers' })

