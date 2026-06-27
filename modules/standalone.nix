{ inputs, ... }: {
  perSystem =
    { pkgs, system, ... }:
    let
      phenix-shell = pkgs.writeShellScriptBin "phenix-shell" ''
        exec ${pkgs.quickshell}/bin/quickshell --config ${toString ../configs/phenix-shell}/shell.qml "$@"
      '';
    in
    {
      packages = {
        hyprland = inputs.hyprland.packages.${system}.hyprland;

        inherit phenix-shell;

        inherit (pkgs) kitty;

        wayland-utils = pkgs.symlinkJoin {
          name = "wayland-utils";
          paths = with pkgs; [
            grim
            slurp
            swappy
            wl-clipboard
            tesseract
          ];
        };

        inherit (pkgs) fish;

        inherit (pkgs) starship;
      };

      devShells.default = pkgs.mkShell {
        name = "phenix-de-dev";
        packages = with pkgs; [
          nix
          nixfmt
          statix
          deadnix
        ];
        shellHook = ''
          repo-hook() {
            if command -v tend &>/dev/null; then
              tend check --profile git-hook --staged "$@"
            else
              echo "tend not available — enter the root Phenix dev shell" >&2
              return 1
            fi
          }
          repo-pushgate() {
            if command -v tend &>/dev/null; then
              tend check --profile pre-push "$@"
            else
              echo "tend not available — enter the root Phenix dev shell" >&2
              return 1
            fi
          }
          repo-check() {
            if command -v tend &>/dev/null; then
              tend check --profile manual "$@"
            else
              echo "tend not available — enter the root Phenix dev shell" >&2
              return 1
            fi
          }
          repo-fix() {
            if command -v tend &>/dev/null; then
              tend check --profile fix "$@"
            else
              echo "tend not available — enter the root Phenix dev shell" >&2
              return 1
            fi
          }
          export -f repo-hook repo-pushgate repo-check repo-fix 2>/dev/null || true
          echo "phenix-de dev shell"
          echo "  tools: nix nixfmt statix deadnix"
          if command -v tend &>/dev/null; then
            echo "  repo-hook      -> tend check --profile git-hook --staged"
            echo "  repo-pushgate  -> tend check --profile pre-push"
            echo "  repo-check     -> tend check --profile manual"
            echo "  repo-fix       -> tend check --profile fix"
          fi
        '';
      };
    };
}
