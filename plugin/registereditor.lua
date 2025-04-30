local internals = require("internals")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEdit", function(opts)
        internals.open_editor_window(opts.args)
    end, { nargs = 1 })
end

setup_user_commands()
