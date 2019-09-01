# frozen_string_literal: true

require "spec_helper"

module Ferrum
  describe Headers do
    let!(:browser) { Browser.new(base_url: @server.base_url) }

    after { browser.reset }

    it "allows headers to be set" do
      browser.headers.set("Cookie" => "foo=bar", "YourName" => "your_value")
      browser.goto("/ferrum/headers")
      expect(browser.body).to include("COOKIE: foo=bar")
      expect(browser.body).to include("YOURNAME: your_value")
    end

    it "allows headers to be read" do
      expect(browser.headers.get).to eq({})
      browser.headers.set("User-Agent" => "Browser", "Host" => "foo.com")
      expect(browser.headers.get).to eq("User-Agent" => "Browser", "Host" => "foo.com")
    end

    it "supports User-Agent" do
      browser.headers.set("User-Agent" => "foo")
      browser.goto
      expect(browser.evaluate("window.navigator.userAgent")).to eq("foo")
    end

    it "sets headers for all HTTP requests" do
      browser.headers.set("X-Omg" => "wat")
      browser.goto
      browser.execute <<-JS
        var request = new XMLHttpRequest();
        request.open("GET", "/ferrum/headers", false);
        request.send();

        if (request.status === 200) {
          document.body.innerHTML = request.responseText;
        }
      JS
      expect(browser.body).to include("X_OMG: wat")
    end

    it "adds new headers" do
      browser.headers.set("User-Agent" => "Browser", "YourName" => "your_value")
      browser.headers.add("User-Agent" => "Super Browser", "Appended" => "true")
      browser.goto("/ferrum/headers")
      expect(browser.body).to include("USER_AGENT: Super Browser")
      expect(browser.body).to include("YOURNAME: your_value")
      expect(browser.body).to include("APPENDED: true")
    end

    it "sets headers on the initial request for referer only" do
      browser.headers.set("PermanentA" => "a")
      browser.headers.add("PermanentB" => "b")
      browser.headers.add({ "Referer" => "http://google.com" }, permanent: false)
      browser.headers.add({ "TempA" => "a" }, permanent: false) # simply ignored

      browser.goto("/ferrum/headers_with_ajax")
      initial_request = browser.at_css("#initial_request").text
      ajax_request = browser.at_css("#ajax_request").text

      expect(initial_request).to include("PERMANENTA: a")
      expect(initial_request).to include("PERMANENTB: b")
      expect(initial_request).to include("REFERER: http://google.com")
      expect(initial_request).to include("TEMPA: a")

      expect(ajax_request).to include("PERMANENTA: a")
      expect(ajax_request).to include("PERMANENTB: b")
      expect(ajax_request).to_not include("REFERER: http://google.com")
      expect(ajax_request).to include("TEMPA: a")
    end

    it "keeps added headers on redirects" do
      browser.headers.add({ "X-Custom-Header" => "1" }, permanent: false)
      browser.goto("/ferrum/redirect_to_headers")
      expect(browser.body).to include("X_CUSTOM_HEADER: 1")
    end

    context "multiple windows", skip: true do
      it "persists headers across popup windows" do
        browser.headers.set(
          "Cookie" => "foo=bar",
          "Host" => "foo.com",
          "User-Agent" => "foo"
        )
        browser.goto("/ferrum/popup_headers")
        browser.at_xpath("a[text()='pop up']").click
        # browser.click_link("pop up")
        browser.switch_to_window browser.windows.last
        expect(browser.body).to include("USER_AGENT: foo")
        expect(browser.body).to include("COOKIE: foo=bar")
        expect(browser.body).to include("HOST: foo.com")
      end

      it "sets headers in existing windows" do
        browser.open_new_window
        browser.headers.set(
          "Cookie" => "foo=bar",
          "Host" => "foo.com",
          "User-Agent" => "foo"
        )
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("USER_AGENT: foo")
        expect(browser.body).to include("COOKIE: foo=bar")
        expect(browser.body).to include("HOST: foo.com")

        browser.switch_to_window browser.windows.last
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("USER_AGENT: foo")
        expect(browser.body).to include("COOKIE: foo=bar")
        expect(browser.body).to include("HOST: foo.com")
      end

      it "keeps temporary headers local to the current window" do
        browser.open_new_window
        browser.headers.add("X-Custom-Header" => "1", permanent: false)

        browser.switch_to_window browser.windows.last
        browser.goto("/ferrum/headers")
        expect(browser.body).not_to include("X_CUSTOM_HEADER: 1")

        browser.switch_to_window browser.windows.first
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("X_CUSTOM_HEADER: 1")
      end

      it "does not mix temporary headers with permanent ones when propagating to other windows" do
        browser.open_new_window
        browser.headers.add("X-Custom-Header" => "1", permanent: false)
        browser.headers.add("Host" => "foo.com")

        browser.switch_to_window browser.windows.last
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("HOST: foo.com")
        expect(browser.body).not_to include("X_CUSTOM_HEADER: 1")

        browser.switch_to_window browser.windows.first
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("HOST: foo.com")
        expect(browser.body).to include("X_CUSTOM_HEADER: 1")
      end

      it "does not propagate temporary headers to new windows" do
        browser.goto
        browser.headers.add("X-Custom-Header" => "1", permanent: false)
        browser.open_new_window

        browser.switch_to_window browser.windows.last
        browser.goto("/ferrum/headers")
        expect(browser.body).not_to include("X_CUSTOM_HEADER: 1")

        browser.switch_to_window browser.windows.first
        browser.goto("/ferrum/headers")
        expect(browser.body).to include("X_CUSTOM_HEADER: 1")
      end
    end
  end
end
