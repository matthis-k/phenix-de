{ config, lib, ... }:
let
  cfg = config.phenix.de.hyprlandCache;
in
{
  options.phenix.de.hyprlandCache = {
    enable = lib.mkEnableOption "the Hyprland binary cache";

    extraSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "https://example.cachix.org" ];
      description = "Additional substituters enabled alongside the Hyprland cache.";
    };

    extraTrustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "example.cachix.org-1:xxxxxxxxxxxxx=" ];
      description = "Trusted public keys for the additional substituters.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      extra-substituters = [ "https://hyprland.cachix.org" ] ++ cfg.extraSubstituters;
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ]
      ++ cfg.extraTrustedPublicKeys;
    };
  };
}
