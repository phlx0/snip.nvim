local M = {}

M.version = "0.3.0"

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

M.config = {
  -- Path or name of the snip executable.
  cmd = "snip",

  -- Keymaps active inside the browser window.
  -- Each value is a key string or a list of key strings.
  keymaps = {
    paste      = { "<CR>", "p" },  -- paste snippet into buffer, close browser
    yank       = "y",              -- copy snippet to system clipboard
    delete     = "d",              -- delete snippet (with confirmation)
    search     = "/",              -- search title, description, tags, language
    tag_filter = "t",              -- pick a tag to filter by
    clear      = "<C-l>",         -- clear all active filters
    refresh    = "R",              -- reload all snippets from snip
    help       = "?",              -- show keymap help
    close      = { "q", "<Esc>" }, -- close the browser
  },

  -- Floating window dimensions (all values are fractions, 0–1).
  ui = {
    width      = 0.85,      -- fraction of &columns
    height     = 0.80,      -- fraction of &lines
    list_ratio = 0.28,      -- fraction of total width used by the list pane
    border     = "rounded", -- any valid nvim_open_win border value
  },
}

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

--- Merge user options into the default config.
--- Call this once in your Neovim config; it is entirely optional.
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Open the interactive snippet browser.
function M.open()
  require("snip.ui").open()
end

--- Paste snippet {title} below the current cursor line.
function M.paste(title)
  local snippet = require("snip.cli").get(title)
  if not snippet then
    vim.notify("snip: '" .. title .. "' not found", vim.log.levels.ERROR)
    return
  end
  local content = snippet.content or ""
  local lines = vim.split(content, "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
end

--- Copy snippet {title} to the system clipboard via the snip CLI.
function M.copy(title)
  if require("snip.cli").copy(title) then
    vim.notify("snip: copied '" .. title .. "' to clipboard")
  else
    vim.notify("snip: failed to copy '" .. title .. "'", vim.log.levels.ERROR)
  end
end

--- Run snippet {title} in a terminal split.
function M.run(title)
  require("snip.cli").run(title)
end

--- Delete snippet {title}.
function M.delete(title)
  local ok, err = require("snip.cli").delete(title)
  if ok then
    vim.notify("snip: deleted '" .. title .. "'")
  else
    vim.notify("snip: " .. (err or "delete failed"), vim.log.levels.ERROR)
  end
end

--- Add the current buffer's file as a snippet.
--- The snippet title is derived from the filename (without extension).
function M.add_buf()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("snip: buffer has no file — save it first", vim.log.levels.ERROR)
    return
  end
  local ok, err = require("snip.cli").add_file(path)
  if ok then
    vim.notify("snip: added '" .. vim.fn.fnamemodify(path, ":t:r") .. "'")
  else
    vim.notify("snip: " .. (err or "add failed"), vim.log.levels.ERROR)
  end
end

--- Export all snippets to {path} as JSON.
--- Defaults to {stdpath("data")}/snip-export.json when path is omitted.
function M.export(path)
  local ok, err = require("snip.cli").export_to(path)
  if ok then
    vim.notify("snip: exported to " .. path)
  else
    vim.notify("snip: " .. (err or "export failed"), vim.log.levels.ERROR)
  end
end

--- Import snippets from a JSON file at {path}.
function M.import(path)
  if not path or path == "" then
    vim.notify("snip: path required", vim.log.levels.ERROR)
    return
  end
  local ok, err = require("snip.cli").import_from(path)
  if ok then
    vim.notify("snip: imported from " .. path)
  else
    vim.notify("snip: " .. (err or "import failed"), vim.log.levels.ERROR)
  end
end

--- Add lines {line1}–{line2} of the current buffer as a snippet.
--- Prompts for a title. File extension is inferred from the buffer's filetype.
function M.add_selection(line1, line2)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  local ft = vim.bo.filetype
  local ext = (ft ~= "" and ft ~= "text") and ("." .. ft) or ""

  vim.ui.input({ prompt = "Snippet title: " }, function(title)
    if not title or title == "" then return end

    -- Write to a temp file named <title>.<ext> so snip picks up the right title.
    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    local tmpfile = tmpdir .. "/" .. title .. ext

    local file = io.open(tmpfile, "w")
    if not file then
      vim.notify("snip: could not write temp file", vim.log.levels.ERROR)
      return
    end
    file:write(table.concat(lines, "\n"))
    file:close()

    local ok, err = require("snip.cli").add_file(tmpfile)
    os.remove(tmpfile)
    pcall(vim.fn.delete, tmpdir, "d")

    if ok then
      vim.notify("snip: added '" .. title .. "'")
    else
      vim.notify("snip: " .. (err or "add failed"), vim.log.levels.ERROR)
    end
  end)
end

return M
