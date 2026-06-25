{ inputs, ... }: {
  perSystem = { pkgs, system, ... }: {
    phenix.overlays = [(final: prev: {
      phenix = (prev.phenix or {}) // {
        hyprland = inputs.hyprland.packages.${system}.hyprland;
        newshell = pkgs.quickshell;
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
    })];
  };
}
