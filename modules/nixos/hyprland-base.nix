{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.phenix.de.hyprland;
in
{
  options.phenix.de.hyprland = {
    enable = mkEnableOption "Phenix Hyprland desktop environment base";

    displayManager = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to enable a display manager (SDDM) for Hyprland.
          When disabled, start Hyprland manually (e.g. via `hyprctl` or TTY login).
        '';
      };

      session = mkOption {
        type = types.str;
        default = "hyprland";
        example = "hyprland";
        description = "Default desktop session for the display manager.";
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to system-wide Hyprland configuration.";
    };
  };

  config = mkIf cfg.enable {
    # Enable Hyprland with the nixpkgs-provided module
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # XDG Desktop Portal integration
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
      configPackages = [ pkgs.hyprland ];
    };

    # Session/seat management
    security.pam.services.hyprland = { };

    # Display manager (SDDM)
    services.displayManager.sddm = mkIf cfg.displayManager.enable {
      enable = true;
      wayland.enable = true;
      defaultSession = cfg.displayManager.session;
    };

    # Environment variables for Wayland/Ozone
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    # Fonts for desktop
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
    ];
  };
}
