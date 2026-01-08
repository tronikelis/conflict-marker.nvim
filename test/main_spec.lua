describe("main", function()
    local nvim
    local lines

    local exec_lua = function(fn, ...)
        return vim.fn.rpcrequest(nvim, "nvim_exec_lua", fn, { ... })
    end

    before_each(function()
        lines = {
            [[<<<<<<< HEAD]],
            [[local value = 5 + 7]],
            [[print(value)]],
            [[print(string.format("value is %d", value))]],
            [[=======]],
            [[local value = 1 - 1]],
            [[>>>>>>> new_branch]],
        }

        nvim = vim.fn.jobstart({ "nvim", "--embed", "--headless" }, { rpc = true })
        exec_lua([[require("conflict-marker").setup()]])
    end)

    after_each(function()
        vim.fn.jobstop(nvim)
    end)

    for _, prepare in ipairs({
        {
            "diff2",
            function()
                lines = {
                    [[<<<<<<< HEAD]],
                    [[local value = 5 + 7]],
                    [[print(value)]],
                    [[print(string.format("value is %d", value))]],
                    [[=======]],
                    [[local value = 1 - 1]],
                    [[>>>>>>> new_branch]],
                }
            end,
        },
        {
            "diff3",
            function()
                lines = {
                    [[<<<<<<< HEAD]],
                    [[local value = 5 + 7]],
                    [[print(value)]],
                    [[print(string.format("value is %d", value))]],
                    [[||||||| 229039e]],
                    [[local value = 1 + 1]],
                    [[=======]],
                    [[local value = 1 - 1]],
                    [[>>>>>>> new_branch]],
                }
            end,
        },
    }) do
        describe("with " .. prepare[1], function()
            before_each(function()
                prepare[2]()
                exec_lua(
                    [[
                        vim.api.nvim_buf_set_lines(0, 0, -1, true, ({...})[1])
                        require("conflict-marker").check()
                    ]],
                    lines
                )
            end)

            it("Conflict ours works", function()
                local result = exec_lua([[
                    vim.cmd("Conflict ours")
                    return vim.api.nvim_buf_get_lines(0, 0, -1, true)
                ]])

                assert.is_same(result, {
                    [[local value = 5 + 7]],
                    [[print(value)]],
                    [[print(string.format("value is %d", value))]],
                })
            end)

            it("Conflict theirs works", function()
                local result = exec_lua([[
                    vim.cmd("Conflict theirs")
                    return vim.api.nvim_buf_get_lines(0, 0, -1, true)
                ]])

                assert.is_same(result, {
                    [[local value = 1 - 1]],
                })
            end)

            it("Conflict both works", function()
                local result = exec_lua([[
                    vim.cmd("Conflict both")
                    return vim.api.nvim_buf_get_lines(0, 0, -1, true)
                ]])

                assert.is_same(result, {
                    [[local value = 5 + 7]],
                    [[print(value)]],
                    [[print(string.format("value is %d", value))]],
                    [[local value = 1 - 1]],
                })
            end)

            it("Conflict none works", function()
                local result = exec_lua([[
                    vim.cmd("Conflict none")
                    return vim.api.nvim_buf_get_lines(0, 0, -1, true)
                ]])

                assert.is_same(result, { "" })
            end)
        end)
    end

    it("selects conflict under cursor", function()
        lines = {
            [[<<<<<<< HEAD]],
            [[ours]],
            [[=======]],
            [[theirs]],
            [[>>>>>>> new_branch]],
            [[<<<<<<< HEAD]],
            [[ours2]],
            [[=======]],
            [[theirs2]],
            [[>>>>>>> new_branch]],
        }

        local result = exec_lua(
            [[
                local lines = ({...})[1]

                vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
                require("conflict-marker").check()

                vim.api.nvim_win_set_cursor(0, { #lines, 0 })

                vim.cmd("Conflict ours")

                return vim.api.nvim_buf_get_lines(0, 0, -1, true)
            ]],
            lines
        )

        assert.is_same(result, {
            [[<<<<<<< HEAD]],
            [[ours]],
            [[=======]],
            [[theirs]],
            [[>>>>>>> new_branch]],
            [[ours2]],
        })
    end)
end)
