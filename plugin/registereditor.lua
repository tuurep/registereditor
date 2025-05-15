local internals = require("internals")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEdit", function(opts)
        internals.open_all_windows(opts.args)
    end, { nargs = "+" })

    vim.api.nvim_create_user_command("RegisterEditClose", function(opts)
        internals.close_windows(opts.args)
    end, { nargs = "*" })
end

setup_user_commands()
