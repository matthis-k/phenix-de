{ inputs, ... }:
{
  perSystem = {
    phenix.overlays = [ inputs.phenix-de.overlays.default ];
  };
}
