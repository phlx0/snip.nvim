<div align="center">

# ◆ snip.nvim

**Your [snip](https://github.com/phlx0/snip) snippet library, inside Neovim.**

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white&style=flat-square)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?logo=lua&logoColor=white&style=flat-square)](https://lua.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/phlx0/snip.nvim/ci.yml?branch=main&label=CI&style=flat-square)](https://github.com/phlx0/snip.nvim/actions)

</div>

---

You saved that docker command in snip. Now you're deep in a file and you don't want to alt-tab, run `snip`, copy, come back, paste. You want it in one step.

`:SnipList` → navigate → `<CR>`. Done.

## Requirements

- Neovim **0.10+**
- [`snip`](https://github.com/phlx0/snip) installed and on `$PATH`

## Install

```lua
-- lazy.nvim (recommended — lazy-loads on first command)
{
  "phlx0/snip.nvim",
  cmd  = { "SnipList", "Snip", "SnipCopy", "SnipRun", "SnipDelete", "SnipAdd", "SnipExport", "SnipImport" },
  keys = {
    { "<leader>ss", "<cmd>SnipList<cr>",  desc = "Browse snippets" },
    { "<leader>sp", ":Snip ",             desc = "Paste snippet" },
    { "<leader>sr", ":SnipRun ",          desc = "Run snippet" },
  },
}
```

No setup call required. snip.nvim works out of the box. Add one if you want
to customise anything:

```lua
require("snip").setup({
  cmd = "snip",            -- snip executable, change if it's not on $PATH
  keymaps = {
    paste      = { "<CR>", "p" },  -- paste snippet into buffer, close browser
    yank       = "y",              -- copy to system clipboard
    delete     = "d",              -- delete snippet (confirmation required)
    search     = "/",              -- search title, description, tags, language
    tag_filter = "t",              -- pick a tag to filter by
    clear      = "<C-l>",         -- clear all active filters
    refresh    = "R",              -- reload snippets from snip
    help       = "?",              -- show keymap help overlay
    close      = { "q", "<Esc>" }, -- close browser
  },
  ui = {
    width      = 0.85,      -- fraction of &columns
    height     = 0.80,      -- fraction of &lines
    list_ratio = 0.28,      -- list pane width as fraction of total
    border     = "rounded", -- any valid nvim_open_win border value
  },
})
```

## Usage

| Command               | Description                              |
| --------------------- | ---------------------------------------- |
| `:SnipList`           | Open the snippet browser                 |
| `:Snip <title>`       | Paste a snippet at cursor (tab-complete) |
| `:SnipCopy <title>`   | Copy a snippet to the clipboard          |
| `:SnipRun <title>`    | Run a snippet in a terminal split        |
| `:SnipDelete <title>` | Delete a snippet                         |
| `:SnipAdd`            | Add the current file as a snippet        |
| `:'<,'>SnipAdd`       | Add a visual selection as a snippet      |
| `:SnipExport [path]`  | Export all snippets to a JSON file       |
| `:SnipImport <path>`  | Import snippets from a JSON file         |

All commands that take a title support **tab-completion**.

## Browser

Open with `:SnipList`. The left pane is navigable with `j`/`k`. The right
pane updates live as you move through the list.

```
╭─ Snippets (5)  ·  #docker ──╮ ╭─ Preview  ·  bash ────────────────────────╮
│ docker-ps   [bash] #docker   │ │ -- list all containers                    │
│ docker-run  [bash] #docker   │ │                                           │
│ docker-exec [bash] #docker   │ │ docker ps -a \                            │
│ compose-up  [yaml] #docker   │ │   --format "table {{.Names}}\t{{.Status}}"│
│ compose-log [bash] #docker   │ │                                           │
╰─────────────────────────────╯ ╰───────────────────────────────────────────╯
```

The list pane shows each snippet's language and tags inline. The window title
updates to reflect the active filter and count. The preview title shows the
language of the selected snippet.

| Key           | Action                                    |
| ------------- | ----------------------------------------- |
| `j` / `k`     | Navigate                                  |
| `<CR>` / `p`  | Paste snippet at cursor, close browser    |
| `y`           | Copy to clipboard                         |
| `d`           | Delete (confirmation required)            |
| `/`           | Search title, description, tags, language |
| `t`           | Filter by tag (picker)                    |
| `<C-l>`       | Clear all active filters                  |
| `R`           | Reload snippets from snip                 |
| `?`           | Show keymap help overlay                  |
| `q` / `<Esc>` | Close                                     |

All keys are configurable via `setup()`. Press `?` inside the browser to see
the current bindings at any time.

## Extending

snip.nvim is three small modules. New integrations go in their own files —
nothing in the core changes.

**Telescope picker** — create `lua/snip/telescope.lua` in your config and
wire it to a keymap:

```lua
vim.keymap.set("n", "<leader>fs", function()
  require("snip.telescope").picker()
end)
```

See `:help snip-extending` for a full working example.

**Direct data access** — use the CLI module from anywhere:

```lua
local cli     = require("snip.cli")
local titles  = cli.list()        -- string[] of all titles
local snippet = cli.get("title")  -- table|nil for a single snippet
local all     = cli.export()      -- table[] of all snippets in one call
```

`cli.export()` is the preferred way to build any UI that needs the full
library — one subprocess call instead of one per snippet.

## Project structure

```
snip.nvim/
├── lua/snip/
│   ├── init.lua    ← setup() and public API
│   ├── cli.lua     ← snip CLI wrappers
│   ├── ui.lua      ← floating window browser
│   └── health.lua  ← :checkhealth snip
├── plugin/
│   └── snip.lua    ← :Snip* command definitions
└── doc/
    └── snip.nvim.txt
```

## Development

Clone the repo and point Neovim at it:

```lua
-- in your init.lua or a test config
vim.opt.rtp:prepend("/path/to/snip.nvim")
require("snip").setup({})
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs are welcome.

## License

MIT — see [LICENSE](LICENSE).
