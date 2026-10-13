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

      # Complete Lucide static SVG release. The tarball is integrity pinned,
      # extracted during the Nix build, and never downloaded at shell runtime.
      lucideArchive = pkgs.fetchurl {
        url = "https://registry.npmjs.org/lucide-static/-/lucide-static-1.55.0.tgz";
        hash = "sha512-h18lunTFsIJWnY0FMRPjXeO9KcAtNi7fDqtqgWHOFbssfgUWsctn/pA7bpiyrd4g1DuBOJ24CsRnPfkYblwm/A==";
      };

      lucideIcons = pkgs.runCommand "phenix-lucide-icons-1.55.0" {
        nativeBuildInputs = with pkgs; [
          findutils
          gnused
          gnutar
          gzip
        ];
      } ''
        dest="$out/share/phenix-shell/lucide"
        mkdir -p "$dest"
        tar -xzf "${lucideArchive}" -C "$dest" --strip-components=1 package/icons package/LICENSE
        # QtSvg does not reliably interpret CSS currentColor in external SVGs.
        # Explicit control tinting still uses the existing QML ColorOverlay.
        find "$dest/icons" -type f -name '*.svg' -exec sed -i 's/currentColor/#cdd6f4/g' {} +
        count="$(find "$dest/icons" -type f -name '*.svg' | wc -l)"
        test "$count" -ge 1800
        test -f "$dest/icons/flame.svg"
        test -f "$dest/icons/wifi.svg"
        test -f "$dest/LICENSE"
      '';

      shellRuntimeInputs =
        (with pkgs; [
          bash
          brightnessctl
          coreutils
          fd
          gawk
          gnugrep
          gnused
          iproute2
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
        "ip"
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

      phenixShellRunner = pkgs.writeShellApplication {
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

          export PHENIX_LUCIDE_ICON_DIR=${lucideIcons}/share/phenix-shell/lucide/icons
          config_dir=${shellConfig}
          quickshell_args=()

          if [ "''${PHENIX_DEV:-0}" = 1 ]; then
            config_dir="''${PHENIX_DE_ROOT:-$HOME/phenix/repos/phenix-de}/configs/phenix-shell"
            quickshell_args+=(--verbose)
          fi

          exec quickshell -p "$config_dir" "''${quickshell_args[@]}" "$@"
        '';
      };

      phenixShell = pkgs.symlinkJoin {
        name = "phenix-shell";
        paths = [ phenixShellRunner ];
        postBuild = ''
          mkdir -p "$out/share/applications"
          ln -s \
            ${pkgs.quickshell}/share/applications/org.quickshell.desktop \
            "$out/share/applications/org.quickshell.desktop"
        '';
        meta.mainProgram = "phenix-shell";
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
    };
}
