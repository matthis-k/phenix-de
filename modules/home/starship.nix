{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "[ $username$hostname ](bold fg:black bg:blue)$directory([ ($git_branch )($git_status)](fg:white bg:black))$fill[( $cmd_duration )](fg:white bg:black)[ $time ](bold fg:black bg:blue)\n$character";

      fill = {
        symbol = " ";
        style = "$style";
      };

      hostname = {
        style = "$style";
        format = "[@$hostname]($style)";
        ssh_symbol = "󰖟";
      };

      username = {
        style_user = "$style";
        style_root = "$style";
        format = "[$user]($style)";
        show_always = true;
      };

      cmd_duration = {
        style = "$style";
        min_time = 500;
        format = "[[$duration](fg:yellow bg:black)]($style)";
      };

      directory = {
        style = "bold fg:yellow bg:bright-black";
        truncation_length = 3;
        home_symbol = "~";
        format = "[ $path ]($style)";
      };

      git_branch = {
        style = "$style";
        symbol = "󰘬";
        format = "[[$symbol $branch](fg:blue bg:black)]($style)";
      };

      git_status = {
        style = "$style";
        ahead = "[⇡$ahead_count](fg:yellow bg:black)";
        behind = "[⇣$behind_count](fg:yellow bg:black)";
        format = "[($ahead_behind)($conflicted$stashed$staged$modified$deleted$renamed$untracked )]($style)";
        conflicted = "[!](fg:red bg:black)";
        untracked = "[?](fg:blue bg:black)";
        stashed = "[s](fg:green bg:black)";
        modified = "[~](fg:yellow bg:black)";
        staged = "[+](fg:green bg:black)";
        renamed = "[»](fg:yellow bg:black)";
        deleted = "[-](fg:red bg:black)";
      };

      time = {
        style = "$style";
        disabled = false;
        time_format = "%R";
        format = "[$time]($style)";
      };

      character = {
        success_symbol = "[❯](bold green) ";
        error_symbol = "[❯](bold red) ";
        vimcmd_symbol = "[❯ ](bold orange)";
        vimcmd_replace_one_symbol = "[❯ ](bold purple)";
        vimcmd_replace_symbol = "[❯ ](bold yellow)";
        vimcmd_visual_symbol = "[❯ ](bold purple)";
      };
    };
  };
}
