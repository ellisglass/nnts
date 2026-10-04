cask "nnts" do
  version "2.0.1"
  sha256 "b11d9f63275cf0859e2f17a319a31ec6064d35fc3c10a7b664f99b9fb2818cc2"

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
