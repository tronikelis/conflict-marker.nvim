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

return M
