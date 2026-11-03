<img src="assets/icon.png" alt="ButtonBag icon" width="96" align="right">

# ButtonBag

A minimap tidy-up addon for **Azeroth Survivors** (WoW 1.12.1 client, benilla).

Every addon adds its own button around the minimap, and they pile up fast. ButtonBag gathers them
into one bag button. Click the bag and a panel drops down holding all of them; click a button inside
it as usual.

## Features

- **One button instead of many**: addon buttons around the minimap move into the bag. The game's
  own minimap buttons stay where they are.
- **Works with any addon**: buttons are found by what they are (named minimap buttons that can be
  dragged, or whose name says they're a minimap button), not by a list of addons. Buttons made a
  little late are picked up too, and *Look again* checks on demand.
- **Choose what goes in**: the settings list every button found. Untick one to keep it on the
  minimap.
- **Your order**: A to Z, or *My order*, where Up and Down in the list move each button.
- **Open your way**: on a click or just by pointing at the bag, toward the middle of the screen or
  always down, up, left or right.
- **Bag size and shape**: Small, Normal, Large or Huge buttons, 1 to 6 per row.
- **Folds itself up**: after you left-click a button in it, when the mouse has been away for a
  moment (0.5 to 5 seconds, your choice), or on Escape. Each can be turned off.
- **Nothing is lost**: an addon can still show, hide and click its button while it's in the bag.
  Turn *Collect buttons* off and every button goes back exactly where it was.
- Follows a square minimap, and has a settings window drawn to match the game's own menus.

## Install

1. Download `ButtonBag-vX.Y.Z.zip` from [Releases](../../releases/latest).
2. Put the `ButtonBag` folder into `benilla-config/AddOns/`.
3. Restart the game.

Or add this repository in [SurvivorsForge](https://github.com/Rezondes/SurvivorsForge) (*Add repo*)
to install and update it from there.

## Use

Left-click the bag on the minimap to open it, right-click for the settings, drag to move it around
the edge of the minimap.

| Command | Does |
|---|---|
| `/bbag` | open or close the settings |
| `/bbag open` | open or close the bag |
| `/bbag scan` | look for buttons again |

## License

MIT. Azeroth Survivors is a fan game by Aethus. This addon is not affiliated with Blizzard
Entertainment.
