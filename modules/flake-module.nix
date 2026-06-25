{ ... }: {
  perSystem = { ... }: {
    phenix.overlays = [(final: prev: {
      phenix = (prev.phenix or {}) // {
        hello-de = final.writeShellScriptBin "hello-de" ''
          echo "hello from phenix-de"
        '';
      };
    })];
  };
}
