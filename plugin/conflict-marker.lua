local augroup = vim.api.nvim_create_augroup("conflict-marker.nvim/plugin", {})

vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    callback = function(ev)
        require("conflict-marker").check(ev.buf)
    end,
})
