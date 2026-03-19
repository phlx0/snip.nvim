#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/phlx0/snip.nvim"
PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/snip/start/snip.nvim"

# ── helpers ──────────────────────────────────────────────────────────────────

ok()   { printf '\033[32m✔\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m  %s\n' "$*"; }
die()  { printf '\033[31m✘\033[0m  %s\n' "$*" >&2; exit 1; }

# ── checks ───────────────────────────────────────────────────────────────────

command -v nvim >/dev/null 2>&1 || die "Neovim is not installed"
command -v git  >/dev/null 2>&1 || die "git is not installed"

nvim_version=$(nvim --version | head -1)
ok "Found $nvim_version"

if ! command -v snip >/dev/null 2>&1; then
  warn "'snip' not found on \$PATH — install it from https://github.com/phlx0/snip"
  warn "snip.nvim will still install, but won't work until snip is available"
fi

# ── install / update ─────────────────────────────────────────────────────────

if [[ -d "$PACK_DIR/.git" ]]; then
  echo "Updating existing installation at $PACK_DIR …"
  git -C "$PACK_DIR" pull --ff-only
  ok "Updated snip.nvim"
else
  echo "Installing snip.nvim to $PACK_DIR …"
  mkdir -p "$(dirname "$PACK_DIR")"
  git clone --depth 1 "$REPO" "$PACK_DIR"
  ok "Installed snip.nvim"
fi

# ── helptags ─────────────────────────────────────────────────────────────────

nvim --headless -c "helptags $PACK_DIR/doc/" -c "quit" 2>/dev/null
ok "Helptags generated — run :help snip.nvim inside Neovim"

# ── done ─────────────────────────────────────────────────────────────────────

echo
echo "snip.nvim is ready. No setup() call is required."
echo "Run :SnipList to open the browser, or :checkhealth snip to verify."
