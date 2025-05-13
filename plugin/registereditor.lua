local internals = require("internals")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEdit", function(opts)
        internals.open_all_windows(opts.args)
    end, { nargs = "+" })
end

local function setup_autocommands()
    -- create a new autocommand group, clearing all previous autocommands
    local autocommand_group = vim.api.nvim_create_augroup(
        "registereditor_autocommands",
        { clear = true }
    )

    -- update open RegisterEdit buffers when a macro is recorded
    vim.api.nvim_create_autocmd({ "RecordingLeave" }, {
        callback = function()
            internals.update_register_buffers(
                vim.fn.reg_recording(),
                vim.api.nvim_get_vvar("event").regcontents:split("\n")
            )
        end,
    })

    -- update open RegisterEdit buffers when text is yanked into a register
    vim.api.nvim_create_autocmd({ "TextYankPost" }, {
        callback = function()
            local event = vim.api.nvim_get_vvar("event")
            internals.update_register_buffers(
                -- if no register was specified for the yank, then we will be
                -- yanking into the " register
                event.regname == "" and '"' or event.regname,
                event.regcontents
            )

            -- update numbered registers
            for register_number = 1, 10 do
                local register = tostring(register_number - 1)
                internals.update_register_buffers(
                    register,
                    vim.fn.getreg(register):split("\n")
                )
            end
        end,
    })

    -- update open RegisterEdit buffers after using the command line
    vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
        callback = vim.schedule_wrap(function()
            internals.refresh_all_register_buffers()
        end),
    })

    -- update open RegisterEdit buffers for the - register. Vim has many ways
    -- for the - register to update internally. Each event in this list needs
    -- at least one example as a justification for being included
    -- * TextChanged - needed when using x from normal mode
    -- * InsertEnter - needed when using s from visual mode
    vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
        callback = vim.schedule_wrap(function()
            internals.update_register_buffers(
                "-",
                vim.fn.getreg("-"):split("\n")
            )
        end),
    })

    -- update open RegisterEdit buffers for the . register.
    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        callback = function()
            internals.update_register_buffers(
                ".",
                vim.fn.getreg("."):split("\n")
            )
        end,
    })
end

setup_user_commands()
setup_autocommands()
