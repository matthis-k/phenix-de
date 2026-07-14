{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../lib/theme.nix { inherit lib; };
  palette = config.phenix.de.theme.palette;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.phenix.de.theme.palette = theme.paletteOption;

  config = {
    programs.dconf.enable = true;

    stylix = theme.mkStylixConfig { inherit pkgs palette; } // {
      homeManagerIntegration.autoImport = false;
    };
  };
}
