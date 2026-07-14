{ inputs }:
{
  imports = [
    (import ./stylix.nix { inherit inputs; })
    (import ./fish.nix { inherit inputs; })
    (import ./kitty.nix { inherit inputs; })
    (import ./quickshell.nix { inherit inputs; })
    (import ./zen-browser.nix { inherit inputs; })
    ./wayland-tools.nix
  ];
}
