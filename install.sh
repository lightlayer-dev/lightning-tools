#!/bin/bash
# ⚡ Lightning Tools — Install fast CLI alternatives
set -euo pipefail

echo "⚡ Installing lightning tools..."

# Detect OS and package manager
install_tool() {
  local name="$1"
  local bin="$2"
  local apt_pkg="$3"
  local brew_pkg="$4"

  if command -v "$bin" &>/dev/null; then
    echo "  ✓ $name ($bin) already installed"
    return
  fi

  if command -v apt &>/dev/null; then
    echo "  → Installing $name via apt ($apt_pkg)..."
    sudo apt install -y "$apt_pkg" 2>/dev/null || echo "  ✗ Failed to install $name via apt"
  elif command -v brew &>/dev/null; then
    echo "  → Installing $name via brew ($brew_pkg)..."
    brew install "$brew_pkg" 2>/dev/null || echo "  ✗ Failed to install $name via brew"
  else
    echo "  ✗ No supported package manager found for $name. Install manually."
  fi
}

# Install each tool
# Args: display_name, binary_name, apt_package, brew_package
install_tool "ripgrep"  "rg"    "ripgrep"   "ripgrep"
install_tool "fd"       "fd"    "fd-find"   "fd"
install_tool "bat"      "bat"   "bat"       "bat"
install_tool "dust"     "dust"  "dust"      "dust"
install_tool "sd"       "sd"    "sd"        "sd"

# Handle fd-find alias on Ubuntu/Debian (binary is fdfind, not fd)
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  echo "  → Creating fd symlink for fdfind..."
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# Handle bat alias on Ubuntu/Debian (binary is batcat, not bat)
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  echo "  → Creating bat symlink for batcat..."
  sudo ln -sf "$(which batcat)" /usr/local/bin/bat
fi

echo ""
echo "⚡ Done! Installed tools:"
for bin in rg fd bat dust sd; do
  if command -v "$bin" &>/dev/null; then
    echo "  ✓ $bin → $(which $bin)"
  else
    echo "  ✗ $bin not found"
  fi
done
