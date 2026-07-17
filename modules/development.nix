_: {
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        name = "phenix-de-dev";
        packages = with pkgs; [
          devenv
          git
          kdePackages.qtdeclarative
          lua
          nix
          quickshell
        ];
        shellHook = ''
          echo "phenix-de dev shell"
          echo "  maintenance: devenv test"
          echo "  fixes:       devenv tasks run maintenance:fix"
        '';
      };
    };
}
