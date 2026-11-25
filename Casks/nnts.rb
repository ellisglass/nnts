cask "nnts" do
  version "1.0"
  sha256 "a39f575a681738e591d39a0f81807352c3d2f0e67c4427852e5d46c75d3d79af"

  url "https://github.com/ellisglass/nnts/releases/download/v#{version}/NNTS.dmg"
  name "NNTS"
  desc "Driverless caps lock remote for Chrome/Brave profiles, first-letter app switching & Copy-on-Select"
  homepage "https://ellisglass.github.io/nnts/"

  depends_on macos: :sonoma

  app "NNTS.app"

  caveats <<~EOS
    NNTS #{version} ships locally signed without paid Apple Developer notarization.
    On first launch, clear quarantine or right-click /Applications/NNTS.app -> Open:
      xattr -cr /Applications/NNTS.app
  EOS

  zap trash: [
    "~/Library/Application Support/com.almosteleven.nnts",
    "~/Library/Caches/com.almosteleven.nnts",
    "~/Library/Preferences/com.almosteleven.nnts.plist",
  ]
end
