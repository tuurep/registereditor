local M = {}

-- add a callback to a keypress without affecting existing keymaps
M.add_key_trigger = function(mode, key, callback, prepend)
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

    -- execute the old mapping's action
    local do_old_mapping = function()
        -- if the old mapping was defined with a function, then it will have a
        -- callback to call. Otherwise, it will have a right-hand-side to
        -- execute in normal mode
        if keymap.callback ~= nil then
            keymap.callback()
        else
            vim.schedule(function()
                vim.cmd("normal! " .. keymap.rhs)
            end)
        end
    end

    -- create a new keymap that calls both the old and new callbacks
    vim.keymap.set(mode, key, function()
        -- the ordering of the old and new callbacks can be chosen
        if prepend then
            callback()
            do_old_mapping()
        else
            do_old_mapping()
            callback()
        end
    end, { remap = true })
end

M.close_buffer = function(buffer)
    vim.cmd("bd " .. buffer)
end

return M
