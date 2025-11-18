local utils = require("conflict-marker.utils")
local constants = require("conflict-marker.constants")

---@class conflict-marker.Conflict
---@field bufnr integer
local Conflict = {}

---@param bufnr integer
---@return conflict-marker.Conflict
function Conflict:new(bufnr)
    ---@type conflict-marker.Conflict
    local obj = {
        bufnr = bufnr,
    }
    self:add_meta(obj)

    return obj
end

---@param conflict conflict-marker.Conflict
---@return conflict-marker.Conflict
function Conflict:add_meta(conflict)
    return setmetatable(conflict, { __index = self })
end

---@param win integer
---@param win_start integer
---@param win_end integer
function Conflict:refresh_hl(win, win_start, win_end)
    vim.api.nvim_buf_clear_namespace(self.bufnr, constants.NS, win_start - 1, win_end)

    local cursor = vim.api.nvim_win_get_cursor(win)
    vim.api.nvim_win_set_cursor(win, { win_start, 0 })

    while vim.api.nvim_win_get_cursor(win)[1] <= win_end do
        -- local conflict_start = 0
        -- self:in_buf(function()
        --     conflict_start = vim.fn.search(constants.CONFLICT_START, "cW")
        -- end)
        -- if conflict_start == 0 then
        --     break
        -- end

        local start, ending = self:conflict_range()
        if not start or not ending then
            break
        end

        local mid = utils.target_in_range(start, ending, self:two_way_search(constants.CONFLICT_MID))
        local base = utils.target_in_range(start, ending, self:two_way_search(constants.CONFLICT_BASE)) or 0
        if not mid then
            break
        end
        if base > mid then
            base = 0
        end

        local base_delta = 0
        if base ~= 0 then
            base_delta = mid - base
        end

        self:apply_line_highlight(start - 1, start, constants.HL_CONFLICT_OURS_MARKER, "(Our changes)")
        self:apply_line_highlight(start, mid - base_delta - 1, constants.HL_CONFLICT_OURS)

        if base ~= 0 then
            self:apply_line_highlight(base - 1, base, constants.HL_CONFLICT_BASE_MARKER, "(Base)")
            self:apply_line_highlight(base, mid - 1, constants.HL_CONFLICT_BASE)
        end

        self:apply_line_highlight(mid - 1, mid, constants.HL_CONFLICT_MID, "")

        self:apply_line_highlight(mid, ending - 1, constants.HL_CONFLICT_THEIRS)
        self:apply_line_highlight(ending - 1, ending, constants.HL_CONFLICT_THEIRS_MARKER, "(Theirs changes)")

        local conflict_end = 0
        self:in_buf(function()
            conflict_end = vim.fn.search(constants.CONFLICT_END, "W")
        end)
        if conflict_end == 0 then
            break
        end
    end

    vim.api.nvim_win_set_cursor(win, cursor)
end

---@param start integer
---@param ending integer
---@param group string
---@param virt_text? string
function Conflict:apply_line_highlight(start, ending, group, virt_text)
    if virt_text then
        vim.api.nvim_buf_set_extmark(self.bufnr, constants.NS, start, 0, {
            invalidate = true,
            virt_text = { { virt_text } },
            hl_mode = "combine",
        })
    end

    vim.api.nvim_buf_set_extmark(self.bufnr, constants.NS, start, 0, {
        end_row = ending,
        end_col = 0,
        hl_eol = true,
        hl_group = group,
        priority = vim.highlight.priorities.user - 1,
        right_gravity = not not virt_text,
        end_right_gravity = not virt_text,
    })
end

---@param win integer
function Conflict:init(win)
    if require("conflict-marker").config.highlights then
        vim.api.nvim_win_set_hl_ns(win, constants.NS)

        --- default diff hl interferes heavily,
        --- so there is no point in keeping them
        for _, v in ipairs({
            "DiffAdd",
            "DiffChange",
            "DiffDelete",
            "DiffText",
        }) do
            vim.api.nvim_set_hl(constants.NS, v, {})
        end
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
        from = vim.fn.search(constants.CONFLICT_START, "cnbW")
        to = vim.fn.search(constants.CONFLICT_END, "cnW")
    end)

    if from == 0 or to == 0 then
        return
    end

    self:in_buf(function()
        -- don't accept cursor pos
        local up_end = vim.fn.search(constants.CONFLICT_END, "nbW")
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

    local start = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_START))
    local mid = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_MID))
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

    local mid = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_MID))
    local ending = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_END))
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

    local base = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_BASE))
    if not base then
        return from, to
    end

    local mid = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_MID))
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

    local start = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_START))
    local mid = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_MID))
    local ending = utils.target_in_range(from, to, self:two_way_search(constants.CONFLICT_END))
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
