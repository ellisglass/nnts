cask "nnts" do
  version "2.0.3"
  sha256 "aa490ea58df3328dd720c3e4b3acd5561edea43d50c5a7022f6173e64b17341f"

  url "https://github.com/ellisglass/nnts/releases/download/v#{version}/NNTS.dmg"
  name "NNTS"
  desc "Driverless Caps-Lock remapper, Chrome profile switcher & Copy-on-Select productivity suite in pure Swift 6"
  homepage "https://github.com/ellisglass/nnts"

  depends_on macos: :sonoma

  app "NNTS.app"

  zap trash: [
    "~/Library/Application Support/com.almosteleven.nnts",
    "~/Library/Caches/com.almosteleven.nnts",
    "~/Library/Preferences/com.almosteleven.nnts.plist",
  ]
end
