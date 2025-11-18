local M = {}

---@class conflict-marker.Config
---@field on_attach fun(arg: conflict-marker.Conflict)
---@field highlights boolean
M.config = {
    highlights = true,
    on_attach = function() end,
}

---@param config conflict-marker.Config?
function M.setup(config)
    config = config or {}
    M.config = vim.tbl_deep_extend("force", M.config, config)
end

return M
