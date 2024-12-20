{ inputs, pkgs, ... }:
let
  neovim = inputs.gman-nvim.homeManagerModule.default;
in

{
  imports = [ neovim ];
  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      lualine-nvim
    ];
    extraLuaConfig = ''
      print("append a line")
    '';
  };
  xdg.configFile = {
    "nvim/lua/core/keymap.lua".source = ./nvim/lua/core/keymaps.lua;
  };
}
# with pkgs; {
# programs.neovim = {
#     enable = true;
#     package = neovim-unwrapped;
#
#     vimAlias = true;
#     viAlias = true;
#     vimdiffAlias = true;
#
#     plugins = with vimPlugins; [
#       alpha-nvim
#       bufferline-nvim
#       catppuccin-nvim
#       cmp-buffer
#       cmp-nvim-lsp
#       cmp-path
#       cmp-spell
#       cmp-treesitter
#       cmp-vsnip
#       fidget-nvim # https://github.com/j-hui/fidget.nvim
#       # friendly-snippets
#       gitsigns-nvim
#       #lightline-vim
#       lsp-format-nvim
#       lspkind-nvim
#       lualine-nvim
#       # neogit
#       none-ls-nvim
#       nvim-autopairs
#       nvim-cmp
#       nvim-colorizer-lua
#       nvim-dap
#       nvim-dap-ui
#       nvim-lspconfig
#       nvim-tree-lua
#       (nvim-treesitter.withPlugins (p: with p; [
#         bash
#         c cpp
#         dockerfile
#         go
#         gomod
#         html
#         javascript
#         json jsonc
#         lua
#         make
#         markdown
#         nix
#         python
#         rust
#         sql
#         toml
#         typescript
#         vim
#         yaml
#         zig
#       ])) 
#       plenary-nvim
#       rainbow-delimiters-nvim
#       telescope-fzy-native-nvim
#       telescope-nvim
#       which-key-nvim
#     ];
#
#     extraPackages = [ 
#       nil
#       gcc 
#       ripgrep
#       fd
#     ];
#
#     # extraConfig =
#     #   let
#     #     luaRequire = module:
#     #       builtins.readFile (builtins.toString
#     #         ./config
#     #       + "/${module}.lua");
#     #     luaConfig = builtins.concatStringsSep "\n" (map luaRequire [
#     #       "init"
#     #       "lspconfig"
#     #       "nvim-cmp"
#     #       "theming"
#     #       "treesitter"
#     #       "treesitter-textobjects"
#     #       "utils"
#     #       "which-key"
#     #     ]);
#     #   in
#     #   ''
#     #     lua << 
#     #     ${luaConfig}
#     #     
#     #   '';
#   };
# } // (
# let
#   # used to link files to .config/nvim/* 
#   nvimDir = config.home.homeDirectory + "/src/dotfiles/home/programs/neovim/nvim";
#   ln = config.lib.file.mkOutOfStoreSymlink;
# in
# {
#   xdg.configFile = {
#     "nvim/lua".source = ln nvimDir + "/lua";
#     "nvim/ftplugin".source = ln nvimDir + "/ftplugin";
#     "nvim/init.lua".text = /*lua*/''
#       -- Globals
#       _G.map = vim.keymap.set
#       _G.P = vim.print
#
#       -- load my customizations
#       require("core.util")
#       require("core.options")
#       require("core.keymaps")
#       require("ui.theme")
#       require("lsp")
#       require("plugs")
#     '';
#   };
# })
