if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Prefer declaratively managed Nix programs while retaining Homebrew for casks
# and externally managed tools such as OpenClaw.
typeset -U path PATH
path=("/etc/profiles/per-user/$USER/bin" /run/current-system/sw/bin $path)

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

alias get_idf='source "$HOME/esp/esp-idf/export.sh"'

# Version managers prepend themselves while initializing. Keep the
# declarative Home Manager profile authoritative for global tools.
path=("$HOME/.local/bin" "/etc/profiles/per-user/$USER/bin" /run/current-system/sw/bin $path)

hm_session_vars="/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
[[ -r "$hm_session_vars" ]] && source "$hm_session_vars"
unset hm_session_vars
