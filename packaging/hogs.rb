cask "hogs" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/starzonmyarmz/hogs/releases/download/v#{version}/Hogs-#{version}.zip"
  name "Hogs"
  desc "Menu bar app that flags processes hogging the CPU"
  homepage "https://github.com/starzonmyarmz/hogs"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Hogs.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Hogs.app"],
        writable_paths: ["Hogs.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.iamdanielmarino.hogs"

  zap trash: "~/Library/Preferences/com.iamdanielmarino.hogs.plist"
end
