{ inputs, ... }: {
  perSystem = { pkgs, system, ... }: let
    phenix-shell = pkgs.writeShellScriptBin "phenix-shell" ''
      exec ${pkgs.quickshell}/bin/quickshell --config ${toString ../configs/phenix-shell}/shell.qml "$@"
    '';
  in {
    packages = {
      hyprland = inputs.hyprland.packages.${system}.hyprland;

      inherit phenix-shell;

      kitty = pkgs.kitty;

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

      fish = pkgs.fish;

      starship = pkgs.starship;
    };
  };
}
