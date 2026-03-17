local M = {}

function M.check()
  vim.health.start("snip.nvim")

  local cfg = require("snip").config
  local cmd = cfg.cmd

  -- snip executable
  if vim.fn.executable(cmd) == 1 then
    vim.health.ok("snip executable found: " .. vim.fn.exepath(cmd))
  else
    vim.health.error(
      ("snip executable not found: '%s'"):format(cmd),
      "Install snip: https://github.com/phlx0/snip"
    )
    return
  end

  -- snip is callable and returns a version
  local result = vim.system({ cmd, "--version" }, { text = true }):wait()
  if result.code == 0 then
    local version = vim.trim(result.stdout or "")
    vim.health.ok("snip version: " .. (version ~= "" and version or "unknown"))
  else
    vim.health.warn(
      "snip --version returned a non-zero exit code",
      "snip may be broken or an incompatible version"
    )
  end

  -- --export (used for batch pre-fetch; degraded performance if broken)
  local exp = vim.system({ cmd, "--export" }, { text = true }):wait()
  if exp.code == 0 then
    local ok = pcall(vim.json.decode, exp.stdout or "")
    if ok then
      vim.health.ok("--export works — browser navigation will be instant")
    else
      vim.health.warn(
        "--export returned invalid JSON",
        "Navigation falls back to per-snippet fetching (slower first visit per snippet)"
      )
    end
  else
    vim.health.warn(
      "--export failed or is not supported by this snip version",
      "Navigation falls back to per-snippet fetching (slower first visit per snippet)"
    )
  end

  -- Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim 0.10+ is required")
  end
end

return M
