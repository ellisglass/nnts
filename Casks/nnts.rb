cask "nnts" do
  version "2.0.0"
  sha256 "4b222fd66c14f40c950a2cd995594fcbccfaf84e18126639d546c829a3cd5620"

  url "https://github.com/unacau/nnts/releases/download/v#{version}/NNTS.dmg"
  name "NNTS"
  desc "Driverless Caps-Lock remapper, Chrome profile switcher & Copy-on-Select productivity suite in pure Swift 6"
  homepage "https://github.com/unacau/nnts"

  depends_on macos: :sonoma

  app "NNTS.app"

  zap trash: [
    "~/Library/Application Support/com.almosteleven.nnts",
    "~/Library/Caches/com.almosteleven.nnts",
    "~/Library/Preferences/com.almosteleven.nnts.plist",
  ]
end
