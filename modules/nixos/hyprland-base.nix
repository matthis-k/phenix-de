{ inputs }:
{
  imports = [
    (import ./hyprland/options.nix { inherit inputs; })
    (import ./hyprland/compositor.nix { inherit inputs; })
    ./hyprland/session-services.nix
    ./hyprland/display-manager.nix
    ./hyprland/portals.nix
    (import ./hyprland/runtime-config.nix { inherit inputs; })
  ];
}
