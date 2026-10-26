# Homebrew cask template. Copy into a tap (e.g. aiwithaj/homebrew-tap/Casks/anyfmt.rb)
# and fill version + sha256 from the release DMG:
#   shasum -a 256 dist/anyfmt-<version>.dmg
cask "anyfmt" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/aiwithaj/anyfmt/releases/download/v#{version}/anyfmt-#{version}.dmg"
  name "anyfmt"
  desc "Drag a file, tap a key, convert it: radial file converter for the menu bar"
  homepage "https://github.com/aiwithaj/anyfmt"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"
  depends_on arch: :arm64

  app "anyfmt.app"
  binary "#{appdir}/anyfmt.app/Contents/Helpers/anyfmt"

  zap trash: [
    "~/Library/Application Support/anyfmt",
    "~/Library/Caches/app.anyfmt",
    "~/Library/Preferences/app.anyfmt.plist",
    "~/Library/Logs/anyfmt",
  ]
end
