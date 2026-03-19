# Changelog

All notable changes to snip.nvim are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project uses [semantic versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] — 2026-03-19

### Added

- Pinned snippets are now indicated in the browser list with a `[pin]` virtual
  text hint (highlighted via `DiagnosticHint`) and a `-- [pinned]` header line
  in the preview pane — adapts to the `pinned` field introduced in snip v0.7.0

### Changed

- `cli.export()` now expects a bare JSON array from `--export`; the dead
  `{ snippets: [...] }` fallback has been removed
- `snippet.content` is the only supported content field; the unused `snippet.code`
  fallback has been removed throughout `ui.lua` and `init.lua`
- Updated field documentation: `cli.get()` and `cli.export()` now document
  `id` (12-character hex string, changed from integer in snip v0.7.0) and `pinned`
- Introduction updated to reflect snip's file-based storage (Markdown files +
  SQLite index) introduced in v0.7.0

## [0.2.0] — 2026-03-19

### Added

- `install.sh` — one-line manual install for users who don't use a package manager; clones to the standard Neovim pack path, generates helptags, and doubles as an updater when run again

## [0.1.0] — 2026-03-17

### Commands

- `:SnipList` — open the two-pane floating window browser
- `:Snip <title>` — paste a snippet below the cursor (tab-completion)
- `:SnipCopy <title>` — copy a snippet to the system clipboard (tab-completion)
- `:SnipRun <title>` — run a snippet in a terminal split (tab-completion)
- `:SnipDelete <title>` — delete a snippet with confirmation (tab-completion)
- `:SnipAdd` — add the current buffer's file as a snippet
- `:'<,'>SnipAdd` — add a visual selection as a snippet (prompts for title, infers filetype)
- `:SnipExport [path]` — exports all snippets to a JSON file (defaults to `{stdpath("data")}/snip-export.json`)
- `:SnipImport <path>` — imports snippets from a JSON file

### Browser

- Two-pane floating window: navigable snippet list on the left, live preview on the right
- Preview shows description, tags, and content with syntax highlighting from the snippet's recorded language
- All snippet data is fetched in one CLI call on open (via `--export`), making navigation instant from the first keypress
- Inline language and tag hints on each list row via virtual text
- Dynamic list window title showing count and active filters, e.g. `Snippets (3/12)  ·  #docker`
- Dynamic preview window title showing the snippet's language, e.g. `Preview  ·  bash`
- Tag filter (`t`) — pick any tag from a list, instantly narrows the browser
- Search (`/`) matches title, description, language, and tags
- Clear all filters with `<C-l>`
- Refresh snippets from snip without closing the browser with `R`
- Paste at cursor with `<CR>` / `p`, copy to clipboard with `y`, delete with `d`, close with `q` / `<Esc>`
- Delete preserves the active filter and cursor position instead of resetting the list
- Help overlay (`?`) shows all current bindings; dismiss keys derived from live config so custom keymaps always work
- All keymaps configurable via `setup()`; each key accepts a string or a list of strings

### Configuration

- `setup()` with full config table: `cmd`, `keymaps`, `ui.width`, `ui.height`, `ui.list_ratio`, `ui.border`
- `cmd` defaults to `"snip"` — override to use a non-`$PATH` binary
- All UI dimensions are fractions (0–1) of the editor size
- `border` accepts any valid `nvim_open_win` border value

### Tab-completion

- All commands that accept a title support tab-completion
- Completion list is cached for 60 seconds; no subprocess on every `<Tab>` press
- Cache is invalidated automatically after add, delete, or import

### Lua API

- `require("snip").open()` — open the browser
- `require("snip").paste(title)` — paste a snippet programmatically
- `require("snip").copy(title)` — copy a snippet programmatically
- `require("snip").run(title)` — run a snippet programmatically
- `require("snip").delete(title)` — delete a snippet programmatically
- `require("snip").add_buf()` — add the current buffer as a snippet
- `require("snip").add_selection(line1, line2)` — add a line range as a snippet
- `require("snip").export(path)` — export all snippets to JSON
- `require("snip").import(path)` — import snippets from JSON
- `require("snip.cli")` exposed as a stable data API for extensions
- `cli.export()` — batch-fetches all snippet data in one CLI call; preferred for building UIs

### Health check

- `:checkhealth snip` — verifies the snip executable is found and callable, `--export` works, and Neovim ≥ 0.10

### Tooling

- `.luacheckrc` for consistent local linting (`luacheck lua/ plugin/`)
- `.stylua.toml` defining the canonical code style
- CI: `luacheck` + `stylua --check` on every push and PR
- CI: Neovim headless job that generates and validates `doc/tags`
- Issue templates (bug report, feature request) with structured forms
- PR template with manual test, lint, formatting, docs, and changelog checklist
- Blank issues disabled; questions redirected to Discussions

### Docs

- Vimdoc at `:help snip.nvim` covering setup, all commands, browser keymaps, full API, and an extending guide with a working Telescope example

[Unreleased]: https://github.com/phlx0/snip.nvim/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/phlx0/snip.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/phlx0/snip.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/phlx0/snip.nvim/releases/tag/v0.1.0
