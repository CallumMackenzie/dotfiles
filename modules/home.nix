{ config, inputs, lib, pkgs, username, ... }:
let
  homeDirectory = "/Users/${username}";
  openclawPlugin = ../openclaw/plugins/openclaw-tmux-notify;
  neovimPython = pkgs.python3.withPackages (pythonPackages: with pythonPackages; [
    ipykernel
    jupyter
    jupytext
    nbconvert
    pynvim
  ]);
in
{
  home = {
    inherit username homeDirectory;
    stateVersion = "25.05";

    packages = with pkgs; [
      fd
      ghostscript
      git
      imagemagick
      neovim
      neovimPython
      nodejs
      ripgrep
      ruby
      tectonic
      terminal-notifier
      tmux
    ];

    sessionVariables = {
      NVIM_PYTHON = "${neovimPython}/bin/python3";
      NVIM_JUPYTER = "${neovimPython}/bin/jupyter";
    };

    file = {
      ".zshrc".source = ../zsh/.zshrc;
      ".zprofile".source = ../zsh/.zprofile;
      ".tmux.conf".source = ../tmux/.tmux.conf;
      ".gitconfig".source = ../git/.gitconfig;
      ".hammerspoon".source = ../hammerspoon;

      ".local/bin/tmux-notify-jump" = {
        source = "${inputs.tmux-notify-jump}/tmux-notify-jump";
        executable = true;
      };

      ".openclaw/local-plugins/openclaw-tmux-notify".source =
        openclawPlugin;
    };
  };

  xdg.configFile = {
    "nvim".source = ../nvim;
    "wezterm".source = ../wezterm;
  };

  programs.home-manager.enable = true;

  home.activation.ensurePrivateZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "${homeDirectory}/.zshrc.private" ]]; then
      $DRY_RUN_CMD install -m 600 /dev/null "${homeDirectory}/.zshrc.private"
    else
      $DRY_RUN_CMD chmod 600 "${homeDirectory}/.zshrc.private"
    fi
  '';

  home.activation.configureOpenClawTmuxNotify =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      openclaw_bin=""
      if [[ -x /opt/homebrew/bin/openclaw ]]; then
        openclaw_bin=/opt/homebrew/bin/openclaw
      elif command -v openclaw >/dev/null 2>&1; then
        openclaw_bin="$(command -v openclaw)"
      fi

      if [[ -n "$openclaw_bin" ]]; then
        $DRY_RUN_CMD "$openclaw_bin" plugins install --link --force \
          --accept-capabilities --acknowledge-install-policy-warning \
          "${openclawPlugin}"
        $DRY_RUN_CMD "$openclaw_bin" plugins enable openclaw-tmux-notify \
          --accept-capabilities
        $DRY_RUN_CMD "$openclaw_bin" config set \
          'plugins.entries.openclaw-tmux-notify.hooks.allowConversationAccess' \
          true --strict-json
      fi
    '';
}
