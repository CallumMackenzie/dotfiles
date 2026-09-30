{ inputs, username, hostname, ... }:
{
  imports = [
    ../../modules/darwin.nix
    ../../modules/homebrew.nix
  ];

  networking.hostName = hostname;
  networking.computerName = "MacBook Pro";

  users.users.${username}.home = "/Users/${username}";

  system.configurationRevision =
    inputs.self.rev or inputs.self.dirtyRev or null;
}
