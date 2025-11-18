local constants = require("conflict-marker.constants")

local augroup = vim.api.nvim_create_augroup("conflict-marker.nvim/setup", {})

vim.api.nvim_set_decoration_provider(constants.NS, {
    on_win = function(_, win, buf, win_start, win_end)
        local conflict = vim.b[buf].__conflict
        if not conflict then
            return false
        end

        require("conflict-marker.Conflict"):add_meta(conflict):refresh_hl(win, win_start + 1, win_end + 1)
    end,
})

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

local diff_add = vim.api.nvim_get_hl(0, { name = "DiffAdd", link = false })
local diff_change = vim.api.nvim_get_hl(0, { name = "DiffChange", link = false })

vim.api.nvim_set_hl(0, constants.HL_CONFLICT_OURS_MARKER, {
    default = true,
    bold = true,
    bg = diff_change.bg and multiply_color(diff_change.bg, 0.8),
    fg = "LightGray",
})
vim.api.nvim_set_hl(0, constants.HL_CONFLICT_OURS, {
    default = true,
    bg = diff_change.bg,
})

vim.api.nvim_set_hl(0, constants.HL_CONFLICT_BASE_MARKER, {
    default = true,
    bold = true,
    fg = "LightGray",
})
vim.api.nvim_set_hl(0, constants.HL_CONFLICT_BASE, {
    default = true,
})

vim.api.nvim_set_hl(0, constants.HL_CONFLICT_MID, {
    default = true,
    bold = true,
    fg = "LightGray",
})

vim.api.nvim_set_hl(0, constants.HL_CONFLICT_THEIRS, {
    default = true,
    bg = diff_add.bg,
})
vim.api.nvim_set_hl(0, constants.HL_CONFLICT_THEIRS_MARKER, {
    default = true,
    bold = true,
    bg = diff_add.bg and multiply_color(diff_add.bg, 0.8),
    fg = "LightGray",
})

---@param bufnr integer
local function check_file(bufnr)
    local conflict = 0

    vim.api.nvim_buf_call(bufnr, function()
        conflict = vim.fn.search(constants.CONFLICT_MID, "ncw")
    end)

    if conflict == 0 then
        return
    end

    local c = require("conflict-marker.Conflict"):new(bufnr)
    c:init(vim.api.nvim_get_current_win())

    vim.b[bufnr].__conflict = c
    require("conflict-marker").config.on_attach(c)
end

-- if we were lazy loaded
if vim.api.nvim_buf_is_loaded(0) then
    local bufnr = vim.api.nvim_get_current_buf()
    check_file(bufnr)
end

vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    callback = function(ev)
        check_file(ev.buf)
    end,
})
