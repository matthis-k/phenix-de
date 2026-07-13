{ inputs, ... }:
{
  flake = {
    nixosModules = {
      hyprland-base = import ./nixos/hyprland-base.nix;
      nix-cache = import ./nixos/nix-cache.nix;
    };

    homeModules.hyprland = import ./home/hyprland.nix;

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
