{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.programs.phenix.hyprland;
in
{
  options.programs.phenix.hyprland = {
    enable = mkEnableOption "Phenix Hyprland user configuration";

    package = mkOption {
      type = types.package;
      default = pkgs.hyprland;
      defaultText = literalExpression "pkgs.hyprland";
      description = "Hyprland package to use.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to hyprland.conf.";
    };

    monitor = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = ",preferred,auto,1";
      description = ''
        Monitor configuration passed to Hyprland.
        Format: <name>,<resolution>,<position>,<scale>
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    wayland.windowManager.hyprland = {
      enable = true;
      inherit (cfg) package;
      inherit (cfg) extraConfig;

      systemd = {
        enable = true;
        variables = [ "--all" ];
      };

      settings = {
        "$mod" = "SUPER";

        monitor = mkIf (cfg.monitor != null) cfg.monitor;

        input = {
          kb_layout = "us,de";
          kb_options = "caps:escape";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
            tap-to-click = true;
          };
          sensitivity = 0;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
        };

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 0.9;
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
          };
        };

        animations = {
          enabled = true;
          bezier = [
            "overshot, 0.13, 0.99, 0.29, 1.1"
            "smoothOut, 0.36, 0, 0.66, -0.56"
            "smoothIn, 0.25, 1, 0.5, 1"
          ];
          animation = [
            "windows, 1, 4, overshot, popin"
            "windowsOut, 1, 4, smoothOut, popin"
            "fade, 1, 4, smoothIn"
            "workspaces, 1, 4, overshot, slidevert"
          ];
        };

        windowrule = [
          "float, title:^(Picture-in-Picture)$"
          "float, title:^(Volume Control)$"
          "float, class:^(pavucontrol)$"
        ];

        bind = [
          "$mod, Q, exec, kitty"
          "$mod, C, killactive"
          "$mod, M, exit"
          "$mod, E, exec, dolphin"
          "$mod, V, togglefloating"
          "$mod, R, exec, rofi -show drun"
          "$mod, P, pseudo"
          "$mod, J, togglesplit"
          "$mod, left, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, SHIFT, 1, movetoworkspace, 1"
          "$mod, SHIFT, 2, movetoworkspace, 2"
          "$mod, SHIFT, 3, movetoworkspace, 3"
          "$mod, SHIFT, 4, movetoworkspace, 4"
          "$mod, SHIFT, 5, movetoworkspace, 5"
          "$mod, mouse_down, workspace, e+1"
          "$mod, mouse_up, workspace, e-1"
        ];

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };
  };
}
