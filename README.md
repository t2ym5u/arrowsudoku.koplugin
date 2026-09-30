# arrowsudoku.koplugin

An Arrow Sudoku plugin for [KOReader](https://github.com/koreader/koreader).

## Screenshot

![Screenshot](images/arrow-sudoku.png)

## Rules

Standard Sudoku rules (fill 1–9; no repeats in rows, columns, or 3×3 boxes) plus **arrow constraints**: the digits along each arrow must sum to the value in the arrow's circle. Digits may repeat on an arrow.

## Features

- **Four difficulty levels** — Easy, Medium, Hard and Expert, each guaranteeing the grid is solvable by pure deduction with no guessing
- **Arrow highlighting** — tap a cell to highlight its arrow(s)
- **Note mode** — pencil in candidate digits
- **Check** — highlights incorrect cells and arrow sums
- **Hint** — reveals the next deduction in three taps: where to look, which technique and digit, then the value itself
- **Reveal solution** — shows the full solution
- **Undo** — step back through your moves
- **Auto-save** — game state saved and restored on next launch

## Installation

1. Download `arrowsudoku.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory.
3. Restart KOReader.
4. Open the menu → **Tools** → **Arrow Sudoku**.

## Controls

| Action | How |
|--------|-----|
| Select a cell | Tap it |
| Enter a digit | Tap the digit button |
| Erase a cell | Tap **Erase** |
| Toggle note mode | Tap **Note: Off / On** |
| Undo last move | Tap **Undo** |
| Check progress | Tap **Check** |
| Get a hint | Tap **Hint** (tap again to go deeper) |
| New game | Tap **New game** |
| Change difficulty | Tap **Diff** |
| Show rules | Tap **Rules** |

## License

GPL-3.0 — see [LICENSE](LICENSE).
