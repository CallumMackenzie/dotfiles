if command -v rbenv >/dev/null 2>&1; then
    eval "$(rbenv init -)"
fi

export PATH="$HOME/.local/bin:$PATH"
[[ -r "$HOME/.zshrc.private" ]] && source "$HOME/.zshrc.private"

# OpenClaw completion
[[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

# Launch an OpenClaw TUI with a tmux-derived session and record where
# completion notifications should return. Explicit --session values are
# supported when they contain only letters, numbers, dots, underscores, or dashes.
oc() {
    if [[ -z "$TMUX_PANE" || -z "$TMUX" ]]; then
        command openclaw tui "$@"
        return
    fi

    local session_key=""
    local tmux_target tmux_socket tmux_session_id state_dir mapping_file
    local -a tui_args
    local i

    tui_args=("$@")
    for ((i = 1; i <= ${#tui_args}; i++)); do
        case "${tui_args[i]}" in
            --session)
                ((i < ${#tui_args})) && session_key="${tui_args[i + 1]}"
                ;;
            --session=*)
                session_key="${tui_args[i]#--session=}"
                ;;
        esac
    done

    if [[ -z "$session_key" ]]; then
        tmux_target="$(tmux display-message -p -t "$TMUX_PANE" '#S-#I-#P')" || return
        session_key="$tmux_target"
        tui_args=(--session "$session_key" "${tui_args[@]}")
    fi

    if [[ "$session_key" == *[^A-Za-z0-9_.-]* ]]; then
        print -u2 "oc: session name must use only letters, numbers, dots, underscores, or dashes"
        return 2
    fi

    tmux_socket="${TMUX%%,*}"
    tmux_session_id="$(tmux display-message -p -t "$TMUX_PANE" '#{session_id}')" || return
    state_dir="$HOME/.local/state/openclaw-tmux"
    mapping_file="$state_dir/$session_key.json"

    umask 077
    mkdir -p "$state_dir" || return
    printf '{"pane":"%s","socket":"%s","tmuxSessionId":"%s","status":"stopped","updatedAt":%s}\n' \
        "$TMUX_PANE" "$tmux_socket" "$tmux_session_id" "$(date +%s)" >| "$mapping_file" || return

    command openclaw tui "${tui_args[@]}"
    local openclaw_status=$?

    # Preserve the mapping after the TUI exits so external status displays can
    # distinguish an idle completed turn from a stopped OpenClaw process.
    printf '{"pane":"%s","socket":"%s","tmuxSessionId":"%s","status":"stopped","updatedAt":%s}\n' \
        "$TMUX_PANE" "$tmux_socket" "$tmux_session_id" "$(date +%s)" >| "$mapping_file"
    return "$openclaw_status"
}

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
