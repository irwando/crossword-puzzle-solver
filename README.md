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
   Run `xcodegen generate` again whenever files are added; it rewrites the project, so re-pick the team
   if Xcode asks.
2. Pick **My Mac**, an iPad simulator, or your iPad, and run (⌘R).
3. On first launch, choose your puzzle folder in iCloud Drive (do this once per device).

### On an iPad

1. Connect the iPad by cable and tap **Trust This Computer**.
2. On the iPad, turn on **Settings → Privacy & Security → Developer Mode** (it restarts).
3. Choose the iPad as the run destination in Xcode and press ⌘R.
4. If iPadOS says the developer is untrusted: **Settings → General → VPN & Device Management** → trust your
   profile.

After the first install, *Window → Devices and Simulators → Connect via network* lets you install over Wi-Fi.
With a free Apple team, the app expires after 7 days; run from Xcode again to reinstall.

### In the iPad simulator

Choose an iPad simulator as the run destination. The simulator can read folders on your Mac directly, so
instead of copying puzzles in you can point it at a folder with `CrosswordsFolder` (see
[Debug launch arguments](#debug-launch-arguments-debug-builds-only)), for example in `LocalDefaults.plist`.
Your Mac keyboard acts as a hardware keyboard; toggle it under *I/O → Keyboard*. iCloud sync between
devices needs real hardware.

From the command line:

```sh
xcrun simctl list devices available | grep iPad          # find a simulator
xcrun simctl launch booted com.irwando.crosswords -CrosswordsFolder "/path/to/puzzles"
```

### Finding your iCloud puzzle folder on the Mac

iCloud Drive lives at `~/Library/Mobile Documents/com~apple~CloudDocs`. If *Desktop & Documents Folders*
syncing is on, iCloud Drive › Documents is your normal `~/Documents`, so a folder that shows up as
iCloud Drive › Documents › Puzzles is at `~/Documents/Puzzles`.

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
blue corner and can't be edited. Pencil letters are gray. Hover over any button for a description.

## Library

The filter, sort, and search controls sit at the top of the puzzle list and hide with it.

- **Sort**: by published date (newest or oldest first) or title. The published date comes from the
  `.ipuz` date field, or a date found in the title, file name, or copyright line ("Nov 11, 2026",
  `nyt-2026-11-11.puz`, `Nov1126.puz`, …). Puzzles without one sort by when the file was added.
- **Filter**: by status (not started, in progress, solved) and grid size. The funnel fills in
  while a filter is active.
- **Search** titles, authors, and file names.
- **File menu**: Choose Puzzle Folder… (⌘O), Refresh Library (⌘R), Forget Puzzle Folder. On iPad, open the
  menu bar by swiping down from the top of the screen or holding ⌘ on a hardware keyboard.

## Settings

Open **Settings** with **⌘,** (Mac, or iPad with a keyboard), from the menu bar, or from the puzzle's **⋯** menu:

- **Theme** — System, Light, or Dark.
- **Fonts** — separate fonts for puzzle titles and clues (default SF Pro, the system font), plus clue size.
  Pick from a short list of legible fonts or any font installed on the device.
- **Clue lists** — put Across and Down independently on the left, right, or below the grid. This applies when
  the window is wider than it is tall; in portrait both lists sit below the grid.
- **Highlighting** — turn the current-clue and crossing-clue highlights on or off (in the grid and the clue
  lists), and pick colors for the selected square and the clue highlight. The crossing clue uses a paler shade.
- **Skip filled squares** while typing.

Settings are per device.

## Debug launch arguments (DEBUG builds only)

| Argument | Effect |
|---|---|
| `-CrosswordsFolder <path>` | Use this folder instead of the saved bookmark |
| `-CrosswordsAutoOpen <file>` | Open this puzzle from the folder at launch |
| `-CrosswordsShowKeyboard YES` | Force the on-screen keyboard |
| `-CrosswordsDebugType <letters>` | Type into 3-Down and check it (end-to-end save test) |
| `-CrosswordsShowSettings YES` | Open Settings at launch (iPad) |

To set any of these without editing the Xcode scheme (which `xcodegen generate` resets), copy
`LocalDefaults.example.plist` to `LocalDefaults.plist` at the project root and edit it. That file is
git-ignored and copied into Debug builds only. Its values act as fallbacks, so launch arguments and saved
settings still win. The Mac app is sandboxed, so on Mac a folder path only works inside the app's
container; in the iPad simulator any path on your Mac works.
