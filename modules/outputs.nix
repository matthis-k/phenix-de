{ inputs, ... }:
let
  hyprlandModule = import ./nixos/hyprland-base.nix;
  hyprlandHomeModule = import ./home/hyprland.nix;
in
{
  flake = {
    nixosModules = {
      default = hyprlandModule;
      hyprland = hyprlandModule;
      hyprlandCache = import ./nixos/nix-cache.nix;
    };

    homeModules = {
      default = hyprlandHomeModule;
      hyprland = hyprlandHomeModule;
    };

    overlays.default = final: prev: {
      phenix = (prev.phenix or { }) // {
        inherit (inputs.self.packages.${final.system})
          hyprland
          phenix-shell
          kitty
          wayland-utils
          fish
          starship
          ;
      };
    };
  };
}
