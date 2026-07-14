{
  inputs,
  lib,
  ...
}:
let
  luaValueType = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
    (lib.types.listOf luaValueType)
    (lib.types.attrsOf luaValueType)
  ];

  toLua =
    value:
    if lib.isAttrs value then
      "{ "
      + lib.concatStringsSep ", " (
        lib.mapAttrsToList (name: attrValue: "[${builtins.toJSON name}] = ${toLua attrValue}") value
      )
      + " }"
    else if lib.isList value then
      "{ " + lib.concatMapStringsSep ", " toLua value + " }"
    else
      builtins.toJSON value;

  hyprlandWrapper = inputs.nix-wrapper-modules.lib.wrapModule (
    {
      config,
      lib,
      pkgs,
      wlib,
      ...
    }:
    let
      nixImportLua = pkgs.writeText "nix-import.lua" ''
        return ${toLua config.luaVariables}
      '';

      usesDefaultConfig = config.configDirectory == "~/.config/hypr";

      mergedConfigDir =
        if usesDefaultConfig then
          null
        else
          pkgs.runCommand "phenix-hyprland-config" { } ''
            cp -r --no-preserve=mode,ownership ${config.configDirectory} "$out"
            chmod -R u+w "$out"
            cp ${nixImportLua} "$out/nix-import.lua"
          '';

      configFlag =
        if usesDefaultConfig then "~/.config/hypr/hyprland.lua" else "${mergedConfigDir}/hyprland.lua";
    in
    {
      options.configDirectory = lib.mkOption {
        type = wlib.types.stringable;
        default = "~/.config/hypr";
        description = "Hyprland configuration directory containing hyprland.lua.";
      };

      options.luaVariables = lib.mkOption {
        type = luaValueType;
        default = { };
        description = "Nix values serialized into the Hyprland nix-import.lua module.";
      };

      config = {
        binName = "Hyprland";
        flags."--config" = configFlag;
        meta.description = "Hyprland with the Phenix Lua desktop configuration";
        passthru = {
          providedSessions = [ "hyprland-uwsm" ];
          inherit nixImportLua;
        };
      };
    }
  );
in
{
  flake.lib.phenixHyprlandWrapper = hyprlandWrapper;
}
