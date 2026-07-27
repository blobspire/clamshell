# Homebrew formula for clamshell.
#
# This is NOT usable until you cut a tagged release, because Homebrew requires
# the sha256 of the release tarball. To publish:
#
#   1. git tag v1.0.0 && git push --tags
#   2. curl -sL https://github.com/blobspire/clamshell/archive/refs/tags/v1.0.0.tar.gz | shasum -a 256
#   3. paste that digest into `sha256` below and commit
#
# Homebrew taps must live in a repo named `homebrew-<name>`, so this file has
# to be copied into e.g. github.com/blobspire/homebrew-tap before
# `brew install blobspire/tap/clamshell` will work. Keeping it here means the
# canonical copy lives with the source.
#
# Until then, installing by hand is the documented path — see the README.

class Clamshell < Formula
  desc "Keep a Mac awake with the lid closed, on battery"
  homepage "https://github.com/blobspire/clamshell"
  url "https://github.com/blobspire/clamshell/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_TARBALL_SHA256"
  license "MIT"

  depends_on :macos

  def install
    bin.install "clamshell"
  end

  def caveats
    <<~EOS
      clamshell needs sudo to change power settings. To avoid a password
      prompt on every run, enable Touch ID for sudo:

        sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
        sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local

      It disables lid-close sleep, which PERSISTS ACROSS REBOOTS. Normally
      clamshell restores it on exit. If it is ever SIGKILLed, run:

        clamshell --off
    EOS
  end

  test do
    assert_match "clamshell #{version}", shell_output("#{bin}/clamshell --version")
    assert_match "USAGE", shell_output("#{bin}/clamshell --help")
  end
end
