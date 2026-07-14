{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.phenix.de.hyprland;
  system = pkgs.stdenv.hostPlatform.system;
  hyprlandPackages = inputs.hyprland.packages.${system};

  configuredPackage = inputs.self.lib.phenixHyprlandWrapper.wrap {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    configDirectory = ../../configs/hypr;
    package = hyprlandPackages.hyprland;
    luaVariables.monitors = cfg.monitors;
  };

  selectedPackage = if cfg.monitors == null then cfg.package else configuredPackage;

  hyprctlFishCompletion = pkgs.runCommand "hyprctl-fish-completion" { } ''
    mkdir -p hyprctl "$out/share/fish/vendor_completions.d"
    cp ${hyprlandPackages.hyprland}/share/fish/vendor_completions.d/hyprctl.fish hyprctl/hyprctl.fish
    chmod u+w hyprctl/hyprctl.fish
    patch -p1 < ${../../patches/hyprctl-fish-completions.patch}
    cp hyprctl/hyprctl.fish "$out/share/fish/vendor_completions.d/hyprctl.fish"
  '';
in
{
  options.phenix.de.hyprland = {
    enable = lib.mkEnableOption "the Phenix Hyprland system integration";

    package = lib.mkOption {
      type = lib.types.package;
      default = hyprlandPackages.hyprland;
      defaultText = lib.literalExpression "inputs.hyprland.packages.<system>.hyprland";
      description = "Base Hyprland package used when the wrapped Lua configuration is disabled.";
    };

    portalPackage = lib.mkOption {
      type = lib.types.package;
      default = hyprlandPackages.xdg-desktop-portal-hyprland;
      defaultText = lib.literalExpression "inputs.hyprland.packages.<system>.xdg-desktop-portal-hyprland";
      description = "Desktop portal package paired with Hyprland.";
    };

    monitors = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.listOf (
          lib.types.submodule {
            options = {
              output = lib.mkOption {
                type = lib.types.str;
                description = "Output name.";
              };
              mode = lib.mkOption {
                type = lib.types.str;
                default = "preferred";
                description = "Output resolution and refresh mode.";
              };
              position = lib.mkOption {
                type = lib.types.str;
                default = "auto";
                description = "Output position.";
              };
              scale = lib.mkOption {
                type = lib.types.number;
                default = 1;
                description = "Output scale factor.";
              };
            };
          }
        )
      );
      default = null;
      description = "Monitor data injected into the packaged Hyprland Lua configuration. Null uses the unwrapped package.";
    };

    enableRuntimeLuaImport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Publish nix-import.lua under /run/phenix/hypr for live configuration reloads.";
    };

    displayManager.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable SDDM and select the Hyprland UWSM session.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      brightnessctl
      hyprpolkitagent
      (lib.hiPrio hyprctlFishCompletion)
      playerctl
      wireplumber
      selectedPackage
    ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    };

    nix.settings = {
      extra-substituters = [ "https://hyprland.cachix.org" ];
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    programs.hyprland = {
      enable = true;
      package = selectedPackage;
      inherit (cfg) portalPackage;
      withUWSM = true;
      xwayland.enable = true;
    };

    security.polkit.enable = true;

    services = {
      dbus.enable = true;
      power-profiles-daemon.enable = true;
      upower.enable = true;
      xserver.enable = true;

      displayManager = lib.mkIf cfg.displayManager.enable {
        defaultSession = "hyprland-uwsm";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [
      nerd-fonts.hack
      noto-fonts
      noto-fonts-emoji
    ];

    systemd.user.services.hyprpolkitagent = {
      enable = true;
      description = "HyprPolkitAgent Service";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      };
    };

    system.activationScripts.hyprland-nix-import = lib.mkIf cfg.enableRuntimeLuaImport (
      lib.stringAfter [ "etc" ] ''
        mkdir -p /run/phenix/hypr /run/newxos/hypr
        cp -f ${configuredPackage.passthru.nixImportLua} /run/phenix/hypr/nix-import.lua
        ln -sfn /run/phenix/hypr/nix-import.lua /run/newxos/hypr/nix-import.lua
      ''
    );
  };
}
