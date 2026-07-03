class Macwal < Formula
  desc "Wallpaper-driven macOS theming CLI"
  homepage "https://github.com/your-org/macwal"
  url "https://github.com/your-org/macwal/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
  license "MIT"

  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/macwal"
  end

  test do
    assert_match "macwal", shell_output("#{bin}/macwal --help")
    assert_match "shell", shell_output("#{bin}/macwal list-targets")
  end
end
