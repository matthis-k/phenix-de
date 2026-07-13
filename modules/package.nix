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

      waylandApps = {
        wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
        wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
        grim = "${pkgs.grim}/bin/grim";
        slurp = "${pkgs.slurp}/bin/slurp";
        swappy = "${pkgs.swappy}/bin/swappy";
        tesseract = "${pkgs.tesseract}/bin/tesseract";
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

      apps = pkgs.lib.mapAttrs (_: program: {
        type = "app";
        inherit program;
      }) waylandApps;
    };
}
