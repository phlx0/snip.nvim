# Contributing to snip.nvim

Thanks for taking the time. Bug fixes, new features, and docs improvements
are all welcome.

## Getting started

1. Fork the repo and create a branch:
   ```
   git checkout -b fix/my-fix
   ```
2. Make your changes
3. Test manually (see below)
4. Open a focused PR — one fix or feature per PR

## Testing

There's no automated test suite yet. Test manually against a real snip
installation:

```lua
-- minimal init.lua for isolated testing
vim.opt.rtp:prepend("/path/to/snip.nvim")
require("snip").setup({})
```

Then exercise the commands you've changed. If you're touching the CLI module,
make sure all five operations work: list, get, copy, delete, add.

Run `:checkhealth snip` to verify the snip executable is found correctly.

## Guidelines

- **Match the code style.** Clarity over cleverness. No unnecessary
  abstractions or helpers for one-off things. Run `stylua` and `luacheck`
  before pushing (`luacheck lua/ plugin/` and `stylua --check lua/ plugin/`).
- **One thing per PR.** A bug fix shouldn't sneak in a refactor.
- **Keep integrations separate.** Telescope, fzf-lua, and similar extensions
  belong in their own files — not wired into `init.lua`, `cli.lua`, or `ui.lua`.
- **Update the docs.** If you add or change user-visible behaviour:
  - Update `README.md`
  - Update `doc/snip.nvim.txt`
  - Regenerate `doc/tags`: `nvim --headless -c "helptags doc/" -c "quit"`
  - Add an entry under `[Unreleased]` in `CHANGELOG.md`

## Reporting bugs

Open an issue with:

- Neovim version (`nvim --version`)
- snip version (`snip --version`)
- What you did, what you expected, what happened
- Minimal steps to reproduce
