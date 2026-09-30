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
    local tmux_target tmux_socket tmux_session_id tmux_session_name state_dir mapping_file
    local candidate jq_bin temporary_file updated_at
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
    tmux_session_name="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}')" || return
    state_dir="$HOME/.local/state/openclaw-tmux"
    mapping_file="$state_dir/$session_key.json"

    umask 077
    mkdir -p "$state_dir" || return
    jq_bin="$(command -v jq 2>/dev/null)"
    if [[ -z "$jq_bin" ]]; then
        print -u2 "oc: jq is required to create the tmux notification mapping"
        return 1
    fi
    "$jq_bin" -n \
        --arg pane "$TMUX_PANE" \
        --arg socket "$tmux_socket" \
        --arg tmux_session_id "$tmux_session_id" \
        --arg tmux_session_name "$tmux_session_name" \
        --argjson updated_at "$(($(date +%s) * 1000))" \
        '{pane: $pane, socket: $socket, tmuxSessionId: $tmux_session_id,
          tmuxSessionName: $tmux_session_name, status: "stopped", updatedAt: $updated_at}' \
        >| "$mapping_file" || return

    command openclaw tui "${tui_args[@]}"
    local openclaw_status=$?

    # A TUI can create replacement session keys in-place via /new or /reset.
    # Mark every alias owned by this pane stopped when the process exits.
    updated_at="$(($(date +%s) * 1000))"
    if [[ -n "$jq_bin" ]]; then
        for candidate in "$state_dir"/*.json(N); do
            if "$jq_bin" -e \
                --arg pane "$TMUX_PANE" \
                --arg socket "$tmux_socket" \
                --arg tmux_session_id "$tmux_session_id" \
                '.pane == $pane and .socket == $socket and .tmuxSessionId == $tmux_session_id' \
                "$candidate" >/dev/null 2>&1; then
                temporary_file="$candidate.$$.$RANDOM.tmp"
                if "$jq_bin" --argjson updated_at "$updated_at" \
                    '.status = "stopped" | .updatedAt = $updated_at' \
                    "$candidate" >| "$temporary_file"; then
                    chmod 600 "$temporary_file"
                    mv -f "$temporary_file" "$candidate"
                else
                    rm -f "$temporary_file"
                fi
            fi
        done
    else
        # Preserve the original mapping even if jq is temporarily unavailable.
        printf '{"pane":"%s","socket":"%s","tmuxSessionId":"%s","status":"stopped","updatedAt":%s}\n' \
            "$TMUX_PANE" "$tmux_socket" "$tmux_session_id" "$updated_at" >| "$mapping_file"
    fi
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
