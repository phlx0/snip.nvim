-- Auto-loaded by Neovim on startup. Registers all :Snip* user commands.

-- Session-scoped title cache for tab-completion.
-- Avoids spawning a subprocess on every <Tab> press.
local _titles    = nil
local _titles_ts = 0
local TTL        = 60 -- seconds

local function titles_cached()
  if not _titles or (os.time() - _titles_ts) > TTL then
    _titles    = require("snip.cli").list()
    _titles_ts = os.time()
  end
  return _titles
end

local function invalidate()
  _titles = nil
end

local function complete(arglead)
  local titles = titles_cached()
  if arglead == "" then return titles end
  local q = arglead:lower()
  return vim.tbl_filter(function(t) return t:lower():find(q, 1, true) ~= nil end, titles)
end

local snip = require("snip")

vim.api.nvim_create_user_command("SnipList", function()
  snip.open()
end, { desc = "Open snip.nvim snippet browser" })

vim.api.nvim_create_user_command("Snip", function(opts)
  snip.paste(opts.args)
end, { nargs = 1, complete = complete, desc = "Paste a snippet below the cursor" })

vim.api.nvim_create_user_command("SnipCopy", function(opts)
  snip.copy(opts.args)
end, { nargs = 1, complete = complete, desc = "Copy a snippet to the clipboard" })

vim.api.nvim_create_user_command("SnipRun", function(opts)
  snip.run(opts.args)
end, { nargs = 1, complete = complete, desc = "Run a snippet in a terminal split" })

vim.api.nvim_create_user_command("SnipDelete", function(opts)
  snip.delete(opts.args)
  invalidate()
end, { nargs = 1, complete = complete, desc = "Delete a snippet" })

vim.api.nvim_create_user_command("SnipAdd", function(opts)
  if opts.range > 0 then
    snip.add_selection(opts.line1, opts.line2)
  else
    snip.add_buf()
  end
  invalidate()
end, { range = true, desc = "Add current file or visual selection as a snippet" })

vim.api.nvim_create_user_command("SnipExport", function(opts)
  local path = opts.args ~= "" and opts.args
    or (vim.fn.stdpath("data") .. "/snip-export.json")
  snip.export(path)
end, { nargs = "?", complete = "file", desc = "Export all snippets to a JSON file" })

vim.api.nvim_create_user_command("SnipImport", function(opts)
  snip.import(opts.args)
  invalidate()
end, { nargs = 1, complete = "file", desc = "Import snippets from a JSON file" })
