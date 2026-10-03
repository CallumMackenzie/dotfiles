{ ... }:
{
  homebrew = {
    enable = true;
    brews = [ "terminal-notifier" ];
    casks = [
      "hammerspoon"
      "wezterm"
    ];
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
  };
}
