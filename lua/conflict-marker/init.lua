local const = require("conflict-marker.const")

local M = {}

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

---@param buf integer?
function M.check(buf)
    buf = buf or 0
    if buf == 0 then
        buf = vim.api.nvim_get_current_buf()
    end

    local conflict = 0
    vim.api.nvim_buf_call(buf, function()
        conflict = vim.fn.search(require("conflict-marker.config").config.markers.mid, "ncw")
    end)
    if conflict == 0 then
        return
    end

    local c = require("conflict-marker.Conflict"):new(buf)
    c:init()
    require("conflict-marker.config").config.on_attach(c)
end

---@param config conflict-marker.Config?
function M.setup(config)
    config = config or {}
    require("conflict-marker.config").config =
        vim.tbl_deep_extend("force", require("conflict-marker.config").config, config)

    local diff_add = vim.api.nvim_get_hl(0, { name = "DiffAdd", link = false })
    local diff_change = vim.api.nvim_get_hl(0, { name = "DiffChange", link = false })

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
end

return M
