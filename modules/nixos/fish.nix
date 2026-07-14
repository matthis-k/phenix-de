{ inputs }:
{ pkgs, ... }:
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  programs.fish.enable = true;
  programs.nix-index = {
    enable = true;
    enableFishIntegration = false;
  };
  programs.nix-index-database.comma.enable = true;

  users.defaultUserShell = pkgs.fish;
}
