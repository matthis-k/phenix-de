{ inputs }:
{
  lib,
  pkgs,
  ...
}:
let
  kitty = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kitty;
in
{
  home.packages = [
    kitty
    pkgs.nerd-fonts.hack
  ];

  home.sessionVariables.TERMINAL = lib.getExe kitty;
}
