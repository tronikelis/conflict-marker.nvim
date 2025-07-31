local utils = require("conflict-marker.utils")

local M = {}

local CONFLICT_START = "^<<<<<<<"
local CONFLICT_END = "^>>>>>>>"
local CONFLICT_MID = "^=======$"
local CONFLICT_BASE = "^|||||||"

local HL_CONFLICT_OURS_MARKER = "ConflictOursMarker"
local HL_CONFLICT_OURS = "ConflictOurs"
local HL_CONFLICT_THEIRS = "ConflictTheirs"
local HL_CONFLICT_THEIRS_MARKER = "ConflictTheirsMarker"
local HL_CONFLICT_MID = "ConflictMid"

local HL_CONFLICT_BASE_MARKER = "ConflictBaseMarker"
local HL_CONFLICT_BASE = "ConflictBase"

local CONFLICT_NS = "ns_conflict-marker.nvim"

---@class conflict-marker.Config
---@field on_attach fun(arg: conflict-marker.Conflict)
---@field highlights boolean
M.config = {
    highlights = true,
    on_attach = function() end,
}

---@class conflict-marker.Conflict
---@field bufnr integer
---@field ns integer
local Conflict = {}

---@param bufnr integer
---@return conflict-marker.Conflict
function Conflict:new(bufnr)
    ---@type conflict-marker.Conflict
    local obj = {
        bufnr = bufnr,
        ns = vim.api.nvim_create_namespace(CONFLICT_NS),
    }
    setmetatable(obj, { __index = self })

    return obj
end

function Conflict:apply_hl()
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    while true do
        local start, base, mid, ending = 0, 0, 0, 0
        self:in_buf(function()
            start = vim.fn.search(CONFLICT_START, "cW")
            base = vim.fn.search(CONFLICT_BASE, "cW")
            mid = vim.fn.search(CONFLICT_MID, "cW")
            ending = vim.fn.search(CONFLICT_END, "cW")
        end)

        if start == 0 or mid == 0 or ending == 0 then
            break
        end

        local base_delta = 0
        if base ~= 0 then
            base_delta = mid - base
        end

        self:apply_line_highlight(start - 1, start, HL_CONFLICT_OURS_MARKER, "(Our changes)")
        self:apply_line_highlight(start, mid - base_delta - 1, HL_CONFLICT_OURS)

        if base ~= 0 then
            self:apply_line_highlight(base - 1, base, HL_CONFLICT_BASE_MARKER, "(Base)")
            self:apply_line_highlight(base, mid - 1, HL_CONFLICT_BASE)
        end

        self:apply_line_highlight(mid - 1, mid, HL_CONFLICT_MID)

        self:apply_line_highlight(mid, ending - 1, HL_CONFLICT_THEIRS)
        self:apply_line_highlight(ending - 1, ending, HL_CONFLICT_THEIRS_MARKER, "(Theirs changes)")
    end

    vim.api.nvim_win_set_cursor(0, cursor)
end

---@param start integer
---@param ending integer
---@param group string
---@param virt_text? string
function Conflict:apply_line_highlight(start, ending, group, virt_text)
    if virt_text then
        vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, start, 0, {
            invalidate = true,
            virt_text = { { virt_text } },
            hl_mode = "combine",
        })
    end

    vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, start, 0, {
        end_row = ending,
        end_col = 0,
        hl_eol = true,
        hl_group = group,
        priority = vim.hl.priorities.user - 1,
    })
end

function Conflict:init()
    if M.config.highlights then
        vim.api.nvim_win_set_hl_ns(0, self.ns)

        --- default diff hl interferes heavily,
        --- so there is no point in keeping them
        for _, v in ipairs({
            "DiffAdd",
            "DiffChange",
            "DiffDelete",
            "DiffText",
        }) do
            vim.api.nvim_set_hl(self.ns, v, {})
        end

        self:apply_hl()
    end

    local choice_map = {
        ours = function()
            self:choose_ours()
        end,
        theirs = function()
            self:choose_theirs()
        end,
        both = function()
            self:choose_both()
        end,
        none = function()
            self:choose_none()
        end,
    }

    vim.api.nvim_buf_create_user_command(self.bufnr, "Conflict", function(ev)
        local choice = choice_map[ev.fargs[1]]
        if not choice then
            print("unknown command")
            return
        end

        choice()
    end, {
        nargs = 1,
        complete = function(query)
            return vim.iter(vim.tbl_keys(choice_map))
                :filter(function(x)
                    return x:sub(1, #query) == query
                end)
                :totable()
        end,
    })
end

---@param fn fun()
function Conflict:in_buf(fn)
    vim.api.nvim_buf_call(self.bufnr, fn)
end

---returns [down, up] lines
---@param pattern  string
---@return integer, integer
function Conflict:two_way_search(pattern)
    local down, up = 0, 0

    self:in_buf(function()
        down = vim.fn.search(pattern, "cnbW")
        up = vim.fn.search(pattern, "cnW")
    end)

    return down, up
end

---@return integer?, integer?
function Conflict:conflict_range()
    local from, to = 0, 0
    local in_range = true

    self:in_buf(function()
        from = vim.fn.search(CONFLICT_START, "cnbW")
        to = vim.fn.search(CONFLICT_END, "cnW")
    end)

    if from == 0 or to == 0 then
        return
    end

    self:in_buf(function()
        -- don't accept cursor pos
        local up_end = vim.fn.search(CONFLICT_END, "nbW")
        if up_end == 0 then
            return
        end

        -- if conflict end is above conflict start
        if up_end > from then
            in_range = false
        end
    end)

    if not in_range then
        return
    end

    return from, to
end

function Conflict:choose_ours()
    local from, to = self:conflict_range_without_base()
    if not from or not to then
        return
    end

    local start = utils.target_in_range(from, to, self:two_way_search(CONFLICT_START))
    local mid = utils.target_in_range(from, to, self:two_way_search(CONFLICT_MID))
    if not start or not mid then
        return
    end

    vim.api.nvim_buf_set_lines(self.bufnr, start - 1, start, true, {})
    -- offset by -1 because we deleted one line above
    vim.api.nvim_buf_set_lines(self.bufnr, mid - 2, to - 1, true, {})
end

function Conflict:choose_theirs()
    local from, to = self:conflict_range_without_base()
    if not from or not to then
        return
    end

    local mid = utils.target_in_range(from, to, self:two_way_search(CONFLICT_MID))
    local ending = utils.target_in_range(from, to, self:two_way_search(CONFLICT_END))
    if not mid or not ending then
        return
    end

    vim.api.nvim_buf_set_lines(self.bufnr, ending - 1, ending, true, {})
    vim.api.nvim_buf_set_lines(self.bufnr, from - 1, mid, true, {})
end

---@return integer?, integer?
function Conflict:conflict_range_without_base()
    local from, to = self:conflict_range()
    if not from or not to then
        return
    end

    local base = utils.target_in_range(from, to, self:two_way_search(CONFLICT_BASE))
    if not base then
        return from, to
    end

    local mid = utils.target_in_range(from, to, self:two_way_search(CONFLICT_MID))
    if not mid then
        return
    end

    vim.api.nvim_buf_set_lines(self.bufnr, base - 1, mid - 1, true, {})

    to = to - (mid - base)

    return from, to
end

function Conflict:choose_both()
    local from, to = self:conflict_range_without_base()
    if not from or not to then
        return
    end

    local start = utils.target_in_range(from, to, self:two_way_search(CONFLICT_START))
    local mid = utils.target_in_range(from, to, self:two_way_search(CONFLICT_MID))
    local ending = utils.target_in_range(from, to, self:two_way_search(CONFLICT_END))
    if not start or not mid or not ending then
        return
    end

    -- loop reverse, so I don't need to do - i
    for _, v in ipairs({ ending, mid, start }) do
        vim.api.nvim_buf_set_lines(self.bufnr, v - 1, v, true, {})
    end
end

function Conflict:choose_none()
    local from, to = self:conflict_range_without_base()
    if not from or not to then
        return
    end

    vim.api.nvim_buf_set_lines(self.bufnr, from - 1, to, true, {})
end

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

---@param config conflict-marker.Config?
function M.setup(config)
    config = config or {}
    M.config = vim.tbl_deep_extend("force", M.config, config)

    -- not using a link because these groups will be deleted in the namespace
    local diff_add = vim.api.nvim_get_hl(0, { name = "DiffAdd" })
    local diff_change = vim.api.nvim_get_hl(0, { name = "DiffChange" })

    vim.api.nvim_set_hl(0, HL_CONFLICT_OURS_MARKER, {
        default = true,
        bold = true,
        bg = multiply_color(diff_change.bg, 1.4),
        fg = "LightGray",
    })
    vim.api.nvim_set_hl(0, HL_CONFLICT_OURS, {
        default = true,
        bg = diff_change.bg,
    })

    vim.api.nvim_set_hl(0, HL_CONFLICT_BASE_MARKER, {
        default = true,
        bold = true,
        fg = "LightGray",
    })
    vim.api.nvim_set_hl(0, HL_CONFLICT_BASE, {
        default = true,
    })

    vim.api.nvim_set_hl(0, HL_CONFLICT_MID, {
        default = true,
        bold = true,
        fg = "LightGray",
    })

    vim.api.nvim_set_hl(0, HL_CONFLICT_THEIRS, {
        default = true,
        bg = multiply_color(diff_add.bg, 0.6),
    })
    vim.api.nvim_set_hl(0, HL_CONFLICT_THEIRS_MARKER, {
        default = true,
        bold = true,
        bg = multiply_color(diff_add.bg, 0.7),
        fg = "LightGray",
    })

    ---@param bufnr integer
    local function check_file(bufnr)
        local conflict = 0

        vim.api.nvim_buf_call(bufnr, function()
            conflict = vim.fn.search(CONFLICT_MID, "nc")
        end)

        if conflict == 0 then
            return
        end

        local c = Conflict:new(bufnr)
        c:init()
        M.config.on_attach(c)
    end

    -- if we were lazy loaded
    if vim.api.nvim_buf_is_loaded(0) then
        local bufnr = vim.api.nvim_get_current_buf()
        check_file(bufnr)
    end

    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function(ev)
            check_file(ev.buf)
        end,
    })
end

return M
