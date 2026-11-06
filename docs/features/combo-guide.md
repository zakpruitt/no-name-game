# Combo guide

Added in Round 19 (`133ec7d`). The commit `e0bd2e4` cut the glyphs down to one control set.

## What it does

While a combo string is going, a short stack of rows appears to the right of
the hero. It flips to the left near the screen edge. Each row is one input
that continues the string.

```
 (LMB) Hurl          > (RMB) Frost Spear
 (RMB) Updraft Lash  > (RMB) Live Wire
 (SPACE)(LMB) Dash Stab > (RMB) Harpoon
```

Each row has three parts:

- **The button.** A pill-shaped key showing LMB (light), RMB (heavy) or SPACE (dash). Its rim takes the input's colour from `combo_guide.KEY_COLORS`. The dash row also carries a small LMB key, because a dash only becomes a Dash Stab when light follows it.
- **The move that press starts.** The text takes the combo tier's colour from `player.COMBO_TIER_COLORS`. Moves that aren't named combos (L1, L2, AL1, IJ) are pale grey.
- **The follow-up hint.** After a `>`, in smaller type: the best named combo one more press past that move, with its button.

**The look** (round 33, part 3, sleek HUD; `scripts/hud_ink.gd`): each row sits on a see-through pill
(`BACK_COLOR` at 0.5) with halftone dots in the row's colour, densest at its key and fading across
(`ROW_DOTS`), inside a 1 px line in that colour (`ROW_LINE`), the effects' thin-ink and halftone language.
Text keeps the plain font with a thin ink outline (`hud_ink.outline()`: size / 9, at least 3 px); the press
ring is 1-3 px (was 1-4). The breaker prompt and the combo counter use the same helpers.

**Timing feedback**
- Before the current move's cancel point, the rows are dimmed (`lit` 0.78), and a ring around each main key fills as the move plays.
- Once a press would be accepted, the rows go to full brightness and the keys pop and pulse. "Accepted" means the press falls inside `player.input_buffer` of the cancel point.
- While heavy is held, a single row reads `HOLD Overwhelm`, and its ring shows how full the charge is. It becomes `RELEASE Overwhelm` when the charge is full.

**Press feedback**
- Pressing a button flashes its row and sends a ring out from its key.
- This fires from `_input`, on the same frame as the press, before the player's physics tick starts the move.

**Settings and visibility**
- The guide can be turned off in Settings → "Combo guide". This is `Game.combo_guide`, saved in `settings.cfg` under `[video] combo_guide`.
- It is hidden in neutral, in a breaker's leap (the breaker prompt takes over), while hurt or dead, and while the game is paused.

## Files

| File | Role |
|---|---|
| `scripts/hero_moves.gd` `void_route()` | **The only routing function** (`hero_moves.void_route()` forwards to it, so `PLAYER.void_route` still works on the script). It decides which move a "light" or "heavy" press starts from a given state (the tables are `VOID_ELEMENT.LIGHT_AFTER`, `AFTER`, `DASH_MOVE`). `routed()` adds the vault (`VOID_ELEMENT.vaults()`: either press is `IJ` while the frost spear stands); `player._next_move()` passes it the live state. |
| `scripts/hero_moves.gd` `chain_after()` | The light-chain index after a move starts. `player._start_attack()` uses it, and the guide's one-press lookahead does too. |
| `scripts/hero_moves.gd` `combo_options()` | Builds the guide's rows from the live state (`hero_moves.combo_options()` forwards). Returns `[]` when there's nothing to show. |
| `scripts/hero_moves.gd` `option()` | Builds one row, including the `next` lookahead. |
| `scripts/hero_input.gd` `combo_window()` | Timing for the rings and the ready state: `{progress, ready, dash}` (`hero_input.combo_window()` forwards). |
| `scripts/hero_moves.gd` `guide_name()`, `MOVE_NAMES` | Display names. Combos come from `COMBOS[id].name`. Plain moves come from `MOVE_NAMES`. |
| `scripts/combo_guide.gd` | The `Control` that draws the guide. It has no child nodes; everything is drawn in `_draw()`. |
| `scripts/hud.gd` | Creates the guide (`hud.combo_guide`) under the HUD root and sets `combo_guide.player` in `bind_player()`. |
| `scripts/game.gd` | Holds the `combo_guide` setting, `toggle_combo_guide()`, `guide_label()`, and its load/save. |
| `scripts/menu_screen.gd` | The Settings row (index 4; "Reset hints" moved to 5). |
| `scripts/main.gd` | Autotest support: the `guide=` stat (`combo_guide.shown`) and the `autotest_guide.png` screenshot. |
| `tests/guide_check.gd` | Checks every row against the real routing and renders `guide_sheet.png`. |

## How it works

Each render frame (`combo_guide._process`):

1. The guide works out its own real-time `dt` from `Time.get_ticks_usec()`, so hitstop (`Engine.time_scale` near 0.03) and the breakers' slow motion don't freeze its animations.
2. It calls `hero_moves.combo_options()`. The player's state machine runs in `_physics_process`, so the rows always describe the state as of the last physics tick. They change on the frame a move starts.
3. It builds a signature from the rows (`kind:id:next_id`). When the signature changes, `_swap_t` resets, and the rows slide in from the hero's side over `SWAP_TIME`, staggered by `SWAP_STAGGER` per row.
4. `_vis` fades in over `FADE_IN` and out over `FADE_OUT`. While fading out, the last rows are kept so they can fade instead of vanishing.
5. `queue_redraw()`.

In `_draw()`:

1. The hero's chest (`CHEST` m above the feet) is projected to the screen with `camera.unproject_position`. The rows are centred vertically on that point and offset `SIDE_GAP` px to the side. They go on the side away from the foes near him (`_pile_side`, `PILE_SLACK` hysteresis), unless that side is within `EDGE` px of the screen edge; an edge flip holds for `EDGE_SLACK` 80 px so it doesn't flicker (`guide_side()`, checked in `guide_check`). Until feel audit 3 the right edge's slack branch sent every left choice back to the right, so the rows sat on the pile. They are also clamped to stay below the top HUD band.
2. `hero_input.combo_window()` is read once. When `ready` turns true, `_ready_t` starts the key pop.
3. Each row is measured left to right into `parts`, then drawn mirrored if the guide has flipped. The main key's centre is stored in `_glyph_at[i]`, so a press flash can find it.

How the rows are built (`combo_options`):

- **"Live" states:** `ATTACK`; `DASH` or `_post_dash_t > 0` (counted as "dashing"); `CHARGE`; and `MOVE` while `_chain_i > 0`. The last one is the short window after a light attack ends, before `_chain_reset_t` clears the chain.
- **Light and heavy rows:** `_routed(kind, _move_id, attacking, _chain_i, dashing)`. A heavy that routes to the neutral grab `GR` is left out, because it isn't a continuation.
- **Dash row:** only while attacking and not already dashing. It shows `dash_light()`: `DL` (dash, then light). It dims when `combo_window().dash` is false, which happens while the dash is on cooldown or before the move's first hit or 20% mark.
- **Charging:** a single `hold` row for `OW` (Overwhelm).
- **The pause hint:** while attacking, each row also asks `_routed()` with `attacking = false` (the press after the move has finished, chain still live); when that gives a different named combo the row adds "or pause: ..." (`pause` in `combo_options()`, `PAUSE_TEXT`).
- **Lookahead (`_option`):** for any row below tier 3, call `_routed(k, id, true, chain_after(id), false)` for heavy and then light, and keep the highest-tier named combo. Heavy wins ties. `OW` is never offered as a follow-up, because it needs neutral.

Routing rules in `void_route()`, checked in order:

| Press | Condition | Move |
|---|---|---|
| either | the frost spear stands (not off a dash, not from `IS`, not mid-`IJ`) | `IJ` (Vault; `_routed()`) |
| light | attacking, from a move in `VOID_ELEMENT.LIGHT_AFTER` | `EC` → `AL1`, `GR` → `VR`, `IP` → `IJ` |
| light | `post_dash` | `DL` |
| light | otherwise | `LIGHT_CHAIN[chain]`: L1 → L2 → L3 → L1 |
| heavy | `post_dash`, not attacking | `VOID_ELEMENT.DASH_MOVE` (`TW`, Tow Line) |
| heavy | attacking | `VOID_ELEMENT.AFTER[from]` (the weapon's element move, see [void-element.md](void-element.md)), else `GR` |
| heavy | not attacking | `GR` (the grab; held, `OW`, handled in `_state_move` / `_state_charge`) |

## Invariants

- **One routing function.** The moves (`_next_move`), the guide (`combo_options`, `_option`) and `tests/guide_check.gd` all go through `void_route()` / `_routed()` and `chain_after()`. Never add a second copy of the routing rules anywhere. If the guide and the game ever disagree, the guide is lying to the player.
- **Lookahead uses invented states.** `_option` calls `_routed()` with `attacking = true` and `chain_after(id)`, which is the state the hero will be in once `id` starts. Any new state that affects routing has to be a parameter of `void_route()`, or the lookahead can't see it.
- **The guide only reads.** `combo_guide.gd` never changes player state. Its only input hook is the cosmetic press flash.
- **Real time only.** Anything animated in the guide must use the guide's own `dt`, never `_delta` or a tween tied to the tree's time scale.

## Tuning (in `combo_guide.gd` unless noted)

| Constant | Effect |
|---|---|
| `FADE_IN` / `FADE_OUT` | How fast the whole guide appears and disappears (s). |
| `SWAP_TIME` / `SWAP_STAGGER` | Row slide-in when the options change (s). |
| `FLASH_TIME` | Length of the press flash (s). |
| `ROW_H`, `ROW_GAP`, `GLYPH_H`, `SMALL_GLYPH_H` | Size of the layout (px, in the 1600x900 viewport space). |
| `NAME_SIZE`, `NEXT_SIZE`, `KEY_SIZE` | Font sizes. |
| `SIDE_GAP`, `CHEST`, `EDGE` | Where the rows sit next to the hero, and when they flip. |
| `PLAIN_COLOR`, `BACK_COLOR` | Colours: plain moves, row backing. Key rims are `KEY_COLORS`. |
| `ROW_DOTS`, `ROW_LINE` | Alpha of the backing's halftone dots and of its line, in the row's colour. |
| `LABELS` | Button text. Only one control set (mouse and keyboard) is shown; the J/K/Shift and gamepad bindings in `Game` still work but appear nowhere in the UI. |
| `lit` in `_draw_row` | Brightness of the rows before the cancel window (0.78). |
| `player.input_buffer` | Also sets when the rows turn "ready". |
| `player.MOVE_NAMES`, `COMBOS`, `COMBO_TIER_COLORS` | Names and colours. |

## Extending

- **New named combo on the existing inputs:**
  1. Add the move to `MOVES` and `COMBOS` (name, input, tier), and its row to `scripts/move_list.gd`.
  2. Add its rule to `void_route()` (or the `VOID_ELEMENT` tables it reads), and update `chain_after()` if it affects the light chain.
  3. Nothing in the guide needs to change. Run `tests/guide_check.gd`, and add the new move to its `FROM` list if it can be started directly.
- **Non-combo move:** give it a name in `MOVE_NAMES`, or the guide shows its raw id.
- **New input kind** (for example a special button):
  1. Add the action to `ACTIONS` and `LABELS`, and give it a colour in `KEY_COLORS`.
  2. Add a row for it in `combo_options()`, and add it to the lookahead loop in `_option()`.
  3. Extend `void_route()` to accept the new kind.
- **Gamepad glyphs again:** an earlier version (`133ec7d`) tracked the last-used device in `_input` and kept a separate label set for each device. Zak asked for a single control set, so that version was removed. Restore it from that commit if it's wanted again.
- **Hiding the guide for more states:** add the condition to the `live` check in `combo_options()`, not to the guide. That keeps the rule in one place and makes it testable.

## Testing

- `godot --headless --path . -s tests/guide_check.gd` runs from every move in `FROM`, both resting and Awakened, and checks two things:
  1. Each row's move equals what `_next_move()` returns for that press (dash rows equal `dash_light()`).
  2. Starting that move and pressing the hinted button gives the hinted combo.

  It also checks the post-dash rows, that neutral shows no rows, and the charge row. It prints `[guide] PASS` or `[guide] FAIL ...`.
- The same command without `--headless` also renders six states into `user://guide_sheet.png`: L1, L2, Awakened L3 with an early ring, Awakened EC, post-dash, and charging. Look at it after any visual change.
- The autotest prints `guide=N`, the number of times the guide appeared, and saves `autotest_guide.png` the first time three rows are fully visible and ready.

## Gotchas / open questions

- The autotest bot presses buttons with `Input.action_press`, which generates no `InputEvent`, so bot presses never flash rows. `_on_press(kind)` can be called directly if a test needs the flash.
- `_box` is a single `StyleBoxFlat` reused for every pill. This works because `draw_style_box` issues its draw commands immediately. Don't cache draw commands that depend on it.
- `combo_options()` treats `State.DASH` as "dashing" so the Dash Stab row shows during the dash itself. `void_route()` only receives `post_dash`, which is set when the dash ends; any buffered light press resolves then.
- Pause MOVES list: draws `scripts/move_list.gd` `SECTIONS`, every input grouped by weapon and element (weapons, storm, ice, magma, dark). Each named combo shows how often it was landed this run. The panel scrolls (wheel, Page Up / Down, right stick). When you add a move, add its row there: `tests/move_list_check.gd` walks every row's input through `void_route()`, and fails if a move or combo is unlisted, `void_route()` reaches a move with no row, or a listed input starts the wrong move.
- Found combos: the first time a named combo lands in a run, `player.combo_found` fires and the HUD hint shows "New combo: Live Wire  (L H H)  ·  5 / 16 found" for `hud.FOUND_HOLD` (skipped while a tutorial hint is up).
- Learned combos: once a combo has been landed `player.GUIDE_LEARNED` (6) times in the run (`combos_landed`), `_option` stops offering it as a follow-up hint. Still open in ROADMAP: a feel pass by hand on placement against the fight.

## Round 34: crossovers

The crossover strings (Rockslide, Fault Line, Steam Burst, Storm Pitch; `void-element.md`) are ordinary
`LIGHT_AFTER` / `AFTER` routes, so the guide shows them with no guide code: off Air Slash the light row is now
Rockslide (it was a plain Slice), off Ice Cube it is Steam Burst, off Tow Line it is Storm Pitch, and off
Rockslide the heavy row is Fault Line with Cataclysm behind it. Black Ice is an `alt` ending, so it shows on the
breaker prompt (both buttons and names), not in the guide.

Second pass: the three-element strings are routes too. Off Ice Cube the heavy row is Hailstorm (it was the
grab) and off Hailstorm the light row is Meltdown with Eruption behind it; off Tow Line the heavy row is Impale and
off Impale the light row is Backdraft with Anvil behind it. With the frost spear standing, presses off Tow Line,
Impale, Backdraft and Storm Pitch no longer turn into the vault (`VOID_ELEMENT.NO_VAULT`), so the guide's rows
off them stay true while the spear is up.

Third pass: the element matrix's payoffs aren't routes (they read a foe's state, `void_element.IMPROV`), so the guide
doesn't show them; the pause MOVES panel has an IMPROVISING section, one text row per cell (`move_list.gd`), whose
inputs name the state and the element ("frozen, then dark") and so never route.

Fourth pass (round 4, finding the mixes): the rows say when a press mixes elements, still only on real routes.

```
 (LMB) storm > magma Rockslide > (RMB) Fault Line
 (RMB) Harpoon + Frozen In
```

- **`mix`** (`hero_moves.mix_of()`): a crossover row (`X*`) names the element change from the move he's in to the one
  it starts, in the matrix's words (`ELEMENT_WORDS`: storm, ice, magma, dark; weapons from `WEAPON_ELEMENT`), drawn
  small in violet before the name (`MIX_SIZE`, `MIX_COLOR`).
- **`pay`** (`hero_moves.pays()`): a row whose base element move would cash in a state on a foe inside that move's own
  hit shape (`void_element.improv_reach()` from where he stands and faces, `improv_state()`) adds "+ <payoff>" in the
  tier-2 colour (`PAY_TEXT`), named from the move list (`move_list.mix_name()`). It is the improvisation rule shown at
  the moment it applies: dash out of a Rockslide and the Harpoon row reads "+ Frozen In". The row signature includes
  it, so the rows slide in again when a payoff comes into reach.
- The pause MOVES panel's IMPROVISING section is now **MIX ELEMENTS**: all 24 state x element cells in plain words
  ("frozen, then dark: Shatter"), the 15 improvised ones and the 9 the moves pay themselves (`own`), each with
  `state` / `el` keys.
- `guide_check._mixing()`: Rockslide's row off Air Slash says "storm > magma", L1's rows carry no tag, and a buried
  foe on Harpoon's line tags Harpoon's row off Dash Stab "+ Frozen In" until he faces away. The windowed sheet's second
  shot is Air Slash (the mix tag on Rockslide; was L2).
