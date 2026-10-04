{ config, inputs, lib, pkgs, username, ... }:
let
  homeDirectory = "/Users/${username}";
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

      ".local/bin/pi-tmux-status" = {
        source = ../scripts/pi-tmux-status;
        executable = true;
        force = true;
      };

      ".pi/agent/AGENTS.md" = managedLink ../pi/AGENTS.md;
      ".pi/agent/extensions/tmux-notify.ts" =
        managedLink ../pi/extensions/tmux-notify.ts;
      ".pi/agent/extensions/ascii-splash.ts" =
        managedLink ../pi/extensions/ascii-splash.ts;
      ".local/bin/pi-mcp-google-drive-compat.mjs" = {
        source = ../pi/mcp/mcp-google-drive-compat.mjs;
        executable = true;
        force = true;
      };
      ".local/bin/pi-leetcode-mcp-keychain" = {
        source = ../pi/mcp/leetcode-mcp-keychain;
        executable = true;
        force = true;
      };
      ".local/bin/pi-course-tracker-mcp" = {
        source = ../pi/mcp/course-tracker-mcp;
        executable = true;
        force = true;
      };
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

  # Pi owns settings.json (device ID, installed packages and UI state). Merge
  # only reproducible model defaults instead of replacing the whole file.
  home.activation.configurePiModels = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:/usr/bin:/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${../scripts/configure-pi-models.sh} \
      "${homeDirectory}/.pi/agent/settings.json" ${../pi/model-defaults.json}
  '';

  home.activation.configurePiMcp = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export HOME="${homeDirectory}"
    export PATH="${pkgs.nodejs}/bin:${pkgs.coreutils}/bin:/usr/bin:/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${../scripts/setup-pi-mcp.sh} ${../pi}
  '';
}
