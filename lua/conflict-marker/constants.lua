local M = {}

M.HL_CONFLICT_OURS_MARKER = "ConflictOursMarker"
M.HL_CONFLICT_OURS = "ConflictOurs"
M.HL_CONFLICT_THEIRS = "ConflictTheirs"
M.HL_CONFLICT_THEIRS_MARKER = "ConflictTheirsMarker"
M.HL_CONFLICT_MID = "ConflictMid"

M.CONFLICT_START = "^<<<<<<<"
M.CONFLICT_END = "^>>>>>>>"
M.CONFLICT_MID = "^=======$"
M.CONFLICT_BASE = "^|||||||"

M.HL_CONFLICT_BASE_MARKER = "ConflictBaseMarker"
M.HL_CONFLICT_BASE = "ConflictBase"

M.NS = vim.api.nvim_create_namespace("conflict-marker.nvim")

return M
