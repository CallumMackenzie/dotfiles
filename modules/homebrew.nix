{ ... }:
{
  homebrew = {
    enable = true;
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
