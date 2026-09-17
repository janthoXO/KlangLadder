class Klangladder < Formula
  desc "Menu bar app that switches macOS default audio devices by priority"
  homepage "https://github.com/janthoXO/KlangLadder"
  url "https://github.com/janthoXO/KlangLadder.git",
      tag:      "v0.0.1",
      revision: "dfb0e6f9a6fff9d3325fff9f92e2dffac0c7a17d"
  head "https://github.com/janthoXO/KlangLadder.git", branch: "main"

  depends_on macos: :sonoma

  def install
    # SwiftPM's own sandbox can't nest inside Homebrew's.
    ENV["VERSION"] = version.to_s unless build.head?
    system "./bundle.sh", "--disable-sandbox"
    prefix.install "build/KlangLadder.app"
  end

  def caveats
    <<~EOS
      Start KlangLadder now and at every login:
        brew services start klangladder
      Or open it once:
        open #{opt_prefix}/KlangLadder.app
    EOS
  end

  service do
    run opt_prefix/"KlangLadder.app/Contents/MacOS/KlangLadder"
  end

  test do
    assert_path_exists prefix/"KlangLadder.app/Contents/MacOS/KlangLadder"
    system "codesign", "--verify", prefix/"KlangLadder.app"
  end
end
