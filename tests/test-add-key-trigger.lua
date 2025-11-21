-- Init
-- ====

local child = MiniTest.new_child_neovim()

local function restart()
    child.restart({ "-u", "tests/minimal-config/init.lua" })

    -- Initial buffer contents
    -- Just something with repeating strings so commands like * and # make a jump
    child.api.nvim_buf_set_lines(0, 0, -1, true, {
        "lorem ipsum dolor sit amet",
        "ipsum dolor sit amet lorem",
        "dolor sit amet lorem ipsum",
        "sit amet lorem ipsum dolor",
        "amet lorem ipsum dolor sit",
    })
end

local T = MiniTest.new_set({
    hooks = {
        pre_case = restart,
        post_once = child.stop,
    },
})

-- Helpers
-- =======

local function load_plugin()
    child.o.rtp = child.o.rtp .. "," .. child.fn.getcwd()
    child.cmd("runtime plugin/registereditor.lua")
end

local function expect_unmapped_behavior_match(keys)
    child.type_keys(keys)

    local ref_behavior = {
        line = child.fn.line("."),
        col = child.fn.col("."),
        search_string = child.fn.getreg("/")
    }

    restart()
    load_plugin() -- Plugin wraps keys: *, #, g*, g#, gd, gD

    child.type_keys(keys)

    local behavior = {
        line = child.fn.line("."),
        col = child.fn.col("."),
        search_string = child.fn.getreg("/")
    }

    MiniTest.expect.equality(behavior, ref_behavior)

    restart()
end

-- Tests
-- =====

T["* and #"] = function()
    expect_unmapped_behavior_match("*")
    expect_unmapped_behavior_match("#")
end

T["g* and g#"] = function()
    expect_unmapped_behavior_match("g*")
    expect_unmapped_behavior_match("g#")
end

T["gd and gD"] = function()
    -- Move down on the second "ipsum": these will go back to the first occurence
    expect_unmapped_behavior_match("jgd")
    expect_unmapped_behavior_match("jgD")
end

T["Visual * and #"] = function()
    expect_unmapped_behavior_match("viw*")
    expect_unmapped_behavior_match("viw#")
end

-- It's unclear from docs (:h search-command) if the rest should exist in Visual mode
-- But it seems like they do

T["Visual g* and g#"] = function()
    expect_unmapped_behavior_match("viwg*")
    expect_unmapped_behavior_match("viwg#")
end

T["Visual gd and gD"] = function()
    -- Move down on the second "ipsum": these will go back to the first occurence
    expect_unmapped_behavior_match("jviwgd")
    expect_unmapped_behavior_match("jviwgD")
end

return T
