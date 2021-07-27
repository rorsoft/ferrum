# frozen_string_literal: true

module Ferrum
  class Browser
    module Options
      class Chrome < Base
        DEFAULT_OPTIONS = {
          "headless" => nil,
          "disable-gpu" => nil,
          "hide-scrollbars" => nil,
          "mute-audio" => nil,
          "enable-automation" => nil,
          "disable-web-security" => nil,
          "disable-session-crashed-bubble" => nil,
          "disable-breakpad" => nil,
          "disable-sync" => nil,
          "no-first-run" => nil,
          "use-mock-keychain" => nil,
          "keep-alive-for-test" => nil,
          "disable-popup-blocking" => nil,
          "disable-extensions" => nil,
          "disable-hang-monitor" => nil,
          "disable-features" => "site-per-process,TranslateUI",
          "disable-translate" => nil,
          "disable-background-networking" => nil,
          "enable-features" => "NetworkService,NetworkServiceInProcess",
          "disable-background-timer-throttling" => nil,
          "disable-backgrounding-occluded-windows" => nil,
          "disable-client-side-phishing-detection" => nil,
          "disable-default-apps" => nil,
          "disable-dev-shm-usage" => nil,
          "disable-ipc-flooding-protection" => nil,
          "disable-prompt-on-repost" => nil,
          "disable-renderer-backgrounding" => nil,
          "force-color-profile" => "srgb",
          "metrics-recording-only" => nil,
          "safebrowsing-disable-auto-update" => nil,
          "password-store" => "basic",
          "no-startup-window" => nil,
          # Note: --no-sandbox is not needed if you properly setup a user in the container.
          # https://github.com/ebidel/lighthouse-ci/blob/master/builder/Dockerfile#L35-L40
          # "no-sandbox" => nil,
        }.freeze

        MAC_BIN_PATH = [
          "/Applications/Chromium.app/Contents/MacOS/Chromium",
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        ].freeze
        LINUX_BIN_PATH = %w[chromium google-chrome-unstable google-chrome-beta
                            google-chrome chrome chromium-browser
                            google-chrome-stable].freeze
        WINDOWS_BIN_PATH = [
          "C:/Program Files/Google/Chrome Dev/Application/chrome.exe",
          "C:/Program Files/Google/Chrome/Application/chrome.exe"
        ].freeze

        def merge_required(flags, options, user_data_dir)
          port = options.fetch(:port, BROWSER_PORT)
          host = options.fetch(:host, BROWSER_HOST)
          flags.merge("remote-debugging-port" => port,
                      "remote-debugging-address" => host,
                      # Doesn't work on MacOS, so we need to set it by CDP
                      "window-size" => options[:window_size].join(","),
                      "user-data-dir" => user_data_dir)
        end

        def merge_default(flags, options)
          unless options.fetch(:headless, true)
            defaults = except("headless", "disable-gpu")
          end

          defaults ||= DEFAULT_OPTIONS
          defaults.merge(flags)
        end
      end
    end
  end
end
