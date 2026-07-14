{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      phenixShell = pkgs.writeShellApplication {
        name = "phenix-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          exec quickshell --config ${../configs/phenix-shell}/shell.qml "$@"
        '';
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
        phenix-shell = phenixShell;

        inherit (pkgs)
          fish
          kitty
          starship
          ;

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
