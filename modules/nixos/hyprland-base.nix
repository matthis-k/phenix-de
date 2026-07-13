{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.phenix.de.hyprland;
in
{
  options.phenix.de.hyprland = {
    enable = lib.mkEnableOption "the Phenix Hyprland system integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hyprland;
      defaultText = lib.literalExpression "pkgs.hyprland";
      description = "Hyprland package exposed as the system desktop session.";
    };

    portalPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xdg-desktop-portal-hyprland;
      defaultText = lib.literalExpression "pkgs.xdg-desktop-portal-hyprland";
      description = "Desktop portal package paired with the selected Hyprland package.";
    };

    displayManager.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable SDDM and select the Hyprland session by default.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      inherit (cfg) package portalPackage;
      xwayland.enable = true;
    };

    services.displayManager = lib.mkIf cfg.displayManager.enable {
      defaultSession = "hyprland";
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
    ];
  };
}
