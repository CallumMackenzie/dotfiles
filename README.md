# dotfiles

Personal configuration for Neovim, tmux, Hammerspoon, Ghostty, and Git.

## Install

Clone the repository into `~/Downloads/dotfiles`, then create the symlinks:

```sh
mkdir -p ~/.config "$HOME/Library/Application Support/com.mitchellh.ghostty"
ln -s ~/Downloads/dotfiles/nvim ~/.config/nvim
ln -s ~/Downloads/dotfiles/tmux/.tmux.conf ~/.tmux.conf
ln -s ~/Downloads/dotfiles/hammerspoon ~/.hammerspoon
ln -s ~/Downloads/dotfiles/ghostty/config.ghostty \
  "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
ln -s ~/Downloads/dotfiles/git/.gitconfig ~/.gitconfig
```

Neovim plugins are restored automatically from `nvim/lazy-lock.json` by lazy.nvim.
Downloaded plugins and tmux plugin files are intentionally not stored in this repository.
