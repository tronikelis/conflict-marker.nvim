local const = require("conflict-marker.const")
local utils = require("conflict-marker.utils")
local config = require("conflict-marker.config")

local NS_HL = vim.api.nvim_create_namespace("conflict-marker.nvim/hl")

---@class conflict-marker.Conflict
---@field bufnr integer
local Conflict = {}

---@param bufnr integer
---@return conflict-marker.Conflict
function Conflict:new(bufnr)
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    ---@type conflict-marker.Conflict
    local obj = {
        bufnr = bufnr,
    }
    setmetatable(obj, { __index = self })

    return obj
end

function Conflict:with_cursor_in_conflict_region(fn)
    local cursor = vim.fn.getpos(".")
    local extmarks = vim.api.nvim_buf_get_extmarks(
        self.bufnr,
        NS_HL,
        { cursor[2] - 1, 0 },
        { cursor[2] - 1, 0 },
        { overlap = true }
    )

    if #extmarks ~= 0 then
        vim.fn.cursor(extmarks[1][2] + 1, 1)
    end

    fn()

    vim.fn.setpos(".", cursor)
end

---@param from integer
---@param to integer
---@param pattern string
---@return integer?
function Conflict:search_in_range(from, to, pattern)
    return utils.target_in_range(from, to, self:two_way_search(pattern))
end

function Conflict:refresh_hl_cursor()
    self:with_cursor_in_conflict_region(function()
        local start, ending = self:conflict_range()
        if not start or not ending then
            return
        end

        vim.api.nvim_buf_clear_namespace(self.bufnr, NS_HL, start - 1, ending)

        local mid = self:search_in_range(start, ending, config.config.markers.mid)
        local base = self:search_in_range(start, ending, config.config.markers.base) or 0
        if not mid then
            return
        end
        if base > mid then
            base = 0
        end

        local base_delta = 0
        if base ~= 0 then
            base_delta = mid - base
        end

        self:apply_line_highlight(start - 1, start, const.HL_CONFLICT_OURS_MARKER, "(Our changes)")
        self:apply_line_highlight(start, mid - base_delta - 1, const.HL_CONFLICT_OURS)

        if base ~= 0 then
            self:apply_line_highlight(base - 1, base, const.HL_CONFLICT_BASE_MARKER, "(Base)")
            self:apply_line_highlight(base, mid - 1, const.HL_CONFLICT_BASE)
        end

        self:apply_line_highlight(mid - 1, mid, const.HL_CONFLICT_MID, "")

        self:apply_line_highlight(mid, ending - 1, const.HL_CONFLICT_THEIRS)
        self:apply_line_highlight(ending - 1, ending, const.HL_CONFLICT_THEIRS_MARKER, "(Theirs changes)")
    end)
end

function Conflict:refresh_hl_all()
    vim.api.nvim_buf_clear_namespace(self.bufnr, NS_HL, 0, -1)

    local cursor = vim.fn.getpos(".")
    vim.fn.cursor(1, 1)

    while true do
        local conflict_start = 0
        self:in_buf(function()
            conflict_start = vim.fn.search(config.config.markers.start, "cW")
        end)
        if conflict_start == 0 then
            break
        end

        self:refresh_hl_cursor()

        local conflict_end = 0
        self:in_buf(function()
            conflict_end = vim.fn.search(config.config.markers.ending, "W")
        end)
        if conflict_end == 0 then
            break
        end
    end

    vim.fn.setpos(".", cursor)
end

---@param start integer
---@param ending integer
---@param group string
---@param virt_text? string
function Conflict:apply_line_highlight(start, ending, group, virt_text)
    if virt_text then
        vim.api.nvim_buf_set_extmark(self.bufnr, NS_HL, start, 0, {
            invalidate = true,
            virt_text = { { virt_text } },
            hl_mode = "combine",
            priority = 0,
        })
    end

    vim.api.nvim_buf_set_extmark(self.bufnr, NS_HL, start, 0, {
        end_row = ending,
        end_col = 0,
        hl_eol = true,
        hl_group = group,
        priority = vim.highlight.priorities.user - 1,
        right_gravity = not not virt_text,
        end_right_gravity = not virt_text,
    })
end

function Conflict:init_hl()
    local augroup = vim.api.nvim_create_augroup(string.format("conflict-marker.nvim/Conflict:init%d", self.bufnr), {})

    vim.api.nvim_win_set_hl_ns(0, NS_HL)

    --- default diff hl interferes heavily,
    --- so there is no point in keeping them
    for _, v in ipairs({
        "DiffAdd",
        "DiffChange",
        "DiffDelete",
        "DiffText",
    }) do
        vim.api.nvim_set_hl(NS_HL, v, {})
    end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = augroup,
        buffer = self.bufnr,
        callback = function()
            self:refresh_hl_cursor()
        end,
    })

    self:refresh_hl_all()
end

---@param original_buf integer
---@param lines string[]
local function create_scratch_diff_buf(original_buf, lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].undofile = false
    vim.bo[buf].filetype = vim.bo[original_buf].filetype
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
    return buf
end

---@param buf1 integer
---@param buf2 integer
local function create_diff_windows(buf1, buf2)
    local win1 = vim.api.nvim_open_win(buf1, true, {
        split = "below",
    })
    vim.cmd("diffthis")
    local win2 = vim.api.nvim_open_win(buf2, true, {
        split = "right",
    })
    vim.cmd("diffthis")
    vim.api.nvim_set_current_win(win1)

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = { tostring(win1), tostring(win2) },
        once = true,
        callback = function()
            vim.api.nvim_win_close(win1, true)
            vim.api.nvim_win_close(win2, true)
        end,
    })
end

function Conflict:diff_ours_theirs()
    local from, to = self:conflict_range()
    if not from or not to then
        return
    end

    local mid = self:search_in_range(from, to, config.config.markers.mid)
    local base = self:search_in_range(from, to, config.config.markers.base)
    if not mid then
        return
    end
    if not base then
        base = mid
    end

    local ours_lines = vim.api.nvim_buf_get_lines(self.bufnr, from, base - 1, true)
    local theirs_lines = vim.api.nvim_buf_get_lines(self.bufnr, mid, to - 1, true)

    local ours_buf = create_scratch_diff_buf(self.bufnr, ours_lines)
    local theirs_buf = create_scratch_diff_buf(self.bufnr, theirs_lines)
    create_diff_windows(ours_buf, theirs_buf)
end

function Conflict:diff_base_ours()
    local from, to = self:conflict_range()
    if not from or not to then
        return
    end

    local mid = self:search_in_range(from, to, config.config.markers.mid)
    local base = self:search_in_range(from, to, config.config.markers.base)
    if not base or not mid then
        return
    end

    local base_lines = vim.api.nvim_buf_get_lines(self.bufnr, base, mid - 1, true)
    local ours_lines = vim.api.nvim_buf_get_lines(self.bufnr, from, base - 1, true)

    local base_buf = create_scratch_diff_buf(self.bufnr, base_lines)
    local ours_buf = create_scratch_diff_buf(self.bufnr, ours_lines)
    create_diff_windows(base_buf, ours_buf)
end

function Conflict:diff_base_theirs()
    local from, to = self:conflict_range()
    if not from or not to then
        return
    end

    local mid = self:search_in_range(from, to, config.config.markers.mid)
    local base = self:search_in_range(from, to, config.config.markers.base)
    if not base or not mid then
        return
    end

    local base_lines = vim.api.nvim_buf_get_lines(self.bufnr, base, mid - 1, true)
    local theirs_lines = vim.api.nvim_buf_get_lines(self.bufnr, mid, to - 1, true)

    local base_buf = create_scratch_diff_buf(self.bufnr, base_lines)
    local theirs_buf = create_scratch_diff_buf(self.bufnr, theirs_lines)
    create_diff_windows(base_buf, theirs_buf)
end

function Conflict:init_user_cmd()
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
        diffOursTheirs = function()
            self:diff_ours_theirs()
        end,
        diffBaseOurs = function()
            self:diff_base_ours()
        end,
        diffBaseTheirs = function()
            self:diff_base_theirs()
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
            local suggestions = vim.iter(vim.tbl_keys(choice_map))
                :filter(function(x)
                    return x:sub(1, #query) == query
                end)
                :totable()
            table.sort(suggestions)
            return suggestions
        end,
    })
end

function Conflict:init()
    if require("conflict-marker.config").config.highlights then
        self:init_hl()
    end
    self:init_user_cmd()
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
        from = vim.fn.search(config.config.markers.start, "cnbW")
        to = vim.fn.search(config.config.markers.ending, "cnW")
    end)

    if from == 0 or to == 0 then
        return
    end

    self:in_buf(function()
        -- don't accept cursor pos
        local up_end = vim.fn.search(config.config.markers.ending, "nbW")
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

    local start = self:search_in_range(from, to, config.config.markers.start)
    local mid = self:search_in_range(from, to, config.config.markers.mid)
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

    local mid = self:search_in_range(from, to, config.config.markers.mid)
    local ending = self:search_in_range(from, to, config.config.markers.ending)
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

    local base = self:search_in_range(from, to, config.config.markers.base)
    if not base then
        return from, to
    end

    local mid = self:search_in_range(from, to, config.config.markers.mid)
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

    local start = self:search_in_range(from, to, config.config.markers.start)
    local mid = self:search_in_range(from, to, config.config.markers.mid)
    local ending = self:search_in_range(from, to, config.config.markers.ending)
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

return Conflict
