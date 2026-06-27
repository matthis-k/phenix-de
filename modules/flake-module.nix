{ inputs, ... }: {
  perSystem = { system, ... }: {
    phenix.overlays = [(final: prev: {
      phenix = (prev.phenix or {}) // {
        inherit (inputs.phenix-de.packages.${final.system})
          hyprland phenix-shell kitty wayland-utils fish starship;
      };
    })];
  };
}
