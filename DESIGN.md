# Design

How Hogs looks and feels. When this file and your instincts disagree, this file wins. Change it on purpose, in the same commit as the code.

## The look in one line

A quiet pig in the menu bar that turns hot pink when something is hogging the CPU.

## Tokens

Every color, size and space comes from a token. If nothing fits, add a token here before using a new value.

| Token | Value | Used for |
|---|---|---|
| `PigIcon.alertColor` (`HogsAlert`) | `#EC4C8A` light, `#FF6FA8` dark | the pig and hog count when hogs are found |
| `tileTop` → `tileBottom` in `scripts/make-icon.swift` | `#FF7FB4` → `#E33D80` | the app icon tile's gradient |
| menu bar pig | 20 pt | `PigIcon.template()` and `tinted()` |

## Components

- **Menu bar pig:** a template image, so it follows the menu bar's own colour, while nothing is a hog. When there are hogs it's tinted `alertColor` with the count beside it in the same colour.
- **Hog menu item:** the command, CPU use, how long it's been hot and its parent processes, with a submenu to quit, force quit, copy the PID, ignore it until it exits, or always ignore that name.
- **Settings window:** a SwiftUI view in a titled, closable `NSWindow` called "Hogs Settings". Changes apply right away, with no Save button.

## Patterns

- Stay out of the way: no Dock icon, no window at launch, and colour only when something needs attention.
- The pig is the one glyph, the Tabler Icons filled `pig`, in both the menu bar and the app icon.

## Adding something new

1. Look for an existing component or pattern that already does it.
2. Build it from tokens only.
3. Check light and dark, and Reduce Motion if it moves.
4. Retake the screenshot if it shows in one.
5. Record it above.

## Known drift

Existing debt to clean up, not to copy.
