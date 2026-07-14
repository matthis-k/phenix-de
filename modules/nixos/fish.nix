{ inputs }:
{ pkgs, ... }:
{
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  programs = {
    fish.enable = true;
    nix-index = {
      enable = true;
      enableFishIntegration = false;
    };
    nix-index-database.comma.enable = true;
  };

  users.defaultUserShell = pkgs.fish;
}
