local const = require("conflict-marker.const")

local augroup = vim.api.nvim_create_augroup("conflict-marker.nvim/plugin", {})

vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    callback = function(ev)
        require("conflict-marker").check(ev.buf)
    end,
})

local diff_add = vim.api.nvim_get_hl(0, { name = "DiffAdd", link = false })
local diff_change = vim.api.nvim_get_hl(0, { name = "DiffChange", link = false })

---@param color integer
---@param factor number
local function multiply_color(color, factor)
    local r = bit.rshift(bit.band(color, 0xFF0000), 4 * 4)
    local g = bit.rshift(bit.band(color, 0x00FF00), 2 * 4)
    local b = bit.band(color, 0x0000FF)

    r = math.min(math.floor(r * factor), 255)
    g = math.min(math.floor(g * factor), 255)
    b = math.min(math.floor(b * factor), 255)

    r = bit.band(bit.lshift(r, 4 * 4), 0xFF0000)
    g = bit.band(bit.lshift(g, 2 * 4), 0x00FF00)

    return bit.bor(r, g, b)
end

vim.api.nvim_set_hl(0, const.HL_CONFLICT_OURS_MARKER, {
    default = true,
    bold = true,
    bg = diff_change.bg and multiply_color(diff_change.bg, 0.8),
    fg = "LightGray",
})
vim.api.nvim_set_hl(0, const.HL_CONFLICT_OURS, {
    default = true,
    bg = diff_change.bg,
})

vim.api.nvim_set_hl(0, const.HL_CONFLICT_BASE_MARKER, {
    default = true,
    bold = true,
    fg = "LightGray",
})
vim.api.nvim_set_hl(0, const.HL_CONFLICT_BASE, {
    default = true,
})

vim.api.nvim_set_hl(0, const.HL_CONFLICT_MID, {
    default = true,
    bold = true,
    fg = "LightGray",
})

vim.api.nvim_set_hl(0, const.HL_CONFLICT_THEIRS, {
    default = true,
    bg = diff_add.bg,
})
vim.api.nvim_set_hl(0, const.HL_CONFLICT_THEIRS_MARKER, {
    default = true,
    bold = true,
    bg = diff_add.bg and multiply_color(diff_add.bg, 0.8),
    fg = "LightGray",
})
