{
  xdg.configFile."satty/config.toml".text = ''
    [general]
    copy-command = "wl-copy"
    corner-roundness = 10
    early-exit = true
    fullscreen = true
    initial-tool = "arrow"
    actions-on-enter = ["save-to-clipboard", "save-to-file", "exit"]
    actions-on-escape = ["exit"]
    actions-on-right-click = ["save-to-clipboard", "save-to-file", "exit"]
  '';
}
