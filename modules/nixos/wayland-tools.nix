{ pkgs, ... }:
let
  tools = import ../lib/wayland-tools.nix { inherit pkgs; };
in
{
  environment.systemPackages = tools.packages;
}
