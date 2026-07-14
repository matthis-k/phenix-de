{ inputs }:
{ pkgs, ... }:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ./starship.nix
  ];

  home.packages = with pkgs; [
    dust
    hyperfine
  ];

  programs = {
    bat.enable = true;
    bottom.enable = true;
    command-not-found.enable = false;

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      icons = "auto";
    };

    fd.enable = true;

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        set fish_cursor_default block
        set fish_cursor_insert line
        set fish_cursor_replace_one underscore
        set fish_cursor_replace underscore
        set fish_cursor_external line
        set fish_cursor_visual block

        function fish_user_key_bindings
          fish_vi_key_bindings
          for mode in default insert visual replace replace_one
            bind -M $mode \cZ 'fg'
          end
        end

        if not set -q SSH_AUTH_SOCK
          eval (${pkgs.openssh}/bin/ssh-agent -c) > /dev/null
        end
      '';
      shellAliases = {
        c = "z";
        cat = "bat";
        ci = "zi";
        du = "dust";
        find = "fd";
        grep = "rg";
        ls = "eza";
        yy = "yazi";
      };
    };

    nix-index = {
      enable = true;
      enableFishIntegration = false;
      symlinkToCacheHome = true;
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    ripgrep.enable = true;

    yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "yy";
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
