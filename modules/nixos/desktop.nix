{ inputs }:
{
  imports = [
    (import ./hyprland-base.nix { inherit inputs; })
    (import ./stylix.nix { inherit inputs; })
    (import ./fish.nix { inherit inputs; })
    ./wayland-tools.nix
  ];

  phenix.de.hyprland.enable = true;
}
