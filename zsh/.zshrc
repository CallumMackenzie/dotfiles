if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

export PATH="$HOME/.local/bin:$PATH"
[[ -r "$HOME/.zshrc.private" ]] && source "$HOME/.zshrc.private"

# Pi detects its tmux pane directly via the pi-tmux-notify extension.
# Launch normally with `pi`; no session wrapper or gateway is needed.

# Run the repository-root Makefile from anywhere inside a Git repository.
nbm() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel)" || return
    make -C "$repo_root" "$@"
}

alias ftl="sed -E 's/^[^Z]*Z[[:space:]]*//'"

# rbenv initializes above and may prepend Homebrew-managed tools. Prefer the
# declarative profile for global commands while retaining its shims as a
# fallback for explicitly selected Ruby versions.
typeset -U path PATH
path=("$HOME/.local/bin" "/etc/profiles/per-user/$USER/bin" /run/current-system/sw/bin $path)
