# Homebrew formula template: the `halo` command-line tool only, no app.
# Copy into a tap (e.g. aiwithaj/homebrew-tap/Formula/halo-cli.rb) and fill
# version + sha256 from the release tarball. The cask (halo.rb, next to this
# file) installs the app and links the same binary; install one or the other,
# since both put `halo` on PATH.
#
# Release tarball layout (built from a signed Release build; the CLI's rpath is
# @executable_path/../Frameworks and it finds its engines in its own folder):
#
#   halo-cli-<version>-arm64/
#     Helpers/halo  Helpers/ffmpeg  Helpers/ffprobe  Helpers/resvg
#     Frameworks/HaloCore.framework
#     LICENSE  LICENSES/
#
# Made from the app bundle with:
#   APP=build/DerivedData/Build/Products/Release/Halo.app
#   D=halo-cli-<version>-arm64; mkdir -p $D/Helpers $D/Frameworks
#   cp -R $APP/Contents/Helpers/{halo,ffmpeg,ffprobe,resvg} $D/Helpers/
#   cp -R $APP/Contents/Frameworks/HaloCore.framework $D/Frameworks/
#   cp -R LICENSE LICENSES $D/
#   tar -czf $D.tar.gz $D && shasum -a 256 $D.tar.gz
class HaloCli < Formula
  desc "Convert images, video, audio and documents locally (CLI and MCP server)"
  homepage "https://github.com/aiwithaj/halo"
  # Placeholder: the GitHub release asset for this version.
  url "https://github.com/aiwithaj/halo/releases/download/v0.1.0/halo-cli-0.1.0-arm64.tar.gz"
  version "0.1.0"
  # Placeholder: `shasum -a 256 halo-cli-<version>-arm64.tar.gz`.
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "AGPL-3.0-only"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :ventura

  def install
    # Keep the bundle layout so rpaths and engine lookup work unchanged.
    libexec.install "Helpers", "Frameworks"
    bin.install_symlink libexec/"Helpers/halo"
    prefix.install "LICENSE"
    (share/"halo").install "LICENSES" if File.directory?("LICENSES")
  end

  def caveats
    <<~EOS
      Use it from agents over MCP:
        claude mcp add halo -- #{opt_bin}/halo mcp
      Check engines and packs with `halo doctor`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/halo version")
    assert_match "\"schemaVersion\" : 1", shell_output("#{bin}/halo version --json")
    # The bundled engines are found through the bin/ symlink.
    assert_match "\"found\" : true", shell_output("#{bin}/halo doctor --json")
  end
end
