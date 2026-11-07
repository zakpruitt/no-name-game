# The wiki (player field guide)

## What it does

`docs/wiki/` is a static, single-page field guide for players: Home (what Awaken is, controls, breaker windows, the
counter, Awakening, where it is going), the kit grammar (how characters are built and how the game will grow), the
heretic's full card, Characters (the Dragon Prince, paused, with TODOs), Elements & states, and a changelog. It is
published to GitHub Pages at https://zakpruitt.github.io/no-name-game/ by `.github/workflows/wiki.yml` on every push to
`dev` that touches `docs/wiki/`. Open `docs/wiki/index.html` from disk to read it; it needs no server.

Every name, input, word and number on it comes from the code, so it stays in sync when moves change; only the "what
state it leaves" and "best situation" lines are hand-written.

## Files

| File | Contents | Written by |
|---|---|---|
| `docs/wiki/index.html` | The page: prose, styles, and the script that builds every table from the two files below | hand |
| `docs/wiki/data.js` | `window.WIKI`: `KitSlots.GROUPS` / `SLOTS` / both cards, `Kit.UPGRADES`, COMBOS names, `ELEMENT_OF` + `WEAPON_ELEMENT`, `ComicFx.MOVE_WORDS`, `move_list.SECTIONS` (headings resolved, each row's slot tag), `BREAKERS` (name, word, element, damage, `alt`), the window's PERFECT mult, `RULES` + words + `RULE_OWN` / `RULE_SELF`, the upgrade cells, counter.gd and the swinging dummy's numbers, Awakening's, the prince's move names | `tools/wiki_data.gd` (never by hand) |
| `docs/wiki/notes.js` | `window.NOTES`: `moves.<id>` = `{state, best}` for every card fill, route step and upgrade move; `endings.<name>` = the best situation of every breaker ending | hand (strict JSON after the `window.NOTES =` line) |
| `docs/wiki/img/*.jpg` | Ten screenshots, 480-640 px wide, under 60 KB each | by hand, from the game's film tools (below) |
| `tools/wiki.py` | Runs `wiki_data.gd` headless, then lists ids `notes.js` lacks (or has but the game doesn't); exit 1 on a missing note | |
| `tools/wiki_data.gd` | `build()` (static) returns the whole data.js text; run as a SceneTree it writes it | |
| `tests/wiki_check.gd` | Compares `build()` with data.js; `[wiki] PASS/FAIL` with the first differing line. In `agent.sh check` | |

## How it works

- `wiki_data.gd` loads the game's scripts at runtime (after the first frame, so the `Game` autoload exists) and reads
  their constants. `JSON.stringify(..., " ", true)` sorts keys, so the output is the same every run and has no commit
  hash or date: data.js changes only when the code it reads changes.
- The page orders the card by `SLOTS` (an array) rather than by the card's `fill` keys (sorted), and sorts a slot's
  moves by input length (L, L L, L L L).
- Crossover rows show their slot's colour `pair`; other rows the move's element (`ELEMENT_OF`).

## Invariants

- data.js matches the code (`wiki_check`). A lane that changes a move, slot, breaker, word, rule or the counter's numbers
  runs `python tools/wiki.py` and commits data.js with the change.
- `notes.js` covers every card move and every breaker ending (`wiki.py` says which are missing; the page shows an empty
  cell for them).
- Images stay small (under 300 KB each; today all are under 60 KB): crop to the action, jpg quality ~84, 640 px at most.

## Rebuilding

```
python tools/wiki.py                                   # data.js + the notes check, a few seconds
godot --headless --path . -s tests/wiki_check.gd       # [wiki] PASS/FAIL
```

Screenshots (windowed; not while a land is running; `user://` is shared, so copy the frames out at once):

```
godot --path . -s tests/string_film.gd -- --dir=wiki_film --no-awaken   # every bot string, ~4 min
godot --path . -s tests/heretic_shots.gd -- --dir=wiki_hero             # the hero (ready_close.png)
godot --path . -s tests/element_shots.gd -- --only=<id>                 # one move or breaker
```

The current shots and their source frames (in `user://wiki_film/<string>/NNN.png`): `hero` ready_close; `window_two`
L_H_H/021 (Live Wire's hang, the Short Circuit / Grounded chips); `galvanize` spread_H_L_L/032; `harpoon_row`
wall_alt_D_L_H/028; `lava_leash` wall_spread_L_L_L_H_L/034; `counter_parry` counter_D/026; the four breaker families
`end_storm` L_H_H/030 (Grounded), `end_ice` alt_H_L_H/037 (Black Ice), `end_magma` wall_spread_L_L_L_H_L/050
(Hellseam), `end_dark` counter_D/045 (Ricochet). Frame numbers move when a string's timing changes: pick from a contact
sheet of the folder (the `docs/agents.md` lesson). Render check: headless Edge,
`msedge --headless=new --window-size=1280,16000 --screenshot=<png> file:///.../docs/wiki/index.html` (16000 px is its
limit: hide the top sections in a scratch copy to see the rest), and a 390 px iframe wrapper for phone width.

## Gotchas

- A Godot `-s` script can't `preload` scripts that name the `Game` autoload; `wiki_data.gd` `load()`s them inside
  `build()`, which the check calls after a frame.
- git may check data.js out with CRLF; the check compares with `\r\n` folded to `\n`.
- `notes.js`'s header comment contains the text `window.NOTES =`; `wiki.py` parses from the last occurrence.
