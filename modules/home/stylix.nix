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
  c = palette.colors;
  hex = color: lib.removePrefix "#" color;
  system = pkgs.stdenv.hostPlatform.system;
  cursorPackage = inputs.catppuccin-breeze-cursors.packages.${system}.catppuccin-breeze.blue;
  paletteJson = pkgs.writeText "phenix-catppuccin-palette.json" (builtins.toJSON palette);
in
{
  imports = [ inputs.stylix.homeModules.stylix ];

  options.phenix.de.theme.palette = theme.paletteOption;

  config = {
    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    };

    stylix = theme.mkStylixConfig { inherit pkgs palette; } // {
      targets = {
        fish.enable = false;
        kitty.enable = false;
      };
    };

    home.pointerCursor = {
      enable = true;
      package = cursorPackage;
      name = "Breeze-Catppuccin-blue";
      size = 24;
      gtk.enable = true;
      hyprcursor.enable = true;
      x11.enable = true;
    };

    xdg.configFile = {
      "quickshell/catppuccin-palette.json".source = paletteJson;

      "fish/stylix-theme.auto.fish".text = ''
        set -g fish_color_normal ${hex c.text}
        set -g fish_color_command ${hex c.blue}
        set -g fish_color_param ${hex c.flamingo}
        set -g fish_color_keyword ${hex c.mauve}
        set -g fish_color_quote ${hex c.green}
        set -g fish_color_redirection ${hex c.pink}
        set -g fish_color_end ${hex c.peach}
        set -g fish_color_comment ${hex c.overlay1}
        set -g fish_color_error ${hex c.red}
        set -g fish_color_gray ${hex c.overlay0}
        set -g fish_color_selection '--background=${hex c.surface0}'
        set -g fish_color_search_match '--background=${hex c.surface0}'
        set -g fish_color_option ${hex c.green}
        set -g fish_color_operator ${hex c.pink}
        set -g fish_color_escape ${hex c.maroon}
        set -g fish_color_autosuggestion ${hex c.overlay0}
        set -g fish_color_cancel ${hex c.red}
        set -g fish_color_cwd ${hex c.yellow}
        set -g fish_color_user ${hex c.teal}
        set -g fish_color_host ${hex c.blue}
        set -g fish_color_host_remote ${hex c.green}
        set -g fish_color_status ${hex c.red}
      '';

      "kitty/stylix-theme.auto.conf".text = ''
        foreground ${c.text}
        background ${c.base}
        selection_foreground ${c.base}
        selection_background ${c.rosewater}
        cursor ${c.rosewater}
        cursor_text_color ${c.base}
        active_border_color ${c.lavender}
        inactive_border_color ${c.overlay0}
        bell_border_color ${c.yellow}
        active_tab_foreground ${c.crust}
        active_tab_background ${c.mauve}
        inactive_tab_foreground ${c.text}
        inactive_tab_background ${c.mantle}
        tab_bar_background ${c.crust}
        color0 ${c.surface1}
        color8 ${c.surface2}
        color1 ${c.red}
        color9 ${c.red}
        color2 ${c.green}
        color10 ${c.green}
        color3 ${c.yellow}
        color11 ${c.yellow}
        color4 ${c.blue}
        color12 ${c.blue}
        color5 ${c.pink}
        color13 ${c.pink}
        color6 ${c.teal}
        color14 ${c.teal}
        color7 ${c.subtext1}
        color15 ${c.subtext0}
      '';
    };

    programs.fish.interactiveShellInit = lib.mkBefore ''
      source ~/.config/fish/stylix-theme.auto.fish
    '';
  };
}
