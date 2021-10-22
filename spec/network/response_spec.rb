# frozen_string_literal: true

module Ferrum
  class Network
    describe Response do
      let(:traffic) { page.network.traffic }

      it "captures responses" do
        page.go_to("/ferrum/with_js")

        expect(traffic.last.response.status).to eq(200)
      end

      it "gets response body" do
        page.go_to("/ferrum/with_js")
        responses = traffic.map(&:response)

        expect(responses.size).to eq(4)

        expect(responses[0].url).to end_with("/ferrum/with_js")
        expect(responses[0].body).to include("ferrum with_js")

        expect(responses[1].url).to end_with("/ferrum/jquery.min.js")
        expect(responses[1].body).to include("jQuery v1.11.3")

        expect(responses[2].url).to end_with("/ferrum/jquery-ui.min.js")
        expect(responses[2].body).to include("jQuery UI - v1.11.4")

        expect(responses[3].url).to end_with("/ferrum/test.js")
        expect(responses[3].body).to include("This is test.js file content")
      end

      it "captures errors" do
        page.go_to("/ferrum/with_ajax_fail")
        expect(page.at_xpath("//h1[text() = 'Done']")).to be

        expect(traffic.last.error).to be
      end

      it "counts network traffic for each loaded resource" do
        page.go_to("/ferrum/with_js")
        responses = traffic.map(&:response)
        resources_size = {
          %r{/ferrum/jquery.min.js$}    => File.size(PROJECT_ROOT + "/spec/support/public/jquery-1.11.3.min.js"),
          %r{/ferrum/jquery-ui.min.js$} => File.size(PROJECT_ROOT + "/spec/support/public/jquery-ui-1.11.4.min.js"),
          %r{/ferrum/test.js$}          => File.size(PROJECT_ROOT + "/spec/support/public/test.js"),
          %r{/ferrum/with_js$}          => 2343
        }

        resources_size.each do |resource, size|
          expect(responses.find { |r| r.url[resource] }.body_size).to eq(size)
        end
      end

      context "status code support" do
        it "determines status from the simple response" do
          browser.go_to("/ferrum/status/500")
          expect(browser.network.status).to eq(500)
        end

        it "determines status code when the page has a few resources" do
          browser.go_to("/ferrum/with_different_resources")
          expect(browser.network.status).to eq(200)
        end

        it "determines status code even after redirect" do
          browser.go_to("/ferrum/redirect")
          expect(browser.network.status).to eq(200)
        end

        it "determines status code when user goes to a page by using a link on it" do
          browser.go_to("/ferrum/with_different_resources")

          browser.at_xpath("//a[text() = 'Go to 500']").click

          expect(browser.network.status).to eq(500)
        end

        it "determines properly status when user goes through a few pages" do
          browser.go_to("/ferrum/with_different_resources")

          browser.at_xpath("//a[text() = 'Go to 200']").click
          browser.at_xpath("//a[text() = 'Go to 201']").click
          browser.at_xpath("//a[text() = 'Do redirect']").click
          browser.at_xpath("//a[text() = 'Go to 402']").click

          expect(browser.network.status).to eq(402)
        end
      end
    end
  end
end
