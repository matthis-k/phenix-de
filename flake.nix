{
  description = "Phenix desktop environment";

  nixConfig = {
    extra-substituters = [ "https://hyprland.cachix.org" ];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    phenix-pins.url = "github:matthis-k/phenix-pins";
    nixpkgs.follows = "phenix-pins/nixpkgs";
    phenix-tend = {
      url = "github:matthis-k/phenix-tend";
      inputs.phenix-pins.follows = "phenix-pins";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        ./modules/outputs.nix
        ./modules/package.nix
        ./modules/development.nix
      ];
      flake.flakeModules.default = import ./modules/overlay.nix;
    };
}
