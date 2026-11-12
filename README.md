# Crosswords

A native crossword solver for iPad and Mac. Opens `.puz`, `.ipuz`, and `.jpz` (plain or zipped) files from a
folder in iCloud Drive and saves your progress back into each puzzle file, so it syncs between devices.

See [PLAN.md](PLAN.md) for design decisions and file-format details.

## Build & run

Requires Xcode 27+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate          # creates Crosswords.xcodeproj from project.yml
open Crosswords.xcodeproj
```

1. Select the **Crosswords** target → *Signing & Capabilities* → choose your (personal) team.
2. Pick **My Mac** or your iPad and run.
   With a free Apple team, apps installed on an iPad expire after 7 days; just run from Xcode again.
3. On first launch, choose your puzzle folder in iCloud Drive (do this once per device).

Package tests (parsers, writers, solve engine):

```sh
cd Packages/CrosswordKit && swift test
```

## Controls

| Action | Keyboard | Touch / mouse |
|---|---|---|
| Select square / toggle direction | Space | Tap a square; tap it again |
| Move | Arrow keys (a perpendicular arrow switches direction first) | |
| Next / previous clue | Tab / Shift-Tab, Return | Chevrons in the clue bar or keyboard |
| Erase | Delete (back), Forward-Delete (in place) | ⌫ key |
| Rebus (several letters in one square) | Esc or Insert, type, then Return / Esc | **Rebus** key, then **Done** |
| Pencil mode | ⇧⌘P | Pencil button |
| Check square / word / puzzle | ⌥⌘1 / ⌥⌘2 / ⌥⌘3 | Check menu (✓) |
| Reveal square / word / puzzle | ⌃⌥⌘1 / ⌃⌥⌘2 / ⌃⌥⌘3 | Reveal menu (eye) |

Wrong squares get a red slash (and a red corner flag after you fix them). Revealed squares are blue with a
blue corner and can't be edited. Pencil letters are gray. Turn *Skip Filled Squares* on or off in the **⋯** menu
(or in Settings on Mac).

## Debug launch arguments (DEBUG builds only)

| Argument | Effect |
|---|---|
| `-CrosswordsFolder <path>` | Use this folder instead of the saved bookmark |
| `-CrosswordsAutoOpen <file>` | Open this puzzle from the folder at launch |
| `-CrosswordsShowKeyboard YES` | Force the on-screen keyboard |
| `-CrosswordsDebugType <letters>` | Type into 3-Down and check it (end-to-end save test) |
