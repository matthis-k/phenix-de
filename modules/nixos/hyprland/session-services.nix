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
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      brightnessctl
      hyprpolkitagent
      playerctl
      wireplumber
    ];

    security.polkit.enable = true;

    services = {
      dbus.enable = true;
      power-profiles-daemon.enable = true;
      upower.enable = true;
    };

    systemd.user.services.hyprpolkitagent = {
      enable = true;
      description = "HyprPolkitAgent Service";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      };
    };
  };
}
