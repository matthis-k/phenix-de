{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPackages = inputs.hyprland.packages.${system};
in
{
  options.phenix.de.hyprland = {
    enable = lib.mkEnableOption "the Phenix Hyprland system integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = hyprlandPackages.hyprland;
      defaultText = lib.literalExpression "inputs.hyprland.packages.<system>.hyprland";
      description = "Base Hyprland package used when the wrapped Lua configuration is disabled.";
    };

    portalPackage = lib.mkOption {
      type = lib.types.package;
      default = hyprlandPackages.xdg-desktop-portal-hyprland;
      defaultText = lib.literalExpression "inputs.hyprland.packages.<system>.xdg-desktop-portal-hyprland";
      description = "Desktop portal package paired with Hyprland.";
    };

    monitors = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.listOf (
          lib.types.submodule {
            options = {
              output = lib.mkOption {
                type = lib.types.str;
                description = "Output name.";
              };
              mode = lib.mkOption {
                type = lib.types.str;
                default = "preferred";
                description = "Output resolution and refresh mode.";
              };
              position = lib.mkOption {
                type = lib.types.str;
                default = "auto";
                description = "Output position.";
              };
              scale = lib.mkOption {
                type = lib.types.number;
                default = 1;
                description = "Output scale factor.";
              };
            };
          }
        )
      );
      default = null;
      description = "Monitor data injected into the packaged Hyprland Lua configuration. Null uses the unwrapped package.";
    };

    enableRuntimeLuaImport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Publish nix-import.lua under /run/phenix/hypr for live configuration reloads.";
    };

    displayManager.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable SDDM and select the Hyprland UWSM session.";
    };
  };
}
