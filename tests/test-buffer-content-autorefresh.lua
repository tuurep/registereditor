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

local function expect_buffer_empty(reg)
    MiniTest.expect.equality(get_buffer_contents(reg), { "" })
end

local function return_to_main_buffer()
    child.cmd("1wincmd w")
end

local function expect_macro_recording_works(reg)
    child.cmd("RegisterEditor " .. reg)
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("q" .. reg .. "ciwFoo<Esc>q")

    expect_buffer_matches_register(reg)
end

local function expect_explicit_yank_works(reg)
    child.cmd("RegisterEditor " .. reg)
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys('"' .. reg .. "yw")

    expect_buffer_matches_register(reg)
end

local function expect_cmdline_set_works(reg)
    child.cmd("RegisterEditor " .. reg)
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys(":let @" .. reg .. "='baz'<cr>")

    expect_buffer_matches_register(reg)
end

-- Tests
-- =====

T["a-z"] = MiniTest.new_set()

T["a-z"]["Generic"] = function()
    expect_macro_recording_works("a")
    restart()
    expect_explicit_yank_works("a")
    restart()
    expect_cmdline_set_works("a")
end

T["A-Z"] = MiniTest.new_set()

T["A-Z"]["Generic (stay empty)"] = function()
    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    child.cmd("RegisterEditor A")
    return_to_main_buffer()

    child.type_keys("qAciwFoo<Esc>q")
    expect_buffer_empty("A")

    child.type_keys('"Ayw')
    expect_buffer_empty("A")

    child.type_keys(":let @A='baz'<cr>")
    expect_buffer_empty("A")
end

T["A-Z"]["Append recorded macro to a"] = function()
    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    -- Record macro to lowercase reg
    child.type_keys("qaciwFoo<Esc>q")

    -- Record macro to uppercase reg: should be appended to @a
    child.type_keys("qAyy5pq")

    expect_buffer_matches_register("a")
end
T["A-Z"]["Append explicit yank to a"] = function()
    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys('"ayw')
    child.type_keys('w"Ayw')

    expect_buffer_matches_register("a")
end
T["A-Z"]["Append cmdline set to a"] = function()
    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys(":let @A='baz'<cr>")

    expect_buffer_matches_register("a")
end
T["A-Z"]["Append to a and wipe A on :w"] = function()
    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    child.cmd("RegisterEditor A")

    local text = " text to append to reg a"
    local appended_contents = newline_split(child.fn.getreg("a") .. text)

    child.type_keys("i" .. text .. "<Esc>")
    child.type_keys(":w<cr>")

    MiniTest.expect.equality(get_buffer_contents("a"), appended_contents)
    expect_buffer_empty("A")
end
T["A-Z"]["Append to a and wipe A on a custom save map"] = function()
    child.api.nvim_set_keymap("n", "<C-s>", "<cmd>w<cr>", {})

    child.cmd("RegisterEditor a")
    child.type_keys("ifoobar<Esc>:w<cr>")
    child.cmd("RegisterEditor A")

    local text = " text to append to reg a"
    local appended_contents = newline_split(child.fn.getreg("a") .. text)

    child.type_keys("i" .. text .. "<Esc>")
    child.type_keys("<C-s>")

    MiniTest.expect.equality(get_buffer_contents("a"), appended_contents)
    expect_buffer_empty("A")
end

T['"'] = MiniTest.new_set()

-- Surprising: a macro *can* be recorded to the " register
T['"']["Generic"] = function()
    MiniTest.add_note("\n\n  Reg updates self in the macro with 'ciw', doesn't refresh on macro end.\n"
                   .. '  Works when manually doing this. Only a problem for the " reg.\n'
                   .. "  Would work with no delete/yank in macro.")
    expect_macro_recording_works('"')
    restart()
    expect_explicit_yank_works('"')
    restart()
    expect_cmdline_set_works('"')
end
T['"']['clipboard="" (default)'] = function()
    child.cmd('RegisterEditor "')
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("yw") -- Small
    expect_buffer_matches_register('"')

    child.type_keys("yip") -- Big
    expect_buffer_matches_register('"')

    child.type_keys("dw") -- Small
    expect_buffer_matches_register('"')

    child.type_keys("dip") -- Big
    expect_buffer_matches_register('"')
end

T["*"] = MiniTest.new_set()

T["*"]["Generic"] = function()
    -- Cannot record macro
    expect_explicit_yank_works("*")
    restart()
    expect_cmdline_set_works("*")
end
T["*"]['clipboard="unnamed"'] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.o.clipboard = "unnamed"
        end,
        post_once = function()
            child.o.clipboard = ""
        end,
    },
})
T["*"]['clipboard="unnamed"'] = function()
    child.cmd('RegisterEditor "') -- Unnamed reg is still always used
    child.cmd("RegisterEditor *")

    return_to_main_buffer()

    child.type_keys("yw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")

    child.type_keys("yip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")

    child.type_keys("dw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")

    child.type_keys("dip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")
end

T["+"] = MiniTest.new_set()

T["+"]["Generic"] = function()
    -- Cannot record macro
    expect_explicit_yank_works("+")
    restart()
    expect_cmdline_set_works("+")
end
T["+"]['clipboard="unnamedplus"'] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.o.clipboard = "unnamedplus"
        end,
        post_once = function()
            child.o.clipboard = ""
        end,
    },
})
T["+"]['clipboard="unnamedplus"'] = function()
    child.cmd('RegisterEditor "') -- Unnamed reg is still always used
    child.cmd("RegisterEditor +")

    return_to_main_buffer()

    MiniTest.add_note("This sometimes fails, system clipboard is not in sync?")

    child.type_keys("yw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("+")

    child.type_keys("yip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("+")

    child.type_keys("dw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("+")

    child.type_keys("dip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("+")
end

-- Special: it's possible to use all three regs "*+ as default clipboard at once
T['clipboard="unnamed,unnamedplus"'] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.o.clipboard = "unnamed,unnamedplus"
        end,
        post_once = function()
            child.o.clipboard = ""
        end,
    },
})
T["+"]['clipboard="unnamed,unnamedplus"'] = function()
    child.cmd('RegisterEditor "')
    child.cmd("RegisterEditor *")
    child.cmd("RegisterEditor +")

    return_to_main_buffer()

    MiniTest.add_note("This sometimes fails, system clipboard is not in sync?")

    child.type_keys("yw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")
    expect_buffer_matches_register("+")

    child.type_keys("yip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")
    expect_buffer_matches_register("+")

    child.type_keys("dw") -- Small
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")
    expect_buffer_matches_register("+")

    child.type_keys("dip") -- Big
    expect_buffer_matches_register('"')
    expect_buffer_matches_register("*")
    expect_buffer_matches_register("+")
end

-- TODO: not sure how to test the FocusGained case for * and +
-- Firing the event is possible with `doautocmd`
-- But how would we update the regs in a way that's similar to a system clipboard copy?

T["-"] = MiniTest.new_set()

T["-"]["Generic"] = function()
    -- Cannot record macro
    expect_explicit_yank_works("-")
    restart()
    expect_cmdline_set_works("-")
end
T["-"]["Small deletes"] = function()
    child.cmd("RegisterEditor -")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("dw")
    expect_buffer_matches_register("-")

    child.type_keys("jd$")
    expect_buffer_matches_register("-")

    child.type_keys("jx")
    expect_buffer_matches_register("-")
end

T["0"] = MiniTest.new_set()

T["0"]["Generic"] = function()
    expect_macro_recording_works("0") -- *Can* record macro (strange)
    restart()
    expect_explicit_yank_works("0")
    restart()
    expect_cmdline_set_works("0")
end
T["0"]["Yank"] = function()
    child.cmd("RegisterEditor 0")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("yw") -- Small
    expect_buffer_matches_register("0")

    child.type_keys("yip") -- Big
    expect_buffer_matches_register("0")
end

T["1-9"] = MiniTest.new_set()

T["1-9"]["Generic"] = function()
    for i=1, 9 do
        local reg = tostring(i)
        expect_macro_recording_works(reg) -- *Can* record macro (strange)
        restart()
        expect_explicit_yank_works(reg)
        restart()
        expect_cmdline_set_works(reg)
        restart()
    end
end
T["1-9"]["Multiline-delete history"] = function()
    child.cmd("RegisterEditor 1 2 3 4 5 6 7 8 9")
    return_to_main_buffer()

    for i=1, 9 do
        child.type_keys("dd")
        for j=1, i do
            local reg = tostring(j)
            expect_buffer_matches_register(reg)
        end
    end
end

T["%#"] = MiniTest.new_set()

T["%#"]["Switch between files"] = function()
    child.cmd("RegisterEditor #") -- Last buffer filename
    expect_buffer_matches_register("#")

    child.cmd("RegisterEditor %") -- Current buffer filename
    expect_buffer_matches_register("%")

    return_to_main_buffer()
    expect_buffer_matches_register("#")
    expect_buffer_matches_register("%")

    -- Todo: return_to_main_buffer only works if main buffer is top left -most
    -- Find a way to make it go to the "oldest" window instead
    vim.cmd("below split foobar.lua")

    expect_buffer_matches_register("#")
    expect_buffer_matches_register("%")

    return_to_main_buffer()
    expect_buffer_matches_register("#")
    expect_buffer_matches_register("%")
end

T[":"] = MiniTest.new_set()

T[":"]["Run ex commands"] = function()
    child.cmd("RegisterEditor :")

    child.type_keys(":echo 'foobar'<cr>")
    expect_buffer_matches_register(":")

    return_to_main_buffer()

    child.type_keys(":echo 'baz'<cr>")
    expect_buffer_matches_register(":")

    child.type_keys(":%s/dolor/holor/g")
    expect_buffer_matches_register(":")
end
T[":"]["Choose a command in cmdwin"] = function()
    -- Cmdwin (see :h cmdwin) can be accessed in 2 ways:
    -- 1. q:
    -- 2. <C-f> in cmdline
    child.cmd("RegisterEditor :")
    return_to_main_buffer()

    child.type_keys(":echo 'foo'<cr>")
    child.type_keys(":echo 'bar'<cr>")
    child.type_keys(":echo 'baz'<cr>")
    child.type_keys(":echo 'qux'<cr>")
    child.type_keys("q:k<cr>")

    expect_buffer_matches_register(":")

    child.type_keys(":<C-f>gg<cr>")
    expect_buffer_matches_register(":")
end

T["."] = MiniTest.new_set()

T["."]["Insert/change text"] = function()
    child.cmd("RegisterEditor .")
    return_to_main_buffer()

    -- Insert
    child.type_keys("iFoo ")
    expect_buffer_matches_register(".")
    child.type_keys("<Esc>")
    expect_buffer_matches_register(".")

    -- Use c operator
    child.type_keys("wcwbar")
    expect_buffer_matches_register(".")
    child.type_keys("<Esc>")
    expect_buffer_matches_register(".")
end

-- TODO: More complicated than others, need to learn how it actually works
--       :h @=
--       Got the most obvious tests here as a start
T["="] = MiniTest.new_set()

T["="]["Cmdline set"] = function()
    -- This works differently from the rest, can't just write "foobar" in it
    child.cmd("RegisterEditor =")
    return_to_main_buffer()

    child.type_keys(":let @=='2+3'<cr>") -- In register: "5"
    expect_buffer_matches_register("=")
end
T["="]['Special "='] = function()
    child.cmd("RegisterEditor =")
    return_to_main_buffer()

    -- Enters a sort of special cmdline mode, see :h "=
    child.type_keys('"=2+3<cr>') -- In register: "5"
    expect_buffer_matches_register("=")
end
T["="]["Special insert mode <C-r>="] = function()
    child.cmd("RegisterEditor =")
    return_to_main_buffer()

    -- Enters a sort of special cmdline mode, see :h "=
    child.type_keys("i<C-r>=2+3<cr>") -- In register: "5"
    expect_buffer_matches_register("=")
end

T["_"] = MiniTest.new_set()

T["_"]["Generic"] = function()
    -- Cannot record macro
    expect_explicit_yank_works("_") -- We check that it's empty like the real reg
    expect_cmdline_set_works("_")
end
T["_"]["Wipe contents on :w"] = function()
    -- Funny but deliberate behavior: wipe the buffer to match the real blackhole reg
    child.cmd("RegisterEditor _")

    child.type_keys("iHold up can I write here?<Esc>")
    child.type_keys(":w<cr>")

    expect_buffer_matches_register("_")
end
T["_"]["Wipe contents on a custom save map"] = function()
    child.api.nvim_set_keymap("n", "<C-s>", "<cmd>w<cr>", {})

    child.cmd("RegisterEditor _")

    child.type_keys("iHold up can I write here?<Esc>")
    child.type_keys("<C-s>")

    expect_buffer_matches_register("_")
end

T["/"] = MiniTest.new_set()

T["/"]["Generic"] = function()
    -- Weird one: can't record macro, can't explicitly yank,
    -- but *can* set on cmdline
    expect_cmdline_set_works("/")
end
T["/"]["Search with / and ?"] = function()
    child.cmd("RegisterEditor /")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("/lobortis<cr>")
    expect_buffer_matches_register("/")

    child.type_keys("?dolor<cr>")
    expect_buffer_matches_register("/")
end
T["/"]["Search with * and #"] = function()
    MiniTest.skip("SKIP: issue #22")

    child.cmd("RegisterEditor /")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("*")
    expect_buffer_matches_register("/")

    child.type_keys("G") -- Move on another word to actually test
    child.type_keys("#")
    expect_buffer_matches_register("/")
end
T["/"]["Search with Visual * and #"] = function()
    MiniTest.skip("SKIP: issue #22")

    MiniTest.add_note("Cursor is not moved but buffer correctly refreshes")

    child.cmd("RegisterEditor /")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("ve*")
    expect_buffer_matches_register("/")

    child.type_keys("G") -- Move on another word to actually test
    child.type_keys("ve#")
    expect_buffer_matches_register("/")
end
T["/"]["Search with g* and g#"] = function()
    MiniTest.skip("SKIP: issue #22")

    child.cmd("RegisterEditor /")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("g*")
    expect_buffer_matches_register("/")

    child.type_keys("G") -- Move on another word to actually test
    child.type_keys("g#")
    expect_buffer_matches_register("/")
end
T["/"]["Search with gd and gD"] = function()
    MiniTest.skip("SKIP: issue #22")

    child.cmd("RegisterEditor /")
    child.type_keys("ifoobar<Esc>:w<cr>")
    return_to_main_buffer()

    child.type_keys("gd")
    expect_buffer_matches_register("/")

    child.type_keys("G") -- Move on another word to actually test
    child.type_keys("gD")
    expect_buffer_matches_register("/")
end
T["/"]["Choose a search string in cmdwin"] = function()
    -- Cmdwin for search strings (see :h cmdwin) can be accessed in 2 ways:
    -- 1. q/ or q?
    -- 2. <C-f> in cmdline (while searching)
    child.cmd("RegisterEditor /")
    return_to_main_buffer()

    child.type_keys("/odio<cr>")
    child.type_keys("/turpis<cr>")
    child.type_keys("/amet<cr>")
    child.type_keys("/nulla<cr>")
    child.type_keys("q/k<cr>")

    expect_buffer_matches_register("/")

    child.type_keys("/<C-f>gg<cr>")
    expect_buffer_matches_register("/")
end

T["Do not refresh buffer currently in focus (unless readonly)"] = function()
    child.type_keys('"ayj') -- Copy 2 lines to reg a
    child.type_keys("yj") -- Copy 2 lines to reg "
    child.cmd('RegisterEditor "')

    child.type_keys("dw")
    expect_buffer_does_not_match_register('"')

    child.type_keys("yw")
    expect_buffer_does_not_match_register('"')

    -- Explicit "
    child.type_keys('""dw')
    expect_buffer_does_not_match_register('"')

    child.type_keys('""yw')
    expect_buffer_does_not_match_register('"')

    child.cmd('RegisterEditor a')

    child.type_keys('"adw')
    expect_buffer_does_not_match_register("a")

    child.type_keys('"ayw')
    expect_buffer_does_not_match_register("a")

    child.type_keys("qaiFoo<Esc>q")
    expect_buffer_does_not_match_register("a")

    child.cmd("let @a='Bar'") -- Note: doesn't move to cmdline
    expect_buffer_does_not_match_register("a")
end

return T
