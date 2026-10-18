# Homebrew cask template. Copy into a tap (e.g. aiwithaj/homebrew-tap/Casks/halo.rb)
# and fill version + sha256 from the release DMG:
#   shasum -a 256 dist/Halo-<version>.dmg
cask "halo" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/aiwithaj/halo/releases/download/v#{version}/Halo-#{version}.dmg"
  name "Halo"
  desc "Drag a file, tap a key, convert it: radial file converter for the menu bar"
  homepage "https://github.com/aiwithaj/halo"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "Halo.app"
  binary "#{appdir}/Halo.app/Contents/Helpers/halo"

  zap trash: [
    "~/Library/Application Support/Halo",
    "~/Library/Caches/dev.aiwithaj.halo",
    "~/Library/Preferences/dev.aiwithaj.halo.plist",
    "~/Library/Logs/Halo",
  ]
end
