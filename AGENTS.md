# Hogs

Menu bar app that flags processes hogging the CPU

Read before working:
- `DESIGN.md` before touching anything people see.

## Commands

```sh
swift test                                  # the HogsCore tests
swift run                                   # run the app without bundling it
swift format --in-place --recursive Package.swift Sources Tests
scripts/install.sh                          # build, replace /Applications/Hogs.app as X.Y.Z-dev+<sha>, open it
scripts/build-app.sh 1.2.3                  # dist/Hogs.app and dist/hogs-1.2.3.zip
scripts/release --dry-run                   # what the next release would be
```

`scripts/install.sh` and `build-app.sh` sign ad hoc unless `SIGN_IDENTITY` names a certificate. Use one long-lived self-signed certificate per machine (Keychain Access → Certificate Assistant → Create a Certificate, type Code Signing), so macOS keeps the app's permissions across reinstalls.

## Layout

- `Sources/HogsCore/`: all the logic, with no AppKit or SwiftUI, so `swift test` covers it. `ProcessList` samples processes, `HogTracker` decides which are hogs and when to notify, `Preferences` and `IgnoreList` hold the settings, and `Format` the menu's text.
- `Sources/Hogs/`: the AppKit shell. `main.swift` starts it as an accessory app (no Dock icon), `AppDelegate` runs the menu, sampling and notifications, `SettingsWindow` the Settings window, and `PigIcon` the menu bar pig. Keep it thin: anything worth testing moves into Core.
- `Tests/HogsCoreTests/`: Swift Testing (`@Suite`, `@Test`, `#expect`).
- `packaging/`: `Info.plist` (the version is `@VERSION@`, filled in at build time), `icon.svg` (the glyph `scripts/make-icon.swift` draws on the app icon tile), and `hogs.rb`, the cask template the release workflow pushes to the tap.
- `scripts/`: `build-app.sh`, `install.sh`, `make-icon.swift` and release tooling.

## Invariants and footguns

What was learned the hard way. Add to this list whenever something breaks in a way the code doesn't make obvious.

- The bundle ID `com.iamdanielmarino.hogs` never changes. macOS ties permissions, Launch at Login and preferences to it.
- The version isn't stored in the repo. It comes from the release tag (`scripts/version.sh` reads the last one), and `build-app.sh` writes it into `Info.plist`. Don't add a version anywhere else.
- Sign releases with the same certificate every time (the `SIGNING_CERT_P12` secret). A new certificate, or ad hoc signing, makes macOS forget the app's permissions on update.
- To change the app icon, edit `packaging/icon.svg` or the tile colours at the top of `scripts/make-icon.swift`, and rebuild. Never commit a generated `.icns`.
- After a change to the app, run `scripts/install.sh` so the user can try the real bundle.
- `swift run Hogs` runs without a bundle, so notifications and Launch at Login don't work there. Check those in the installed app.
- A process stays a hog until it drops more than 20 points below the Busy at least setting. That stay-busy threshold is derived from the busy one, not a setting of its own.
- The pig is the filled `pig` icon from Tabler Icons (MIT), credited in the README. It's both `packaging/icon.svg` and the SVG inside `PigIcon`.

## Conventions

- Conventional Commits with Title-Case scopes: `feat(Engine): …`. The body explains why.
- Tests ship in the same commit as the change. Pure logic is tested; the UI or host shell stays thin.
- A `feat`, `fix` or `perf` commit that someone using Hogs would notice adds a line under `## [Unreleased]` in `CHANGELOG.md`, in the same commit, written for them, not as a code summary.
- This repo is public. Keep real names, logins, paths and work data out of code, fixtures, docs, the changelog and commits.

## Releasing

Releases happen only when asked. Never bump, tag or publish on your own.

`scripts/release` works out the bump from commits since the last tag, finalizes the changelog, commits `chore(Release): X.Y.Z`, tags `vX.Y.Z` and pushes. The tag triggers `.github/workflows/release.yml`.
