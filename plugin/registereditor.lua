local internals = require("internals")

local function setup_user_commands()
    vim.api.nvim_create_user_command("RegisterEditor", function(opts)
        internals.registereditor_command(opts.args)
    end, { nargs = "+" })
end

setup_user_commands()
