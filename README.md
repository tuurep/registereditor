# me (macro editor)

> Vim Macros are awesome. But it's hard to get it right on the first try.

*-- dohsimpson 2015*

I couldn't agree more, so I tried his plugin [vim-macroeditor](https://github.com/dohsimpson/vim-macroeditor), and it was almost perfect.

It's a tiny plugin, 27 lines of VimScript, so it's easy to edit. I've rewritten it in Lua and modified the following:

* Shorter command name (just `:Me`)
* Show name of the register in the statusline
* Set window height 1 and `nonumber`
* Check that argument is a valid macro register (a-z or A-Z)
* Allow editing a macro that hasn't been created yet
    * This already works in the original, but gives an unnecessary error
* Allow more than one macro editor window open at the same time

Big thanks to [dohsimpson](https://github.com/dohsimpson) for sharing the original plugin.

## Usage

Start editing a macro with `:Me <register>`

Update `<register>` contents with `:wq`

Or discard changes with `:q!`

When you need to insert special characters like `<Esc>` (displayed as `^[`) in a macro, press <kbd>Ctrl</kbd> + <kbd>v</kbd> in insert mode followed by <kbd>Esc</kbd>
