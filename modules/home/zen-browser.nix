{ inputs }:
{ pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  zenPackage = inputs.zen-flake.packages.${system}.beta;
  firefoxAddons = inputs.firefox-addons.packages.${system};
  nixSnowflake = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  newTab = "https://duckduckgo.com/";
  openWebUIOrigin = "https://matthisk-desktop-phenix.local";
in
{
  imports = [ inputs.zen-flake.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    package = zenPackage;
    setAsDefaultBrowser = true;

    policies = {
      AppAutoUpdate = false;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      BackgroundAppUpdate = false;
      Certificates.ImportEnterpriseRoots = true;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisableMasterPasswordCreation = true;
      DisablePasswordReveal = true;
      DisablePocket = true;
      DisableProfileImport = true;
      DisableProfileRefresh = true;
      DisableSetDesktopBackground = true;
      DisableSystemAddonUpdate = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;

      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://cloudflare-dns.com/dns-query";
        Fallback = true;
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };

      HTTPSOnlyMode.Value = true;
      NewTabPage = {
        URL = newTab;
        Locked = true;
      };
      OfferToSaveLogins = false;
      OverrideFirstRunPage = newTab;
      OverridePostUpdatePage = "";
      PasswordManagerEnabled = false;
      Permissions.Microphone.Allow = [ openWebUIOrigin ];
      PromptForDownloadLocation = true;
      SearchBar = "unified";

      Preferences = {
        "browser.contentblocking.category" = "strict";
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.search.suggest.enabled" = false;
        "browser.search.suggest.enabled.private" = false;
        "browser.urlbar.quicksuggest.enabled" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.pocket.enabled" = false;
        "privacy.query_stripping.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.pbmode.enabled" = true;
      };

      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
      };
    };

    profiles.default = {
      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
        engines = {
          "My NixOS" = {
            urls = [ { template = "https://mynixos.com/search?q={searchTerms}"; } ];
            icon = nixSnowflake;
            definedAliases = [ "@nx" ];
          };
          "Nix Packages" = {
            urls = [ { template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}"; } ];
            icon = nixSnowflake;
            definedAliases = [
              "@np"
              "@pkg"
              "@pkgs"
            ];
          };
          "Nix Options" = {
            urls = [ { template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}"; } ];
            icon = nixSnowflake;
            definedAliases = [
              "@no"
              "@opt"
            ];
          };
          ChatGPT = {
            urls = [
              {
                template = "https://chat.openai.com";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [
              "@gpt"
              "@ai"
              "@chatgpt"
            ];
          };
          "Open WebUI" = {
            urls = [
              {
                template = "${openWebUIOrigin}/";
                params = [
                  {
                    name = "q";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            definedAliases = [ "@llm" ];
          };
        };
      };

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Nix resources";
            toolbar = true;
            bookmarks = [
              {
                name = "NixOS packages";
                url = "https://search.nixos.org/packages";
              }
              {
                name = "NixOS options";
                url = "https://search.nixos.org/options";
              }
              {
                name = "Home Manager options";
                url = "https://home-manager-options.extranix.com";
              }
            ];
          }
          {
            name = "AI";
            toolbar = true;
            bookmarks = [
              {
                name = "Open WebUI";
                url = openWebUIOrigin;
              }
            ];
          }
        ];
      };

      extensions.packages = with firefoxAddons; [
        ublock-origin
        privacy-badger
        duckduckgo-privacy-essentials
        bitwarden
        catppuccin-web-file-icons
      ];

      settings = {
        "browser.startup.homepage" = newTab;
        "browser.tabs.warnOnClose" = false;
        "browser.warnOnQuitShortcut" = false;
        "browser.compactmode.show" = true;
        "browser.download.useDownloadDir" = false;
        "browser.urlbar.showFullURL" = true;
        "browser.urlbar.trimURLs" = false;
        "extensions.pocket.enabled" = false;
        "general.autoScroll" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "network.trr.mode" = 2;
        "privacy.donottrackheader.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.pbmode.enabled" = true;
        "signon.rememberSignons" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "zen.urlbar.behavior" = "normal";
        "zen.view.use-single-toolbar" = false;
      };

      pinsForce = true;
      pinsForceAction = "demote";
      pins = {
        ChatGPT = {
          id = "b2c3d4e5-f6a7-8901-bcde-f12345678901";
          url = "https://chat.openai.com";
          position = 101;
          isEssential = true;
        };
        "Open WebUI" = {
          id = "c3d4e5f6-a7b8-9012-cdef-123456789012";
          url = openWebUIOrigin;
          position = 102;
          isEssential = true;
        };
        GitHub = {
          id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
          url = "https://github.com";
          position = 103;
          isEssential = true;
        };
        YouTube = {
          id = "d4e5f6a7-b8c9-0123-defa-234567890123";
          url = "https://youtube.com";
          position = 104;
          isEssential = true;
        };
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/json" = [ "nvim.desktop" ];
      "image/gif" = [ "zen-beta.desktop" ];
      "image/jpeg" = [ "zen-beta.desktop" ];
      "image/png" = [ "zen-beta.desktop" ];
      "image/svg+xml" = [ "zen-beta.desktop" ];
      "image/webp" = [ "zen-beta.desktop" ];
      "text/markdown" = [ "nvim.desktop" ];
      "text/plain" = [ "nvim.desktop" ];
    };
  };

  stylix.targets.zen-browser.profileNames = [ "default" ];
  home.sessionVariables.BROWSER = "zen-beta";
}
