{ ... }: {
  perSystem = { pkgs, ... }: {
    packages.default = pkgs.writeShellScriptBin "hello-de" ''
      echo "hello from phenix-de"
    '';
  };
}
