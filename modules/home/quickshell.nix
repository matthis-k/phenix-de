{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  shellPackage = inputs.self.packages.${system}.phenix-shell;
  iconThemeName =
    if config.stylix.polarity == "light" then config.stylix.icons.light else config.stylix.icons.dark;
  useDevConfig = config.phenix.devMode or false;
in
{
  home.packages = [
    shellPackage
    pkgs.kdePackages.qtdeclarative
    pkgs.kdePackages.qt3d
    pkgs.kdePackages.qt6ct
    pkgs.kdePackages.qtbase
    pkgs.kdePackages.qttools
    pkgs.kdePackages.qt5compat
  ];

  home.sessionVariables.QS_ICON_THEME = iconThemeName;

  systemd.user.services.phenix-shell = {
    Unit = {
      Description = "Phenix Quickshell session";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];

    Service = {
      ExecStart = lib.getExe shellPackage;
      Restart = "on-failure";
      RestartSec = "500ms";
      Environment = [
        "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/wrappers/bin:/run/current-system/sw/bin"
        "XDG_CURRENT_DESKTOP=Hyprland"
      ]
      ++ lib.optionals useDevConfig [
        "PHENIX_DEV=1"
        "NEWXOS_DEV=1"
      ];
    };
  };
}
