local internals = require("internals")
local lua_utils = require("lua_utils")
local vim_utils = require("vim_utils")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEditor", function(opts)
        internals.registereditor_command(opts.args)
    end, { nargs = "+" })
end

local function setup_autocommands()
    -- create a new autocommand group, clearing all previous autocommands
    local autocommand_group =
        vim.api.nvim_create_augroup("registereditor_autocommands", { clear = true })

    -- update open registereditor buffers when a macro is recorded
    vim.api.nvim_create_autocmd({ "RecordingLeave" }, {
        group = autocommand_group,
        callback = function()
            internals.update_register_buffers(
                vim.fn.reg_recording(),
                lua_utils.newline_split(vim.api.nvim_get_vvar("event").regcontents)
            )
        end,
    })

    -- update open registereditor buffers when text is yanked into a register
    vim.api.nvim_create_autocmd({ "TextYankPost" }, {
        group = autocommand_group,
        callback = function()
            local event = vim.api.nvim_get_vvar("event")
            internals.update_register_buffers(
                -- if no register was specified for the yank, then we will be
                -- yanking into the " register
                event.regname == "" and '"' or event.regname,
                event.regcontents
            )
            internals.update_register_buffers(
                "+",
                lua_utils.newline_split(vim.fn.getreg("+"))
            )
            internals.update_register_buffers(
                "*",
                lua_utils.newline_split(vim.fn.getreg("*"))
            )

            -- update numbered registers
            for register_number = 1, 10 do
                local register = tostring(register_number - 1)
                internals.update_register_buffers(
                    register,
                    lua_utils.newline_split(vim.fn.getreg(register))
                )
            end

            -- update the - register. There are many ways to trigger this
            -- update, but they all end up triggering the TextYankPost event
            internals.update_register_buffers(
                "-",
                lua_utils.newline_split(vim.fn.getreg("-"))
            )
        end,
    })

    -- update open registereditor buffers after using the command line
    vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
        group = autocommand_group,
        callback = vim.schedule_wrap(function()
            internals.refresh_all_register_buffers()
        end),
    })

    -- update open registereditor buffers for the . register.
    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        group = autocommand_group,
        callback = function()
            internals.update_register_buffers(
                ".",
                lua_utils.newline_split(vim.fn.getreg("."))
            )
        end,
    })

    -- update open registereditor buffers for the # and % registers.
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
        group = autocommand_group,
        callback = function()
            internals.update_register_buffers(
                "#",
                lua_utils.newline_split(vim.fn.getreg("#"))
            )
            internals.update_register_buffers(
                "%",
                lua_utils.newline_split(vim.fn.getreg("%"))
            )
        end,
    })
end

local function setup_keymaps()
    local update_slash_register = vim.schedule_wrap(function()
        internals.update_register_buffers(
            "/",
            lua_utils.newline_split(vim.fn.getreg("/"))
        )
    end)
    local search_actions = { "*", "#", "g*", "g#", "gd", "gD" }
    for _, key in ipairs(search_actions) do
        vim_utils.add_key_trigger("n", key, update_slash_register)
        vim_utils.add_key_trigger("v", key, update_slash_register)
    end
end

setup_user_commands()
setup_autocommands()
setup_keymaps()
