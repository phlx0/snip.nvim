std = "lua51"
globals = { "vim" }

-- Ignore unused self in methods and unused arguments in callbacks
ignore = { "212" }

max_line_length = false

files["plugin/snip.lua"] = {
  globals = { "vim" },
}
