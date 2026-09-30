{ config, inputs, lib, pkgs, username, ... }:
let
  homeDirectory = "/Users/${username}";
  openclawPlugin = ../openclaw/plugins/openclaw-tmux-notify;
  managedLink = source: { inherit source; force = true; };
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
      ".zshrc" = managedLink ../zsh/.zshrc;
      ".zprofile" = managedLink ../zsh/.zprofile;
      ".tmux.conf" = managedLink ../tmux/.tmux.conf;
      ".gitconfig" = managedLink ../git/.gitconfig;
      ".hammerspoon" = managedLink ../hammerspoon;

      ".local/bin/tmux-notify-jump" = {
        source = "${inputs.tmux-notify-jump}/tmux-notify-jump";
        executable = true;
        force = true;
      };

      ".openclaw/local-plugins/openclaw-tmux-notify" =
        managedLink openclawPlugin;
    };
  };

  xdg.configFile = {
    "nvim" = managedLink ../nvim;
    "wezterm" = managedLink ../wezterm;
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
      export PATH="${pkgs.nodejs}/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
      openclaw_bin=""
      if [[ -x /opt/homebrew/bin/openclaw ]]; then
        openclaw_bin=/opt/homebrew/bin/openclaw
      elif command -v openclaw >/dev/null 2>&1; then
        openclaw_bin="$(command -v openclaw)"
      fi

      if [[ -n "$openclaw_bin" ]]; then
        plugin_path="${homeDirectory}/.openclaw/local-plugins/openclaw-tmux-notify"
        paths_json="$("$openclaw_bin" config get plugins.load.paths 2>/dev/null || printf '[]')"
        merged_paths="$(printf '%s' "$paths_json" | ${pkgs.jq}/bin/jq \
          --arg stable "$plugin_path" \
          'if type == "array" then . else [] end
           | map(select((startswith("/nix/store/") and test("openclaw.*tmux.*notify"; "i")) | not))
           | if index($stable) then . else . + [$stable] end')"

        $DRY_RUN_CMD "$openclaw_bin" config set plugins.load.paths \
          "$merged_paths" --strict-json
        $DRY_RUN_CMD "$openclaw_bin" config set \
          plugins.entries.openclaw-tmux-notify.enabled true --strict-json
        $DRY_RUN_CMD "$openclaw_bin" config set \
          'plugins.entries.openclaw-tmux-notify.hooks.allowConversationAccess' \
          true --strict-json
      fi
    '';
}
