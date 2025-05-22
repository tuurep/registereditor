local internals = require("internals")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEdit", function(opts)
        internals.register_edit_command(opts.args)
    end, { nargs = "+" })
end

setup_user_commands()
