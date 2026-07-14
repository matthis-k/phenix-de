{ lib }:
let
  defaultPalette = {
    name = "Catppuccin Mocha";
    flavor = "mocha";
    author = "https://github.com/catppuccin/catppuccin";
    colors = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
      text = "#cdd6f4";
      subtext1 = "#bac2de";
      subtext0 = "#a6adc8";
      overlay2 = "#9399b2";
      overlay1 = "#7f849c";
      overlay0 = "#6c7086";
      surface2 = "#585b70";
      surface1 = "#45475a";
      surface0 = "#313244";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";
    };
  };

  paletteType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Theme display name.";
      };
      flavor = lib.mkOption {
        type = lib.types.str;
        description = "Theme flavor name.";
      };
      author = lib.mkOption {
        type = lib.types.str;
        description = "Theme author or upstream source.";
      };
      colors = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        description = "Full semantic color palette.";
      };
    };
  };

  mkBase16Scheme =
    palette:
    let
      c = palette.colors;
    in
    {
      system = "base16";
      inherit (palette) name author;
      variant = "dark";
      palette = {
        base00 = c.base;
        base01 = c.mantle;
        base02 = c.surface0;
        base03 = c.surface1;
        base04 = c.surface2;
        base05 = c.text;
        base06 = c.rosewater;
        base07 = c.lavender;
        base08 = c.red;
        base09 = c.peach;
        base0A = c.yellow;
        base0B = c.green;
        base0C = c.teal;
        base0D = c.blue;
        base0E = c.mauve;
        base0F = c.flamingo;
      };
    };

  mkStylixConfig =
    { pkgs, palette }:
    {
      enable = true;
      base16Scheme = mkBase16Scheme palette;
      polarity = "dark";
      icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus";
      };
      fonts.monospace = {
        package = pkgs.nerd-fonts.hack;
        name = "Hack Nerd Font Mono";
      };
    };
in
{
  inherit defaultPalette mkStylixConfig;

  paletteOption = lib.mkOption {
    type = paletteType;
    default = defaultPalette;
    description = "Semantic palette used by Stylix and desktop-specific targets.";
  };
}
