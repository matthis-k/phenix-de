{
  config,
  lib,
  ...
}:
let
  cfg = config.phenix.de.hyprland;
in
{
  config = lib.mkIf cfg.enable {
    services = {
      xserver.enable = true;

      displayManager = lib.mkIf cfg.displayManager.enable {
        defaultSession = "hyprland-uwsm";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
    };
  };
}
