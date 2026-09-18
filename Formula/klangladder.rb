class Klangladder < Formula
  desc "Menu bar app that switches macOS default audio devices by priority"
  homepage "https://github.com/janthoXO/KlangLadder"
  url "https://github.com/janthoXO/KlangLadder.git",
      tag:      "v0.0.2",
      revision: "633527d0450cfe8241c4176db62a3150409083a0"
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
