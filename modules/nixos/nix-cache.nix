{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.phenix.de.nixCache;
in
{
  options.phenix.de.nixCache = {
    enable = mkEnableOption "Phenix DE Nix binary cache configuration";

    extraCaches = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "https://some-cache.cachix.org" ];
      description = "Additional binary cache URLs to trust.";
    };

    extraPublicKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "some-cache.cachix.org-1:xxxxxxxxxxxxx=" ];
      description = "Public keys for additional caches.";
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      substituters = [
        "https://hyprland.cachix.org"
        "https://cache.nixos.org"
      ]
      ++ cfg.extraCaches;

      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ]
      ++ cfg.extraPublicKeys;
    };
  };
}
