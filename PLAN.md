# Crosswords — Plan

Native SwiftUI crossword solver for **iPadOS and macOS** (one multiplatform target, not Catalyst).

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Formats | `.puz` (Across Lite), `.ipuz` (JSON), `.jpz` (Crossword Compiler XML, plain or zipped) |
| Puzzle storage | A user-picked iCloud Drive folder, remembered per device via security-scoped bookmark (works with a free Apple team) |
| Solve-state sync | Progress is written **into the puzzle file** itself; iCloud Drive syncs the file |
| On-screen input | Custom crossword keyboard on iPad, auto-hidden when a hardware keyboard is attached |
| Rebus | `Esc` / `Insert` / on-screen **Rebus** key opens multi-letter entry on the cell; `Enter` (or `Esc`) commits |
| Extras | Pencil mode, skip-filled-squares (toggle) |
| Signing | Free/personal team: no iCloud entitlement; set your team in Xcode before running on a device |

## Where progress is stored in each format

| Format | Entries | Rebus entries | Marks (incorrect / revealed / pencil) |
|---|---|---|---|
| `.puz` | player-state grid | `RUSR` section | `GEXT` flags: `0x10` prev-incorrect, `0x20` incorrect, `0x40` revealed, `0x08` pencil (app-specific), `0x80` circle preserved |
| `.ipuz` | standard `saved` grid | `saved` grid | extension key `com.irwando.crosswords:marks` |
| `.jpz` | `solve-state` cell attribute | `solve-state` | `solve-status="revealed"` + app attribute `xw-marks` |

Checksums in `.puz` are recomputed on save. Scrambled `.puz` files are unlocked automatically
by brute-forcing the 4-digit key against the stored scramble checksum (solution kept in memory only).

## Architecture

```
Packages/CrosswordKit/            Swift package, fully unit-tested (`swift test`)
  CrosswordCore/                  Puzzle model, grid index, SolveSession (pure value-type engine),
                                  publication-date parsing for library sorting
  PuzzleFormats/                  PUZ / IPUZ / JPZ readers + writers, checksums, unscrambler, mini XML tree, zip
App/                              SwiftUI app (iPad + Mac)
  Library/                        folder bookmark, file listing, progress summaries, sort/filter/search
  Storage/                        NSFileCoordinator IO, NSFilePresenter change detection + merge,
                                  debug-only LocalDefaults.plist loader
  Puzzle/                         grid canvas, clue bar, clue lists, wide/tall layouts, key handling
  Commands/                       menu-bar commands (File: folder actions; Puzzle: check/reveal/pencil)
  Settings/                       theme, fonts, clue placement, highlighting (AppStorage + environment)
  Theme/                          palette and highlight color sets (light/dark)
  Keyboard/                       on-screen crossword keyboard
```

### Sync & conflicts
- Every edit marks cells dirty; saves are debounced (~1 s) and also happen on background/close.
- Reads and writes go through `NSFileCoordinator`; an `NSFilePresenter` watches the open file.
- When another device's change lands, the file is re-read and merged: cells edited locally since the
  last save keep the local value, all other cells take the remote value.

### Solving behaviour
- Click/tap a cell to select; tap the selected cell again to toggle direction.
- Arrows move (a perpendicular arrow first switches direction), Tab / Shift-Tab = next/prev clue,
  Space toggles direction, Delete/Backspace clears and moves back.
- Typing advances within the word; at the end of a word jumps to the next unfinished clue.
  With *skip filled* on, the cursor skips over already-filled squares.
- Check square / word / puzzle marks wrong entries; Reveal square / word / puzzle fills and marks them.
  Revealed squares are locked. Clear word / clear puzzle also available.

## Milestones
1. Package: model + PUZ reader/writer (validated against `puzpy`), unscrambler — tests.
2. IPUZ + JPZ (XML tree, zip) readers/writers — tests.
3. SolveSession engine (navigation, entry, rebus, pencil, check/reveal, merge) — tests.
4. App shell: XcodeGen project, folder picker + bookmark, library list.
5. Puzzle screen: canvas grid, clues, toolbar/menus, hardware keys, on-screen keyboard.
6. Storage: coordinated IO, debounced save, file presenter merge.
7. Build both platforms, smoke-test on Mac + iPad simulator, screenshots.
