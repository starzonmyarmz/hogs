# Changelog

What changed for people using Hogs, newest first. Code-only work stays in the git history. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [SemVer](https://semver.org).

## [Unreleased]

## [0.3.2] - 2026-11-23

### Changed
- The release download is now named `hogs-X.Y.Z.zip` and comes with a `SHA256SUMS` file.

## [0.3.1] - 2026-11-23

### Fixed
- On macOS 26, menu items line up on the left again. macOS was adding an icon to Quit, which indented every item.

## [0.3.0] - 2026-11-23

### Added
- A Settings window (⌘,) for how busy a process must be and for how long before it counts as a hog, and for Launch at Login. Changes apply right away.

### Changed
- How far a hog's CPU use can drop before it stops counting follows the Busy at least setting: 20 points below it.

## [0.2.0] - 2026-11-23

### Added
- How long a process must stay busy can be changed with `defaults write com.iamdanielmarino.hogs hotForMinutes`.

### Changed
- The pig turns hot pink when it finds hogs, and is a little larger. The app icon is pink to match.

## [0.1.1] - 2026-11-23

### Fixed
- Installing with Homebrew no longer prints deprecation warnings.

## [0.1.0] - 2026-11-23

### Added
- Hogs, a menu bar pig that flags processes that have kept a CPU core busy for a long time, with a notification and a count in the menu bar.
- Each hog's command, CPU use, time spent hot and parent processes, with options to quit or force quit it, copy its PID, or ignore it.
