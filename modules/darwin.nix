{ pkgs, username, ... }:
{
  nix.enable = false; # Determinate Nix owns the daemon and its configuration.

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  programs.zsh.enable = true;

  environment.systemPackages = [ pkgs.vim ];

  system = {
    primaryUser = username;
    stateVersion = 6;

    defaults = {
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
      };
      dock = {
        autohide = false;
        show-recents = false;
      };
      finder = {
        FXPreferredViewStyle = "Nlsv";
      };
    };
  };
}
