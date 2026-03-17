-- Two-pane floating window browser.
-- Left pane: navigable snippet list with inline lang/tag hints.
-- Right pane: live preview with syntax highlighting.
-- All sizing and keymaps come from require("snip").config.

local M = {}

local cli = require("snip.cli")
local ns  = vim.api.nvim_create_namespace("snip")

local state = {
  frame_buf    = nil,
  frame_win    = nil,  -- outer border window; holds the centered "Snippets (N)" title
  list_buf     = nil,
  list_win     = nil,
  preview_buf  = nil,
  preview_win  = nil,
  titles       = {},   -- ordered list of all titles
  filtered     = {},   -- titles after current filter
  orig_win     = nil,  -- window to return focus to on paste
  cache        = {},   -- title → snippet table (populated from --export on open)
  last_preview = nil,  -- title currently rendered in preview pane
  query        = "",   -- active text search
  tag          = "",   -- active tag filter
  list_w       = 40,   -- fallback width used before the window is created
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function make_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  return buf
end

local function float_opts(row, col, width, height, title, cfg)
  return {
    relative  = "editor",
    row       = row,
    col       = col,
    width     = width,
    height    = height,
    style     = "minimal",
    border    = cfg.ui.border,
    title     = " " .. title .. " ",
    title_pos = "center",
  }
end

local function current_title()
  if not (state.list_win and vim.api.nvim_win_is_valid(state.list_win)) then return nil end
  return state.filtered[vim.api.nvim_win_get_cursor(state.list_win)[1]]
end

-- ---------------------------------------------------------------------------
-- Filtering
-- ---------------------------------------------------------------------------

local function apply_filter()
  local q   = state.query:lower()
  local tag = state.tag:lower()

  state.filtered = vim.tbl_filter(function(title)
    local s = state.cache[title]

    -- Tag filter: must have the exact tag
    if tag ~= "" then
      if not (s and s.tags) then return false end
      local match = false
      for _, t in ipairs(s.tags) do
        if t:lower() == tag then match = true; break end
      end
      if not match then return false end
    end

    -- Text search: title, description, language, tags
    if q ~= "" then
      if title:lower():find(q, 1, true) then return true end
      if s then
        if s.description and s.description:lower():find(q, 1, true) then return true end
        if s.language and s.language:lower():find(q, 1, true) then return true end
        if s.tags then
          for _, t in ipairs(s.tags) do
            if t:lower():find(q, 1, true) then return true end
          end
        end
      end
      return false
    end

    return true
  end, state.titles)
end

-- ---------------------------------------------------------------------------
-- Window title helpers
-- ---------------------------------------------------------------------------

local function list_title()
  local n, total = #state.filtered, #state.titles
  local count = n == total and ("(%d)"):format(total) or ("(%d/%d)"):format(n, total)
  local parts = {}
  if state.query ~= "" then table.insert(parts, state.query) end
  if state.tag   ~= "" then table.insert(parts, "#" .. state.tag) end
  local filter = #parts > 0 and ("  ·  " .. table.concat(parts, "  ")) or ""
  return "Snippets " .. count .. filter
end

local function set_list_title()
  if state.frame_win and vim.api.nvim_win_is_valid(state.frame_win) then
    vim.api.nvim_win_set_config(state.frame_win, {
      title = " " .. list_title() .. " ", title_pos = "center",
    })
  end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

local function render_list()
  -- Use the actual rendered window width so truncation is always accurate.
  local win_w = (state.list_win and vim.api.nvim_win_is_valid(state.list_win))
    and vim.api.nvim_win_get_width(state.list_win)
    or state.list_w

  vim.bo[state.list_buf].modifiable = true

  local display     = {}
  local virt_chunks = {}

  for i, title in ipairs(state.filtered) do
    local s = state.cache[title]
    local virt     = {}
    local virt_len = 0

    if s then
      if s.language and s.language ~= "" then
        local chunk = "  [" .. s.language .. "]"
        table.insert(virt, { chunk, "Comment" })
        virt_len = virt_len + #chunk
      end
      if s.tags and #s.tags > 0 then
        local tag_str = "  " .. table.concat(
          vim.tbl_map(function(t) return "#" .. t end, s.tags), " "
        )
        table.insert(virt, { tag_str, "Special" })
        virt_len = virt_len + #tag_str
      end
    end

    local shown
    if virt_len > 0 then
      local max_title = math.max(1, win_w - virt_len - 1)
      shown = #title > max_title and (title:sub(1, max_title - 1) .. "…") or title
    else
      shown = title
    end

    table.insert(display, shown)
    if #virt > 0 then virt_chunks[i] = virt end
  end

  -- Write lines first; extmarks must come after or set_lines clears them.
  vim.api.nvim_buf_set_lines(state.list_buf, 0, -1, false, display)
  vim.api.nvim_buf_clear_namespace(state.list_buf, ns, 0, -1)
  for i, virt in pairs(virt_chunks) do
    vim.api.nvim_buf_set_extmark(state.list_buf, ns, i - 1, 0, {
      virt_text = virt, virt_text_pos = "eol",
    })
  end

  vim.bo[state.list_buf].modifiable = false
  set_list_title()
end

local function update_preview()
  if not (state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf)) then return end
  local title = current_title()
  if not title or title == state.last_preview then return end
  state.last_preview = title

  -- Fetch once; reuse on revisit.
  if state.cache[title] == nil then
    state.cache[title] = cli.get(title) or false
  end
  local snippet = state.cache[title]
  local lines, ft = {}, "text"

  if snippet then
    if snippet.description and snippet.description ~= "" then
      vim.list_extend(lines, { "-- " .. snippet.description, "" })
    end
    if snippet.tags and #snippet.tags > 0 then
      vim.list_extend(lines, { "-- tags: " .. table.concat(snippet.tags, ", "), "" })
    end
    local content = snippet.content or snippet.code or ""
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
    if snippet.language and snippet.language ~= "" then ft = snippet.language:lower() end
  else
    lines = { "(preview unavailable)" }
  end

  vim.bo[state.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
  vim.bo[state.preview_buf].modifiable = false
  pcall(function() vim.bo[state.preview_buf].filetype = ft end)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

function M.close()
  for _, win in ipairs({ state.list_win, state.preview_win, state.frame_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  state.frame_buf, state.frame_win   = nil, nil
  state.list_buf, state.list_win     = nil, nil
  state.preview_buf, state.preview_win = nil, nil
  state.cache, state.last_preview    = {}, nil
  state.query, state.tag             = "", ""
end

local function action_paste()
  local title = current_title()
  if not title then return end
  -- Use cached data; skip live fetch when cache recorded a prior failure.
  local cached = state.cache[title]
  local snippet
  if type(cached) == "table" then
    snippet = cached
  elseif cached == false then
    vim.notify("snip: could not fetch '" .. title .. "'", vim.log.levels.ERROR)
    return
  else
    snippet = cli.get(title)
  end
  if not snippet then
    vim.notify("snip: could not fetch '" .. title .. "'", vim.log.levels.ERROR)
    return
  end
  local orig = state.orig_win
  M.close()
  local content = snippet.content or snippet.code or ""
  local lines = vim.split(content, "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  if orig and vim.api.nvim_win_is_valid(orig) then
    vim.api.nvim_set_current_win(orig)
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
end

local function action_yank()
  local title = current_title()
  if not title then return end
  if cli.copy(title) then
    vim.notify("snip: copied '" .. title .. "' to clipboard")
  else
    vim.notify("snip: failed to copy '" .. title .. "'", vim.log.levels.ERROR)
  end
end

local function action_delete()
  local title = current_title()
  if not title then return end
  vim.ui.select({ "Yes", "No" }, { prompt = "Delete '" .. title .. "'?" }, function(choice)
    if choice ~= "Yes" then return end
    local ok, err = cli.delete(title)
    if ok then
      vim.notify("snip: deleted '" .. title .. "'")
      state.cache[title] = nil
      state.titles = vim.tbl_filter(function(t) return t ~= title end, state.titles)
      local row = vim.api.nvim_win_get_cursor(state.list_win)[1]
      apply_filter()
      render_list()
      state.last_preview = nil
      if #state.filtered > 0 then
        vim.api.nvim_win_set_cursor(state.list_win, { math.min(row, #state.filtered), 0 })
      end
      update_preview()
    else
      vim.notify("snip: " .. (err or "delete failed"), vim.log.levels.ERROR)
    end
  end)
end

local function action_search()
  vim.ui.input({ prompt = "Search: ", default = state.query }, function(query)
    if query == nil then return end
    state.query = query
    apply_filter()
    render_list()
    if #state.filtered > 0 then
      vim.api.nvim_win_set_cursor(state.list_win, { 1, 0 })
    end
    state.last_preview = nil
    update_preview()
  end)
end

local function action_tag_filter()
  local seen, tags = {}, {}

  local function collect()
    for _, title in ipairs(state.titles) do
      local s = state.cache[title]
      if s and s.tags then
        for _, t in ipairs(s.tags) do
          if not seen[t] then seen[t] = true; table.insert(tags, t) end
        end
      end
    end
  end

  collect()

  -- Cache was cold (--export failed or not supported on open); try now.
  if #tags == 0 and #state.titles > 0 then
    local all = cli.export()
    if #all > 0 then
      for _, snippet in ipairs(all) do
        if snippet.title then state.cache[snippet.title] = snippet end
      end
      seen, tags = {}, {}
      collect()
      render_list() -- refresh virtual text now that cache is warm
    end
  end

  table.sort(tags)

  if #tags == 0 then
    vim.notify("snip: no tags found", vim.log.levels.INFO)
    return
  end

  table.insert(tags, 1, "(clear)")
  vim.ui.select(tags, { prompt = "Filter by tag: " }, function(choice)
    if not choice then return end
    state.tag = choice == "(clear)" and "" or choice
    apply_filter()
    render_list()
    if #state.filtered > 0 then
      vim.api.nvim_win_set_cursor(state.list_win, { 1, 0 })
    end
    state.last_preview = nil
    update_preview()
  end)
end

local function action_clear()
  state.query, state.tag = "", ""
  apply_filter()
  render_list()
  if #state.filtered > 0 then
    vim.api.nvim_win_set_cursor(state.list_win, { 1, 0 })
  end
  state.last_preview = nil
  update_preview()
end

local function action_help()
  local km  = require("snip").config.keymaps
  local cfg = require("snip").config
  local function fmt(k)
    return type(k) == "table" and table.concat(k, " / ") or k
  end

  local rows = {
    { fmt(km.paste),      "paste snippet into buffer" },
    { fmt(km.yank),       "copy to clipboard" },
    { fmt(km.delete),     "delete snippet" },
    { fmt(km.search),     "search" },
    { fmt(km.tag_filter), "filter by tag" },
    { fmt(km.clear),      "clear all filters" },
    { fmt(km.refresh),    "refresh from snip" },
    { fmt(km.help),       "this help" },
    { fmt(km.close),      "close browser" },
  }

  local key_w = 0
  for _, r in ipairs(rows) do key_w = math.max(key_w, #r[1]) end

  local lines = { "" }
  for _, r in ipairs(rows) do
    table.insert(lines, ("  %-" .. key_w .. "s   %s"):format(r[1], r[2]))
  end
  vim.list_extend(lines, { "", "  press any key to dismiss", "" })

  local width = 0
  for _, l in ipairs(lines) do width = math.max(width, #l) end
  width = width + 2

  local buf = make_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    row       = math.floor((vim.o.lines   - #lines) / 2),
    col       = math.floor((vim.o.columns - width)  / 2),
    width     = width,
    height    = #lines,
    style     = "minimal",
    border    = cfg.ui.border,
    title     = " Help ",
    title_pos = "center",
  })

  local function close_help()
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
      vim.api.nvim_set_current_win(state.list_win)
    end
  end

  -- Derive dismiss keys from the live config so custom bindings always work.
  local dismiss = {}
  for _, v in pairs(require("snip").config.keymaps) do
    if type(v) == "table" then
      for _, k in ipairs(v) do dismiss[k] = true end
    else
      dismiss[v] = true
    end
  end
  for _, k in ipairs({ "j", "k", "g", "G", "<C-d>", "<C-u>", "<C-f>", "<C-b>" }) do
    dismiss[k] = true
  end
  for k in pairs(dismiss) do
    vim.keymap.set("n", k, close_help, { buffer = buf, nowait = true, silent = true })
  end
  vim.api.nvim_create_autocmd("BufLeave", { buffer = buf, once = true, callback = close_help })
end

local function action_refresh()
  state.cache        = {}
  state.last_preview = nil

  local all = cli.export()
  state.titles = {}
  if #all > 0 then
    for _, snippet in ipairs(all) do
      if snippet.title then
        table.insert(state.titles, snippet.title)
        state.cache[snippet.title] = snippet
      end
    end
  else
    state.titles = cli.list()
  end

  apply_filter()
  render_list()
  if #state.filtered > 0 then
    vim.api.nvim_win_set_cursor(state.list_win, { 1, 0 })
  end
  update_preview()
  vim.notify("snip: refreshed")
end

-- ---------------------------------------------------------------------------
-- Keymap wiring
-- ---------------------------------------------------------------------------

local function set_keymaps()
  local km = require("snip").config.keymaps
  local function map(keys, fn, desc)
    local opts = { buffer = state.list_buf, nowait = true, silent = true, desc = desc }
    for _, k in ipairs(type(keys) == "table" and keys or { keys }) do
      vim.keymap.set("n", k, fn, opts)
    end
  end

  map(km.close,      M.close,           "Close browser")
  map(km.paste,      action_paste,      "Paste snippet into buffer")
  map(km.yank,       action_yank,       "Copy to clipboard")
  map(km.delete,     action_delete,     "Delete snippet")
  map(km.search,     action_search,     "Search snippets")
  map(km.tag_filter, action_tag_filter, "Filter by tag")
  map(km.clear,      action_clear,      "Clear all filters")
  map(km.refresh,    action_refresh,    "Refresh from snip")
  map(km.help,       action_help,       "Show keymap help")
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------

function M.open()
  state.orig_win     = vim.api.nvim_get_current_win()
  state.cache        = {}
  state.last_preview = nil
  state.query        = ""
  state.tag          = ""
  state.titles       = {}

  -- Pre-fetch everything in one CLI call so navigation is instant.
  local all = cli.export()
  if #all > 0 then
    for _, snippet in ipairs(all) do
      if snippet.title then
        table.insert(state.titles, snippet.title)
        state.cache[snippet.title] = snippet
      end
    end
  else
    -- export not supported or failed; fall back to title-only listing.
    state.titles = cli.list()
  end

  if #state.titles == 0 then
    local cmd = require("snip").config.cmd
    if vim.fn.executable(cmd) == 0 then
      vim.notify(
        ("snip: executable not found: '%s'\nInstall snip: https://github.com/phlx0/snip"):format(cmd),
        vim.log.levels.ERROR
      )
    else
      vim.notify("snip: no snippets found — add one with :SnipAdd", vim.log.levels.WARN)
    end
    return
  end

  state.filtered = vim.deepcopy(state.titles)

  local cfg       = require("snip").config
  local cols      = vim.o.columns
  local rows      = vim.o.lines
  local total_w   = math.floor(cols * cfg.ui.width)
  local total_h   = math.floor(rows * cfg.ui.height)
  local list_w    = math.floor(total_w * cfg.ui.list_ratio)
  -- preview fills the remaining space inside the frame (1 col taken by the separator)
  local preview_w = total_w - list_w - 1
  local start_row = math.floor((rows - total_h) / 2)
  local start_col = math.floor((cols - total_w) / 2)
  state.list_w    = list_w

  -- Outer frame: rounded border spanning both panes; holds the centered title.
  state.frame_buf = make_buf()
  state.frame_win = vim.api.nvim_open_win(state.frame_buf, false, {
    relative  = "editor",
    row       = start_row,
    col       = start_col,
    width     = total_w,
    height    = total_h,
    style     = "minimal",
    border    = cfg.ui.border,
    title     = " " .. list_title() .. " ",
    title_pos = "center",
    focusable = false,
    zindex    = 49,
  })

  -- List pane: positioned inside the frame, right-side separator only.
  state.list_buf = make_buf()
  state.list_win = vim.api.nvim_open_win(state.list_buf, true, {
    relative  = "editor",
    row       = start_row + 1,
    col       = start_col + 1,
    width     = list_w,
    height    = total_h,
    style     = "minimal",
    border    = { "", "", "", "│", "", "", "", "" },
    focusable = true,
    zindex    = 50,
  })
  vim.wo[state.list_win].cursorline = true
  vim.wo[state.list_win].number     = false
  vim.wo[state.list_win].wrap       = false

  -- Preview pane: positioned inside the frame, no border.
  state.preview_buf = make_buf()
  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, {
    relative  = "editor",
    row       = start_row + 1,
    col       = start_col + list_w + 2,
    width     = preview_w,
    height    = total_h,
    style     = "minimal",
    border    = "none",
    focusable = false,
    zindex    = 50,
  })
  vim.wo[state.preview_win].number = true
  vim.wo[state.preview_win].wrap   = false

  render_list()
  set_keymaps()

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer   = state.list_buf,
    callback = update_preview,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern  = tostring(state.list_win),
    once     = true,
    callback = function()
      for _, win in ipairs({ state.preview_win, state.frame_win }) do
        if win and vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end,
  })

  vim.api.nvim_win_set_cursor(state.list_win, { 1, 0 })
  update_preview()
end

return M
