# frozen_string_literal: true

module Ferrum
  describe Page::Animation do
    it "gets default playback rate" do
      browser.go_to("/animation")

      expect(browser.playback_rate).to eq(1)
    end

    it "sets playback rate" do
      browser.playback_rate = 2000

      browser.go_to("/animation")

      expect(browser.playback_rate).to eq(2000)
    end
  end
end
