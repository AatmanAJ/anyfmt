# Homebrew formula template: the `anyfmt` command-line tool only, no app.
# Copy into a tap (e.g. aiwithaj/homebrew-tap/Formula/anyfmt-cli.rb) and fill
# version + sha256 from the release tarball. The cask (anyfmt.rb, next to this
# file) installs the app and links the same binary; install one or the other,
# since both put `anyfmt` on PATH.
#
# Release tarball layout (built from a signed Release build; the CLI's rpath is
# @executable_path/../Frameworks and it finds its engines in its own folder):
#
#   anyfmt-cli-<version>-arm64/
#     Helpers/anyfmt  Helpers/ffmpeg  Helpers/ffprobe  Helpers/resvg
#     Frameworks/AnyfmtCore.framework
#     LICENSE  LICENSES/
#
# Made from the app bundle with:
#   APP=build/DerivedData/Build/Products/Release/anyfmt.app
#   D=anyfmt-cli-<version>-arm64; mkdir -p $D/Helpers $D/Frameworks
#   cp -R $APP/Contents/Helpers/{anyfmt,ffmpeg,ffprobe,resvg} $D/Helpers/
#   cp -R $APP/Contents/Frameworks/AnyfmtCore.framework $D/Frameworks/
#   cp -R LICENSE LICENSES $D/
#   tar -czf $D.tar.gz $D && shasum -a 256 $D.tar.gz
class AnyfmtCli < Formula
  desc "Convert images, video, audio and documents locally (CLI and MCP server)"
  homepage "https://github.com/aiwithaj/anyfmt"
  # Placeholder: the GitHub release asset for this version.
  url "https://github.com/aiwithaj/anyfmt/releases/download/v0.1.0/anyfmt-cli-0.1.0-arm64.tar.gz"
  version "0.1.0"
  # Placeholder: `shasum -a 256 anyfmt-cli-<version>-arm64.tar.gz`.
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
    bin.install_symlink libexec/"Helpers/anyfmt"
    prefix.install "LICENSE"
    (share/"anyfmt").install "LICENSES" if File.directory?("LICENSES")
  end

  def caveats
    <<~EOS
      Use it from agents over MCP:
        claude mcp add anyfmt -- #{opt_bin}/anyfmt mcp
      Check engines and packs with `anyfmt doctor`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anyfmt version")
    assert_match "\"schemaVersion\" : 1", shell_output("#{bin}/anyfmt version --json")
    # The bundled engines are found through the bin/ symlink.
    assert_match "\"found\" : true", shell_output("#{bin}/anyfmt doctor --json")
  end
end
