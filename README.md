<img src="packaging/icon.png" width="128" height="128" alt="">

# Hogs

A macOS menu bar app that flags processes that have kept a CPU core busy for a long time.

The pig sits quietly in your menu bar. When a process has used at least 80% of a core for 30 minutes (and hasn't dropped more than 20 points below that since), the pig turns pink, shows how many hogs it found, and sends a notification.

Each hog in the menu shows its command, CPU use, how long it's been hot, and its parent processes, with options to quit or force quit it, copy its PID, ignore it until it exits, or always ignore processes with that name.

## Settings

Choose Settings… (⌘,) from the menu. Changes apply right away.

| Setting         | Options                          | Default        |
| --------------- | -------------------------------- | -------------- |
| Busy at least   | 50%, 80%, 100% or 200% of a core | 80% of a core  |
| For at least    | 5, 10, 15 or 30 minutes, 1 hour  | 30 minutes     |
| Launch at Login | on or off                        | off            |

A process that uses several cores can go past 100%. Once a process counts as a hog, it stays one until it drops more than 20 points below the Busy at least setting.

Ignored processes are managed from the menu, under Ignored Processes.

## Install

```sh
brew install --cask starzonmyarmz/tap/hogs
```

Requires macOS 14 or later on Apple silicon.

Hogs is signed with a self-signed certificate, not an Apple Developer ID, so the cask removes the quarantine flag after installing. Installing the zip from a release by hand needs the same:

```sh
xattr -dr com.apple.quarantine /Applications/Hogs.app
```

## Develop

```sh
swift test
swift run Hogs               # runs without a bundle: no notifications or Launch at Login
scripts/build-app.sh         # builds an ad-hoc signed dist/Hogs.app
```

## Releases

Every push to `main` runs the tests, then picks the next version from [conventional commits](https://www.conventionalcommits.org) since the last tag:

| Commit                              | Release |
| ----------------------------------- | ------- |
| `feat!:` or a `BREAKING CHANGE:` footer | major   |
| `feat:`                             | minor   |
| `fix:`, `perf:`, `refactor:`, `revert:` | patch   |
| anything else                       | none    |

The workflow builds and signs `Hogs.app`, publishes a GitHub release with the zip, and updates the cask in [starzonmyarmz/homebrew-tap](https://github.com/starzonmyarmz/homebrew-tap).

It needs these repository secrets:

- `SIGNING_CERT_P12`: the base64-encoded code signing certificate and key
- `SIGNING_CERT_PASSWORD`: the password for that `.p12`
- `TAP_TOKEN`: a fine-grained token with Contents read and write on `homebrew-tap`

Keep signing with the same certificate: macOS ties Launch at Login and notification permissions to it.

## Credits

The pig is the filled `pig` icon from [Tabler Icons](https://tabler.io/icons) (MIT).
