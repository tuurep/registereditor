-- Init
-- ====

local child = MiniTest.new_child_neovim()

local function restart()
    child.restart({ "-u", "tests/minimal-config/init.lua" })

    -- Load plugin
    child.o.rtp = child.o.rtp .. "," .. vim.fn.getcwd()
    child.cmd("runtime plugin/registereditor.lua")

    -- "Main buffer" is prepopulated with this for each test
    child.api.nvim_buf_set_lines(0, 0, -1, true, {
        "Lorem ipsum dolor sit amet,",
        "consectetur adipiscing elit.",
        "Quisque sed dolor sapien.",
        "Nam at posuere odio.",
        "Mauris sit amet erat orci.",
        "Vivamus sit amet tincidunt quam.",
        "Phasellus vel turpis quis purus lobortis bibendum.",
        "Suspendisse potenti.",
        "Morbi at justo non risus auctor dictum",
        "Suspendisse laoreet nulla sit amet felis faucibus blandit.",
    })
end

local T = MiniTest.new_set({
    hooks = {
        pre_case = restart,

        -- Todo: doesn't test all cases where modified should be set to false
        -- Still useful though
        post_case = function()
            MiniTest.expect.equality(child.bo.modified, false)
        end,

        post_once = child.stop,
    },
})

-- Helpers
-- =======

vim.o.rtp = vim.o.rtp .. "," .. vim.fn.getcwd()
newline_split = require("lua-utils").newline_split

local function get_register_from_buffer(buf)
    return string.sub(child.api.nvim_buf_get_name(buf), -1, -1)
end

local function get_buffer_contents(reg)
    for _, buf in pairs(child.api.nvim_list_bufs()) do
        if child.api.nvim_get_option_value("filetype", { buf = buf }) == "registereditor" then
            if get_register_from_buffer(buf) == reg then
                return child.api.nvim_buf_get_lines(buf, 0, -1, true)
            end
        end
    end
    error("registereditor buffer @" .. reg .. " not found")
    return {}
end

local function expect_buffer_matches_register(reg)
    local actual_reg = newline_split(child.fn.getreg(reg))
    MiniTest.expect.equality(get_buffer_contents(reg), actual_reg)
end

local function expect_buffer_does_not_match_register(reg)
    local actual_reg = newline_split(child.fn.getreg(reg))
    MiniTest.expect.no_equality(get_buffer_contents(reg), actual_reg)
end

local function expect_buffer_is_empty(reg)
    MiniTest.expect.equality(get_buffer_contents(reg), { "" })
end

local function expect_buffer_is_not_empty(reg)
    MiniTest.expect.no_equality(get_buffer_contents(reg), { "" })
end

-- TODO: expects "main buffer" is the top-left-most buffer
-- Make it so it switches to the first opened buffer
local function return_to_main_buffer()
    child.cmd("1wincmd w")
end

local function expect_basic_write(reg, save_keys)
    -- Single line
    child.cmd("RegisterEditor " .. reg)
    child.type_keys("ifoobar<Esc>" .. save_keys)
    expect_buffer_is_not_empty(reg)
    expect_buffer_matches_register(reg)

    -- Multi line
    child.type_keys("obazqux<cr><Esc>" .. save_keys)
    expect_buffer_is_not_empty(reg)
    expect_buffer_matches_register(reg)
end

-- Tests
-- =====

T["a-z"] = function()
    expect_basic_write("a", ":w<cr>")
end

T["A-Z"] = function()
    -- @A-Z buffers append to the lowercase counterpart on write, and wipe self.

    child.cmd("RegisterEditor a")
    child.type_keys("iinitial<Esc>:w<cr>")
    child.cmd("RegisterEditor A")

    child.type_keys("ifoo<Esc>:w<cr>")

    expect_buffer_is_not_empty("a")
    expect_buffer_matches_register("a")
    expect_buffer_is_empty("A")

    child.type_keys("i additional<cr>bar<cr><Esc>:w<cr>")

    expect_buffer_is_not_empty("a")
    expect_buffer_matches_register("a")
    expect_buffer_is_empty("A")
end

T['"'] = function()
    child.cmd("let @\"=''")
    expect_basic_write('"', ":w<cr>")
end

T["*"] = function()
    child.cmd("let @*=''")
    expect_basic_write("*", ":w<cr>")
end

T["+"] = function()
    child.cmd("let @+=''")
    expect_basic_write("+", ":w<cr>")
end

T["-"] = function()
    expect_basic_write("-", ":w<cr>")
end

T["0"] = function()
    expect_basic_write("0", ":w<cr>")
end

T["1-9"] = function()
    for i=1, 9 do
        local reg = tostring(i)
        expect_basic_write(reg, ":w<cr>")
        vim.cmd("bd")
    end
end

T["#"] = function()
    -- @# buffer can be written to if contents are substring matching an existing buffer
    -- name, or an existing buffer id. It expands immediately to the full buffername.

    -- Gives a sensible error if not a valid string that can be written.

    child.cmd("rightbelow split foobar.lua")
    child.cmd("rightbelow vsplit bazqux.nim")
    child.cmd("rightbelow vsplit Makefile")
    child.cmd("rightbelow vsplit .gitignore")

    child.cmd("RegisterEditor #")

    child.type_keys("ccfoobar.lua<Esc>:w<cr>")
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("ccqux<Esc>:w<cr>")
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("ccM<Esc>:w<cr>") -- Makefile
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("cc0<Esc>:w<cr>") -- Current buffer id
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

     -- Turns out this actually *is* empty in the test env...
    child.type_keys("cc1<Esc>:w<cr>") -- The main buffer id
    expect_buffer_matches_register("#")

    -- Try all existing buffer ids
    for i=2, 6 do
        child.type_keys("cc" .. i .. "<Esc>:w<cr>")
        expect_buffer_is_not_empty("#")
        expect_buffer_matches_register("#")
    end
end

T["="] = function()
    -- @= buffer evaluates the buffer contents and rewrites the buffer with the
    -- evaluation.

    child.cmd("RegisterEditor =")
    child.type_keys("i2+3<Esc>:w<cr>")
    expect_buffer_is_not_empty("=")
    expect_buffer_matches_register("=")
    child.type_keys("A*5<Esc>:w<cr>")
    expect_buffer_is_not_empty("=")
    expect_buffer_matches_register("=")

    -- Note (but not relevant to this test):
    --
    -- The = register can't be set as a multi line table
    -- For example `vim.fn.setreg("=", {"2", "+", "3"})`
    -- But it can contain newlines, and our `set_register()` concats the lines in a way it
    -- works. If written with multiple lines, seems like it evaluates the first line and
    -- ignores the rest.
end

T["_"] = function()
    -- @_ buffer just wipes itself on write to match the register.

    child.cmd("RegisterEditor _")

    child.type_keys("ifoobar<Esc>:w<cr>")
    expect_buffer_matches_register("_")

    child.type_keys("ifoobar<cr>bazqux<cr><cr><Esc>:w<cr>")
    expect_buffer_matches_register("_")
end

T["/"] = function()
    -- Note: the / register can't be set as a multi line table
    -- For example `vim.fn.setreg("/", {"a", "b", "c"})`
    -- But it can contain newlines, and our `set_register()` concats the lines in a way it
    -- works
    expect_basic_write("/", ":w<cr>")
end

-- Three readonly registers . : % (can't be written to)
-- These also have `nomodifiable` set and will error at an attempt to edit.
-- Not sure how to test these. For a start, check that `readonly` and `nomodifiable` are
-- set.

T["."] = function()
    child.cmd("RegisterEditor .")
    MiniTest.expect.equality(child.bo.readonly, true)
    MiniTest.expect.equality(child.bo.modifiable, false)
end
T[":"] = function()
    child.cmd("RegisterEditor :")
    MiniTest.expect.equality(child.bo.readonly, true)
    MiniTest.expect.equality(child.bo.modifiable, false)
end
T["%"] = function()
    child.cmd("RegisterEditor %")
    MiniTest.expect.equality(child.bo.readonly, true)
    MiniTest.expect.equality(child.bo.modifiable, false)
end

-- With custom save map
-- Note: this isn't really about the mapping itself, but about not using the CmdLineLeave
-- event when writing the buffer.
T["Custom save map"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.api.nvim_set_keymap("n", "<C-s>", "<cmd>w<cr>", {})
        end
    }
})

T["Custom save map"]["a-z"] = function()
    expect_basic_write("a", "<C-s>")
end

T["Custom save map"]["A-Z"] = function()
    -- @A-Z buffers append to the lowercase counterpart on write, and wipe self.

    child.cmd("RegisterEditor a")
    child.type_keys("iinitial<Esc><C-s>")
    child.cmd("RegisterEditor A")

    child.type_keys("ifoo<Esc><C-s>")

    expect_buffer_is_not_empty("a")
    expect_buffer_matches_register("a")
    expect_buffer_is_empty("A")

    child.type_keys("i additional<cr>bar<cr><Esc><C-s>")

    expect_buffer_is_not_empty("a")
    expect_buffer_matches_register("a")
    expect_buffer_is_empty("A")
end

T["Custom save map"]['"'] = function()
    child.cmd("let @\"=''")
    expect_basic_write('"', "<C-s>")
end

T["Custom save map"]["*"] = function()
    child.cmd("let @*=''")
    expect_basic_write("*", "<C-s>")
end

T["Custom save map"]["+"] = function()
    child.cmd("let @+=''")
    expect_basic_write("+", "<C-s>")
end

T["Custom save map"]["-"] = function()
    expect_basic_write("-", "<C-s>")
end

T["Custom save map"]["0"] = function()
    expect_basic_write("0", "<C-s>")
end

T["Custom save map"]["1-9"] = function()
    for i=1, 9 do
        local reg = tostring(i)
        expect_basic_write(reg, "<C-s>")
        vim.cmd("bd")
    end
end

T["Custom save map"]["#"] = function()
    -- @# buffer can be written to if contents are substring matching an existing buffer
    -- name, or an existing buffer id. It expands immediately to the full buffername.

    -- Gives a sensible error if not a valid string that can be written.

    child.cmd("rightbelow split foobar.lua")
    child.cmd("rightbelow vsplit bazqux.nim")
    child.cmd("rightbelow vsplit Makefile")
    child.cmd("rightbelow vsplit .gitignore")

    child.cmd("RegisterEditor #")

    child.type_keys("ccfoobar.lua<Esc><C-s>")
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("ccqux<Esc><C-s>")
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("ccM<Esc><C-s>") -- Makefile
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

    child.type_keys("cc0<Esc><C-s>") -- Current buffer id
    expect_buffer_is_not_empty("#")
    expect_buffer_matches_register("#")

     -- Turns out this actually *is* empty in the test env...
    child.type_keys("cc1<Esc><C-s>") -- The main buffer id
    expect_buffer_matches_register("#")

    -- Try all existing buffer ids
    for i=2, 6 do
        child.type_keys("cc" .. i .. "<Esc><C-s>")
        expect_buffer_is_not_empty("#")
        expect_buffer_matches_register("#")
    end
end

T["Custom save map"]["="] = function()
    -- @= buffer evaluates the buffer contents and rewrites the buffer with the
    -- evaluation.

    child.cmd("RegisterEditor =")
    child.type_keys("i2+3<Esc><C-s>")
    expect_buffer_is_not_empty("=")
    expect_buffer_matches_register("=")
    child.type_keys("A*5<Esc><C-s>")
    expect_buffer_is_not_empty("=")
    expect_buffer_matches_register("=")

    -- Note (but not relevant to this test):
    --
    -- The = register can't be set as a multi line table
    -- For example `vim.fn.setreg("=", {"2", "+", "3"})`
    -- But it can contain newlines, and our `set_register()` concats the lines in a way it
    -- works. If written with multiple lines, seems like it evaluates the first line and
    -- ignores the rest.
end

T["Custom save map"]["_"] = function()
    -- @_ buffer just wipes itself on write to match the register.

    child.cmd("RegisterEditor _")

    child.type_keys("ifoobar<Esc><C-s>")
    expect_buffer_matches_register("_")

    child.type_keys("ifoobar<cr>bazqux<cr><cr><Esc><C-s>")
    expect_buffer_matches_register("_")
end

T["Custom save map"]["/"] = function()
    -- Note: the / register can't be set as a multi line table
    -- For example `vim.fn.setreg("/", {"a", "b", "c"})`
    -- But it can contain newlines, and our `set_register()` concats the lines in a way it
    -- works
    expect_basic_write("/", "<C-s>")
end

return T
