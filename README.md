# ruby_hl_lvar.vim

Highlight local variables in Ruby files.

## Requirements

- Vim Ruby interface(`has('ruby')`) enabled and Ruby's version = 2.0.0 (You can check by `:ruby puts RUBY_VERSION`)

Other versions of Rubies, whitch version is >= 1.9.0 may works, but I tested under only 2.0.0.

Bug reports are welcome.

## Usage

Since this plugin is under contruction, you can highlight manually:

```vim
call ruby_hl_lvar#highlight('%')
```

