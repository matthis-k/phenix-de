{
  description = "Phenix desktop environment";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    phenix-pins.url = "github:matthis-k/phenix-pins";
    phenix-tend.url = "github:matthis-k/phenix-tend";
    nixpkgs.follows = "phenix-pins/nixpkgs";
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "phenix-pins/nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [ ./modules/package.nix ];
      flake.flakeModules.default = import ./modules/overlay.nix;
    };
}
