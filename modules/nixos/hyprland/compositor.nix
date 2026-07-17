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
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (lib.hiPrio runtime.hyprctlFishCompletion)
      runtime.selectedPackage
    ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    };

    nix.settings = {
      extra-substituters = [ "https://hyprland.cachix.org" ];
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    programs.hyprland = {
      enable = true;
      package = runtime.selectedPackage;
      inherit (cfg) portalPackage;
      withUWSM = true;
      xwayland.enable = true;
    };

    fonts.packages = with pkgs; [
      nerd-fonts.hack
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
