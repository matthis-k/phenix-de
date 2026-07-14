{ inputs, ... }:
let
  desktopModule = import ./nixos/desktop.nix { inherit inputs; };
  hyprlandModule = import ./nixos/hyprland-base.nix { inherit inputs; };
  stylixModule = import ./nixos/stylix.nix { inherit inputs; };
  fishModule = import ./nixos/fish.nix { inherit inputs; };

  desktopHomeModule = import ./home/desktop.nix { inherit inputs; };
  hyprlandHomeModule = import ./home/hyprland.nix;
  stylixHomeModule = import ./home/stylix.nix { inherit inputs; };
  fishHomeModule = import ./home/fish.nix { inherit inputs; };
  kittyHomeModule = import ./home/kitty.nix { inherit inputs; };
  quickshellHomeModule = import ./home/quickshell.nix { inherit inputs; };
  zenBrowserHomeModule = import ./home/zen-browser.nix { inherit inputs; };
in
{
  flake = {
    nixosModules = {
      default = desktopModule;
      desktop = desktopModule;
      hyprland = hyprlandModule;
      hyprlandCache = import ./nixos/nix-cache.nix;
      stylix = stylixModule;
      fish = fishModule;
      waylandTools = import ./nixos/wayland-tools.nix;
    };

    homeModules = {
      default = desktopHomeModule;
      desktop = desktopHomeModule;
      hyprland = hyprlandHomeModule;
      stylix = stylixHomeModule;
      fish = fishHomeModule;
      kitty = kittyHomeModule;
      quickshell = quickshellHomeModule;
      waylandTools = import ./home/wayland-tools.nix;
      zenBrowser = zenBrowserHomeModule;
    };

    overlays.default = final: prev: {
      phenix = (prev.phenix or { }) // {
        inherit (inputs.self.packages.${final.system})
          hyprland
          phenix-hyprland
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
