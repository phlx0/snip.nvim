-- Thin wrappers around the snip CLI.
-- All subprocess calls go through here; nothing else touches vim.system.

local M = {}

local function exec(args)
  local cmd = require("snip").config.cmd
  local result = vim.system(vim.list_extend({ cmd }, args), { text = true }):wait()
  return result.stdout or "", result.stderr or "", result.code
end

--- Returns all snippet titles as a list of strings.
function M.list()
  local out, _, code = exec({ "--list" })
  if code ~= 0 then return {} end
  local titles = {}
  for line in out:gmatch("[^\n]+") do
    local t = vim.trim(line)
    if t ~= "" then table.insert(titles, t) end
  end
  return titles
end

--- Returns snippet metadata for {title} as a table, or nil on failure.
--- Fields: id (string), title, content, language, description, tags, pinned
function M.get(title)
  local out, _, code = exec({ "--json", title })
  if code ~= 0 or out == "" then return nil end
  local ok, data = pcall(vim.json.decode, out)
  return ok and data or nil
end

--- Exports all snippets in one call. Returns a list of snippet tables.
--- Used to pre-populate the browser cache so navigation is instant.
--- Each table has: title, content, language, description, tags, pinned.
function M.export()
  local out, _, code = exec({ "--export" })
  if code ~= 0 or out == "" then return {} end
  local ok, data = pcall(vim.json.decode, out)
  if not ok or not vim.islist(data) then return {} end
  return data
end

--- Copies {title} to the system clipboard via the snip CLI. Returns bool.
function M.copy(title)
  local _, _, code = exec({ title })
  return code == 0
end

--- Opens a terminal split and runs {title} as a shell command.
function M.run(title)
  local cmd = vim.fn.shellescape(require("snip").config.cmd)
  vim.cmd("split | terminal " .. cmd .. " run " .. vim.fn.shellescape(title))
end

--- Deletes {title}. Returns (true, nil) or (false, err_string).
function M.delete(title)
  local _, err, code = exec({ "--delete", title })
  if code ~= 0 then return false, err end
  return true, nil
end

--- Adds {path} as a snippet. Title is derived from the filename by snip.
--- Returns (true, nil) or (false, err_string).
function M.add_file(path)
  local _, err, code = exec({ "--add", path })
  if code ~= 0 then return false, err end
  return true, nil
end

--- Exports all snippets to {path} as JSON.
--- Returns (true, nil) or (false, err_string).
function M.export_to(path)
  local out, err, code = exec({ "--export" })
  if code ~= 0 then return false, err end
  local file = io.open(path, "w")
  if not file then return false, "cannot write to " .. path end
  file:write(out)
  file:close()
  return true, nil
end

--- Imports snippets from a JSON file at {path}.
--- Returns (true, nil) or (false, err_string).
function M.import_from(path)
  local _, err, code = exec({ "--import", path })
  if code ~= 0 then return false, err end
  return true, nil
end

return M
