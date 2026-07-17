{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.phenix.de.hyprland;
  runtime = import ../../lib/hyprland-runtime.nix {
    inherit inputs pkgs cfg;
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.enableRuntimeLuaImport) {
    system.activationScripts.hyprland-nix-import = lib.stringAfter [ "etc" ] ''
      mkdir -p /run/phenix/hypr
      cp -f ${runtime.configuredPackage.passthru.nixImportLua} /run/phenix/hypr/nix-import.lua
    '';
  };
}
