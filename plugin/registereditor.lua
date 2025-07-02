local internals = require("internals")

-- add a callback to a keypress without affecting existing keymaps
local add_key_trigger = function(mode, key, callback, prepend)
    -- get the current keymap for the key
    local keymap = vim.fn.maparg(key, mode, false, true)

    -- if there is no current keymap, create a new keymap with the new callback
    if next(keymap) == nil then
        vim.keymap.set(mode, key, function()
            callback()
            return key
        end, { expr = true })
        return
    end

    -- create a new keymap that calls both the old and new callbacks
    vim.keymap.set(mode, key, function()
        -- the ordering of the old and new callbacks can be chosen
        if prepend then
            callback()
            keymap.callback()
        else
            keymap.callback()
            callback()
        end
    end, { remap = true })
end

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEditor", function(opts)
        internals.registereditor_command(opts.args)
    end, { nargs = "+" })
end

local function setup_autocommands()
    -- create a new autocommand group, clearing all previous autocommands
    local autocommand_group = vim.api.nvim_create_augroup(
        "registereditor_autocommands",
        { clear = true }
    )

    -- update open registereditor buffers when a macro is recorded
    vim.api.nvim_create_autocmd({ "RecordingLeave" }, {
        group = autocommand_group,
        callback = function()
            internals.update_register_buffers(
                vim.fn.reg_recording(),
                vim.api.nvim_get_vvar("event").regcontents:split("\n")
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
                vim.fn.getreg("+"):split("\n")
            )
            internals.update_register_buffers(
                "*",
                vim.fn.getreg("*"):split("\n")
            )

            -- update numbered registers
            for register_number = 1, 10 do
                local register = tostring(register_number - 1)
                internals.update_register_buffers(
                    register,
                    vim.fn.getreg(register):split("\n")
                )
            end

            -- update the - register. There are many ways to trigger this
            -- update, but they all end up triggering the TextYankPost event
            internals.update_register_buffers(
                "-",
                vim.fn.getreg("-"):split("\n")
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
                vim.fn.getreg("."):split("\n")
            )
        end,
    })

    -- update open registereditor buffers for the # and % registers.
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
        group = autocommand_group,
        callback = function()
            internals.update_register_buffers(
                "#",
                vim.fn.getreg("#"):split("\n")
            )
            internals.update_register_buffers(
                "%",
                vim.fn.getreg("%"):split("\n")
            )
        end,
    })
end

local function setup_keymaps()
    local update_slash_register = vim.schedule_wrap(function()
        internals.update_register_buffers("/", vim.fn.getreg("/"):split("\n"))
    end)
    add_key_trigger("n", "*", update_slash_register)
    add_key_trigger("n", "#", update_slash_register)
    add_key_trigger("v", "*", update_slash_register)
    add_key_trigger("v", "#", update_slash_register)
end

setup_user_commands()
setup_autocommands()
setup_keymaps()
