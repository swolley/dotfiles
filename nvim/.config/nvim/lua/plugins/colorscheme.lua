-- Replace LazyVim's Catppuccin with soft noctalia green (base16).
local palette = require("noctalia.palette")

local function apply_noctalia()
  require("base16-colorscheme").setup({
    base00 = palette.base, -- Default background
    base01 = palette.surface, -- Lighter background / status
    base02 = palette.surface2, -- Selection background
    base03 = palette.muted, -- Comments, invisibles
    base04 = "#9aa29c", -- Dark foreground
    base05 = palette.text, -- Default foreground
    base06 = "#e8ebe8", -- Light foreground
    base07 = palette.bright, -- Lightest foreground
    base08 = palette.urgent, -- Variables, errors
    base09 = palette.rose, -- Integers, constants
    base0A = palette.yellow, -- Classes, search
    base0B = palette.accent, -- Strings, diff insert
    base0C = palette.teal, -- Regex, escapes
    base0D = palette.accent_bright, -- Functions, methods
    base0E = palette.accent_dim, -- Keywords, storage
    base0F = palette.urgent, -- Deprecated
  })
  vim.g.colors_name = "noctalia-green"
end

return {
  { "catppuccin/nvim", enabled = false },
  {
    "folke/tokyonight.nvim",
    enabled = false,
  },
  {
    "RRethy/base16-nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = apply_noctalia,
    },
  },
}
