# registereditor

> Vim Macros are awesome. But it's hard to get it right on the first try.

*-- dohsimpson 2015*

I couldn't agree more, so I tried his plugin [vim-macroeditor](https://github.com/dohsimpson/vim-macroeditor), and it was almost perfect.

It's a tiny plugin, 27 lines of VimScript, so it's easy to edit. I've rewritten it in Lua and modified the following:

* Now you can edit any register, not just macros
    * Though the best use is for editing macros, editing other types of registers is basically the same thing, so just allow it
* Short command (just `:Re`)
* Checks that argument is a valid register
* No warnings when editing a register that wasn't already set
* Allows more than one window open at the same time
* Window shows register name in statusline
* Window height is set based on number of lines in register
* Always splits window below

Big thanks to [dohsimpson](https://github.com/dohsimpson) for sharing the original plugin.

## Usage

Start editing a register with `:Re <register>`

Update `<register>` contents with `:wq`

Or discard changes with `:q!`

### Inserting special characters in macros

When you need to insert special characters like `<Esc>` (displayed as `^[`) in a macro, press <kbd>Ctrl</kbd> + <kbd>v</kbd> in insert mode followed by <kbd>Esc</kbd>

### How to deal with newlines in registers

Newlines in registers are stored as `^J` (see `:h NL-used-for-Nul`). This causes an actual <kbd>Ctrl</kbd> + <kbd>j</kbd> keypress in a macro.

That's why macros should be written only on the first line of the registereditor buffer with no empty lines after.

When a newline at the end of the register is desired, the registereditor buffer should end in an empty line.

## Editing registers with no plugins at all

This plugin is in essence a less cumbersome alternative to one of the following methods:

Example register `q`

1. On the command line:
    * `:let @q = "<C-r>q"`
    * Register `q` contents are pasted on commandline for editing

2. Temporarily pasting to a buffer for editing:
    * `"qp`
    * Edit inside buffer
    * Yank it back using something like:
        * `"qy` . . .
        * `"qd` . . .
