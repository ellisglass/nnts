cask "xomsky" do
  version "1.1.2"
  sha256 "ce6dffd7a3e56d7feeb0d3b6e6d06a2f84765b50278db537b655c250a30b8d25"

  url "https://github.com/unacau/xomsky/releases/download/v#{version}/Xomsky.dmg"
  name "Xomsky"
  desc "Driverless Caps-Lock remapper & Chrome profile switcher in pure Swift 6"
  homepage "https://github.com/unacau/xomsky"

  depends_on macos: :sonoma

  app "Xomsky.app"

  zap trash: [
    "~/Library/Application Support/com.almosteleven.xomsky",
    "~/Library/Caches/com.almosteleven.xomsky",
    "~/Library/Preferences/com.almosteleven.xomsky.plist",
  ]
end
