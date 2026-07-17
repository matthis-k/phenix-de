{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      hyprlandConfig = builtins.path {
        name = "phenix-hyprland-config";
        path = ../configs/hypr;
      };

      shellConfig = builtins.path {
        name = "phenix-shell-config";
        path = ../configs/phenix-shell;
        filter = path: type: !(type == "regular" && builtins.baseNameOf path == ".qmlls.ini");
      };

      configuredHyprland = inputs.self.lib.phenixHyprlandWrapper.wrap {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        configDirectory = hyprlandConfig;
        package = inputs.hyprland.packages.${system}.hyprland;
        luaVariables.monitors = [ { output = "auto"; } ];
      };

      waylandTools = import ./lib/wayland-tools.nix { inherit pkgs; };

      shellRuntimeInputs =
        (with pkgs; [
          bash
          brightnessctl
          coreutils
          fd
          gawk
          gnugrep
          gnused
          networkmanager
          quickshell
          systemd
          util-linux
          uwsm
          wl-clipboard
          xdg-utils
        ])
        ++ waylandTools.packages;

      shellRuntimeCommands = [
        "annotate"
        "awk"
        "brightnessctl"
        "cat"
        "df"
        "fd"
        "grimblast"
        "head"
        "loginctl"
        "mkdir"
        "nmcli"
        "notify-send"
        "printf"
        "quickshell"
        "read-image"
        "setsid"
        "sh"
        "systemctl"
        "systemd-run"
        "tesseract"
        "uwsm"
        "wl-copy"
        "wl-paste"
        "xdg-open"
      ];

      phenixShell = pkgs.writeShellApplication {
        name = "phenix-shell";
        runtimeInputs = shellRuntimeInputs;
        text = ''
          if [ "''${1:-}" = "--check-runtime" ]; then
            missing=0
            for command in ${pkgs.lib.escapeShellArgs shellRuntimeCommands}; do
              if ! command -v "$command" >/dev/null 2>&1; then
                printf 'missing shell runtime command: %s\n' "$command" >&2
                missing=1
              fi
            done
            exit "$missing"
          fi

          config_dir=${shellConfig}
          quickshell_args=()

          if [ "''${PHENIX_DEV:-0}" = 1 ]; then
            config_dir="''${PHENIX_DE_ROOT:-$HOME/phenix/repos/phenix-de}/configs/phenix-shell"
            quickshell_args+=(--verbose)
          fi

          exec quickshell -p "$config_dir" "''${quickshell_args[@]}" "$@"
        '';
      };

      kitty = inputs.nix-wrapper-modules.wrappers.kitty.wrap {
        inherit pkgs;
        font = {
          name = "Hack Nerd Font";
          size = 10;
        };
        extraConfig = ''
          include ~/.config/kitty/stylix-theme.auto.conf

          ${builtins.readFile ../configs/kitty/kitty.conf}
        '';
      };

      waylandUtils = pkgs.symlinkJoin {
        name = "phenix-wayland-utils";
        paths = [
          pkgs.grim
          pkgs.slurp
          pkgs.swappy
        ]
        ++ waylandTools.packages;
      };

      mkApp = program: description: {
        type = "app";
        inherit program;
        meta.description = description;
      };
    in
    {
      packages = {
        hyprland = inputs.hyprland.packages.${system}.hyprland;
        phenix-hyprland = configuredHyprland;
        phenix-shell = phenixShell;
        inherit kitty;
        wayland-utils = waylandUtils;
        inherit (pkgs) fish starship;
      };

      apps = {
        default = mkApp "${phenixShell}/bin/phenix-shell" "Launch the Phenix desktop shell";
        phenix-shell = mkApp "${phenixShell}/bin/phenix-shell" "Launch the Phenix desktop shell";
        wl-copy = mkApp "${pkgs.wl-clipboard}/bin/wl-copy" "Copy data to the Wayland clipboard";
        wl-paste = mkApp "${pkgs.wl-clipboard}/bin/wl-paste" "Read data from the Wayland clipboard";
        grim = mkApp "${pkgs.grim}/bin/grim" "Capture a Wayland screenshot";
        slurp = mkApp "${pkgs.slurp}/bin/slurp" "Select a Wayland screen region";
        swappy = mkApp "${pkgs.swappy}/bin/swappy" "Annotate and edit screenshots";
        tesseract = mkApp "${pkgs.tesseract}/bin/tesseract" "Run optical character recognition";
      };

      checks = {
        inherit configuredHyprland phenixShell kitty;

        shell-runtime =
          pkgs.runCommand "phenix-shell-runtime-check" { nativeBuildInputs = [ phenixShell ]; }
            ''
              phenix-shell --check-runtime
              touch "$out"
            '';

        desktop-config =
          pkgs.runCommand "phenix-desktop-config-check" { nativeBuildInputs = [ pkgs.lua ]; }
            ''
              cd ${../.}
              test -f configs/hypr/hyprland.lua
              test -f configs/hypr/keymap/tests.lua
              test -f configs/phenix-shell/shell.qml
              test -f configs/kitty/kitty.conf
              lua configs/hypr/keymap/tests.lua
              touch "$out"
            '';
      };
    };
}
