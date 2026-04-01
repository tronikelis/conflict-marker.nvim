local M = {}

---@class conflict-marker.Config.Markers
---@field start string
---@field ending string
---@field mid string
---@field base string

---@class conflict-marker.Config
---@field on_attach fun(arg: conflict-marker.Conflict)
---@field highlights boolean
---@field markers conflict-marker.Config.Markers
M.config = {
    highlights = true,
    on_attach = function() end,
    markers = {
        start = "^<<<<<<<",
        ending = "^>>>>>>>",
        mid = "^=======$",
        base = "^|||||||",
    },
}

---@param buf integer?
function M.check(buf)
    buf = buf or 0
    if buf == 0 then
        buf = vim.api.nvim_get_current_buf()
    end

    local conflict = 0
    vim.api.nvim_buf_call(buf, function()
        conflict = vim.fn.search(M.config.markers.mid, "ncw")
    end)
    if conflict == 0 then
        return
    end

    local c = require("conflict-marker.Conflict"):new(buf)
    c:init()
    M.config.on_attach(c)
end

---@param config conflict-marker.Config?
function M.setup(config)
    config = config or {}
    M.config = vim.tbl_deep_extend("force", M.config, config)
end

return M
