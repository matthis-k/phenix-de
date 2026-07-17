{
  inputs,
  pkgs,
  cfg,
}:
let
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
  inherit
    configuredPackage
    hyprctlFishCompletion
    hyprlandPackages
    selectedPackage
    ;
}
