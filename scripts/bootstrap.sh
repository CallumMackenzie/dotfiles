#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
notifier_dir="$HOME/.local/share/tmux-notify-jump"
notifier_ref="61f48dbd319af3e010249414c22b6b39661f08e1"

link_path() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$(dirname "$target_path")"
  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    return
  fi
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$target_path" >&2
    return 1
  fi
  ln -s "$source_path" "$target_path"
}

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew is required before running this bootstrap script.\n' >&2
  exit 1
fi

brew bundle --file "$repo_root/Brewfile"

link_path "$repo_root/nvim" "$HOME/.config/nvim"
link_path "$repo_root/tmux/.tmux.conf" "$HOME/.tmux.conf"
link_path "$repo_root/hammerspoon" "$HOME/.hammerspoon"
link_path "$repo_root/wezterm" "$HOME/.config/wezterm"
link_path "$repo_root/git/.gitconfig" "$HOME/.gitconfig"
link_path "$repo_root/zsh/.zshrc" "$HOME/.zshrc"
link_path "$repo_root/zsh/.zprofile" "$HOME/.zprofile"

if [[ ! -e "$HOME/.zshrc.private" ]]; then
  install -m 600 /dev/null "$HOME/.zshrc.private"
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/share"
if [[ ! -d "$notifier_dir/.git" ]]; then
  git clone https://github.com/hmgle/tmux-notify-jump.git "$notifier_dir"
else
  git -C "$notifier_dir" fetch --tags origin
fi
git -C "$notifier_dir" checkout --detach "$notifier_ref"
link_path "$notifier_dir/tmux-notify-jump" "$HOME/.local/bin/tmux-notify-jump"
link_path "$repo_root/scripts/pi-tmux-status" "$HOME/.local/bin/pi-tmux-status"
link_path "$repo_root/pi/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
link_path "$repo_root/pi/extensions/tmux-notify.ts" "$HOME/.pi/agent/extensions/tmux-notify.ts"
link_path "$repo_root/pi/extensions/ascii-splash.ts" "$HOME/.pi/agent/extensions/ascii-splash.ts"
link_path "$repo_root/pi/mcp/mcp-google-drive-compat.mjs" "$HOME/.local/bin/pi-mcp-google-drive-compat.mjs"
link_path "$repo_root/pi/mcp/leetcode-mcp-keychain" "$HOME/.local/bin/pi-leetcode-mcp-keychain"
link_path "$repo_root/pi/mcp/course-tracker-mcp" "$HOME/.local/bin/pi-course-tracker-mcp"
bash "$repo_root/scripts/setup-pi-mcp.sh" "$repo_root/pi"
bash "$repo_root/scripts/configure-pi-models.sh" \
  "$HOME/.pi/agent/settings.json" "$repo_root/pi/model-defaults.json"

python_bin="$(brew --prefix python@3.14)/bin/python3.14"
"$python_bin" -m venv "$HOME/.venvs/neovim"
"$HOME/.venvs/neovim/bin/python" -m pip install --upgrade pip
"$HOME/.venvs/neovim/bin/python" -m pip install -r "$repo_root/python/neovim-requirements.txt"

printf 'Bootstrap complete. Reload zsh and tmux, then allow terminal-notifier in macOS Notifications.\n'
