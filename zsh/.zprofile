if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Prefer declaratively managed Nix programs while retaining Homebrew for casks
# and externally managed tools such as OpenClaw.
typeset -U path PATH
path=("$HOME/.nix-profile/bin" /run/current-system/sw/bin $path)

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

alias get_idf='source "$HOME/esp/esp-idf/export.sh"'
