# registereditor

> Vim Macros are awesome. But it's hard to get it right on the first try.

*-- dohsimpson 2015*

I couldn't agree more, so I tried his plugin [vim-macroeditor](https://github.com/dohsimpson/vim-macroeditor), and it was almost perfect.

It's a tiny plugin, 27 lines of VimScript, so it's easy to edit. I've rewritten it in Lua and modified the following:

* Now you can edit any register, not just macros
    * Though the best use is for editing macros, editing other types of registers is basically the same thing, so just allow it
* Macros can be edited on multiple lines (lines concatenated in register)
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

When you need to insert special characters like `<Esc>` (displayed as `^[`) in a macro, press <kbd>Ctrl</kbd> + <kbd>v</kbd> in insert mode followed by <kbd>Esc</kbd>
