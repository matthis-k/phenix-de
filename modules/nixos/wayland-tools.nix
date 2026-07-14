{ pkgs, ... }:
let
  screenShot = pkgs.writeShellApplication {
    name = "screen-shot";
    runtimeInputs = with pkgs; [
      coreutils
      grimblast
      satty
    ];
    text = ''
      mode="''${1:-region}"
      screenshots_dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
      mkdir -p "$screenshots_dir"

      case "$mode" in
        region)
          output_file="$screenshots_dir/screen-shot-region-$(date +%Y%m%d-%H%M%S).png"
          grimblast --freeze --filetype ppm save area - | satty --filename - --fullscreen --output-filename "$output_file"
          ;;
        region-direct)
          output_file="$screenshots_dir/screen-shot-region-$(date +%Y%m%d-%H%M%S).png"
          grimblast --notify --freeze copysave area "$output_file"
          ;;
        output)
          output_file="$screenshots_dir/screen-shot-output-$(date +%Y%m%d-%H%M%S).png"
          grimblast --filetype ppm save output - | satty --filename - --fullscreen --output-filename "$output_file"
          ;;
        window)
          output_file="$screenshots_dir/screen-shot-window-$(date +%Y%m%d-%H%M%S).png"
          grimblast --filetype ppm save active - | satty --filename - --fullscreen --output-filename "$output_file"
          ;;
        *)
          printf 'usage: screen-shot [region|region-direct|output|window]\n' >&2
          exit 2
          ;;
      esac
    '';
  };

  screenReadRegion = pkgs.writeShellApplication {
    name = "screen-read-region";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      grimblast
      libnotify
      tesseract
      wl-clipboard
    ];
    text = ''
      tmp_png="$(mktemp --suffix .png)"
      trap 'rm -f "$tmp_png"' EXIT
      grimblast --freeze save area - > "$tmp_png"
      text="$(tesseract "$tmp_png" stdout -l "''${OCR_LANG:-eng}" 2>/dev/null | sed '/^[[:space:]]*$/d')"

      if [ -z "$text" ]; then
        notify-send "Screen OCR" "No text detected"
        exit 1
      fi

      printf '%s' "$text" | wl-copy
      printf '%s\n' "$text"
      notify-send "Screen OCR" "Copied text to clipboard"
    '';
  };

  screenEditClipboard = pkgs.writeShellApplication {
    name = "screen-edit-clipboard";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      satty
      wl-clipboard
    ];
    text = ''
      screenshots_dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
      output_file="$screenshots_dir/screen-edit-$(date +%Y%m%d-%H%M%S).png"
      mkdir -p "$screenshots_dir"

      image_type="$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1 || true)"
      if [ -z "$image_type" ]; then
        notify-send "Satty" "Clipboard has no image"
        exit 1
      fi

      wl-paste --type "$image_type" | satty --filename - --fullscreen --output-filename "$output_file"
    '';
  };

  readImage = pkgs.writeShellApplication {
    name = "read-image";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
      libnotify
      tesseract
      wl-clipboard
    ];
    text = ''
      if [ "''${1:-}" = "--clipboard" ]; then
        image_type="$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1 || true)"
        if [ -z "$image_type" ]; then
          notify-send "read-image" "Clipboard has no image"
          exit 1
        fi
        wl-paste --type "$image_type" | "$0"
        exit
      fi

      tmp="$(mktemp --suffix .png)"
      trap 'rm -f "$tmp"' EXIT
      cat > "$tmp"
      text="$(tesseract "$tmp" stdout -l "''${OCR_LANG:-eng}" 2>/dev/null | sed '/^[[:space:]]*$/d')"

      if [ -z "$text" ]; then
        notify-send "read-image" "No text detected"
        exit 1
      fi
      printf '%s\n' "$text"
    '';
  };

  annotate = pkgs.writeShellApplication {
    name = "annotate";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      libnotify
      satty
      wl-clipboard
    ];
    text = ''
      if [ "''${1:-}" = "--clipboard" ]; then
        image_type="$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1 || true)"
        if [ -z "$image_type" ]; then
          notify-send "annotate" "Clipboard has no image"
          exit 1
        fi
        wl-paste --type "$image_type" | "$0"
        exit
      fi

      screenshots_dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
      output_file="$screenshots_dir/annotate-$(date +%Y%m%d-%H%M%S).png"
      mkdir -p "$screenshots_dir"
      cat | satty --filename - --fullscreen --output-filename "$output_file"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    grimblast
    libnotify
    satty
    tesseract
    wl-clipboard
    screenShot
    screenReadRegion
    screenEditClipboard
    readImage
    annotate
  ];
}
