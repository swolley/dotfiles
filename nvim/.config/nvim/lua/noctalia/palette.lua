-- Soft noctalia green palette shared with kitty / starship / tmux.
-- The values below are the fallback: noctalia generates the same table from the
-- shared palette in ~/.cache/noctalia/nvim-palette.lua (template in the dotfiles:
-- noctalia/.config/noctalia/templates/nvim-palette.lua) and it takes precedence.
local defaults = {
  base = "#1c1c1e",
  surface = "#2a2b2e",
  surface2 = "#3a3b3e",
  muted = "#7a827c",
  text = "#d8ddd9",
  bright = "#ffffff",
  accent = "#8fbf98",
  accent_bright = "#a8d0b0",
  accent_dim = "#6b8070",
  teal = "#7eb8b0",
  yellow = "#c6a26e",
  urgent = "#ffb4ab",
  rose = "#c4a7a0",
}

local cache = (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")) .. "/noctalia/nvim-palette.lua"
local ok, generated = pcall(dofile, cache)
if ok and type(generated) == "table" then
  return vim.tbl_extend("force", defaults, generated)
end
return defaults
