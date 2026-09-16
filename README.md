# dotfiles

Personal configuration for Neovim and tmux.

## Install

Clone the repository into `~/Downloads/dotfiles`, then create the symlinks:

```sh
mkdir -p ~/.config
ln -s ~/Downloads/dotfiles/nvim ~/.config/nvim
ln -s ~/Downloads/dotfiles/tmux/.tmux.conf ~/.tmux.conf
```

Neovim plugins are restored automatically from `nvim/lazy-lock.json` by lazy.nvim.
Downloaded plugins and tmux plugin files are intentionally not stored in this repository.
