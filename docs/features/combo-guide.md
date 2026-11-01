# Combo guide

Added in Round 19 (`133ec7d`). The commit `e0bd2e4` cut the glyphs down to one control set.

## What it does

While a combo string is going, a short stack of rows appears to the right of
the hero. It flips to the left near the screen edge. Each row is one input
that continues the string.

```
 (LMB) Hurl        > (RMB) Ground Breaker
 (RMB) Launcher    > (RMB) Launcher
 (SPACE)(LMB) Dash Stab > (RMB) Launcher
```

Each row has three parts:

- **The button.** A pill-shaped key showing LMB (light), RMB (heavy) or SPACE (dash). Its rim takes the input's path colour from `Upgrades.PATHS`, the same colour as that button's powers (see [powers.md](powers.md)). The dash row also carries a small LMB key, because a dash only becomes a Dash Stab when light follows it.
- **The move that press starts.** The text takes the combo tier's colour from `player.COMBO_TIER_COLORS`. Moves that aren't named combos (L1, L2, H) are pale grey. Ultimates (SKY, RUSH and the AF finisher) use the element's colour and glow on a pulse.
- **The follow-up hint.** After a `>`, in smaller type: the best named combo one more press past that move, with its button.

**Timing feedback**
- Before the current move's cancel point, the rows are dimmed (`lit` 0.78), and a ring around each main key fills as the move plays.
- Once a press would be accepted, the rows go to full brightness and the keys pop and pulse. "Accepted" means the press falls inside `player.input_buffer` of the cancel point.
- While heavy is held, a single row reads `HOLD Charged Slam`, and its ring shows how full the charge is. It becomes `RELEASE Charged Slam` when the charge is full.

**Press feedback**
- Pressing a button flashes its row and sends a ring out from its key.
- This fires from `_input`, on the same frame as the press, before the player's physics tick starts the move.

**Settings and visibility**
- The guide can be turned off in Settings → "Combo guide". This is `Game.combo_guide`, saved in `settings.cfg` under `[video] combo_guide`.
- It is hidden in neutral, during an ultimate (`State.ULT`), during the AF finisher, while hurt or dead, and while the game is paused.

## Files

| File | Role |
|---|---|
| `scripts/player.gd` `route()` | **The only routing function.** It decides which move a "light" or "heavy" press starts from a given state. `_next_move()` is a thin wrapper that passes the live state. |
| `scripts/player.gd` `chain_after()` | The light-chain index after a move starts. `_start_attack()` uses it, and the guide's one-press lookahead does too. |
| `scripts/player.gd` `combo_options()` | Builds the guide's rows from the live state. Returns `[]` when there's nothing to show. |
| `scripts/player.gd` `_option()` | Builds one row, including the `next` lookahead. |
| `scripts/player.gd` `combo_window()` | Timing for the rings and the ready state: `{progress, ready, dash}`. |
| `scripts/player.gd` `guide_name()`, `MOVE_NAMES` | Display names. Combos come from `combo_name()`, which gives element-specific ultimate and finisher names. Plain moves come from `MOVE_NAMES`. |
| `scripts/combo_guide.gd` | The `Control` that draws the guide. It has no child nodes; everything is drawn in `_draw()`. |
| `scripts/hud.gd` | Creates the guide (`hud.combo_guide`) under the HUD root and sets `combo_guide.player` in `bind_player()`. |
| `scripts/game.gd` | Holds the `combo_guide` setting, `toggle_combo_guide()`, `guide_label()`, and its load/save. |
| `scripts/menu_screen.gd` | The Settings row (index 4; "Reset hints" moved to 5). |
| `scripts/main.gd` | Autotest support: the `guide=` stat (`combo_guide.shown`) and the `autotest_guide.png` screenshot. |
| `tests/guide_check.gd` | Checks every row against the real routing and renders `guide_sheet.png`. |

## How it works

Each render frame (`combo_guide._process`):

1. The guide works out its own real-time `dt` from `Time.get_ticks_usec()`, so hitstop (`Engine.time_scale` near 0.03) and the ultimates' slow motion don't freeze its animations.
2. It calls `player.combo_options()`. The player's state machine runs in `_physics_process`, so the rows always describe the state as of the last physics tick. They change on the frame a move starts.
3. It builds a signature from the rows (`kind:id:next_id`). When the signature changes, `_swap_t` resets, and the rows slide in from the hero's side over `SWAP_TIME`, staggered by `SWAP_STAGGER` per row.
4. `_vis` fades in over `FADE_IN` and out over `FADE_OUT`. While fading out, the last rows are kept so they can fade instead of vanishing.
5. `queue_redraw()`.

In `_draw()`:

1. The hero's chest (`CHEST` m above the feet) is projected to the screen with `camera.unproject_position`. The rows are centred vertically on that point and offset `SIDE_GAP` px to the side. They flip to the left side within `EDGE` px of the right edge, with an 80 px gap before flipping back so they don't flicker. They are also clamped to stay below the top HUD band.
2. `player.combo_window()` is read once. When `ready` turns true, `_ready_t` starts the key pop.
3. Each row is measured left to right into `parts`, then drawn mirrored if the guide has flipped. The main key's centre is stored in `_glyph_at[i]`, so a press flash can find it.

How the rows are built (`combo_options`):

- **"Live" states:** `ATTACK`; `DASH` or `_post_dash_t > 0` (counted as "dashing"); `CHARGE`; and `MOVE` while `_chain_i > 0`. The last one is the short window after a light attack ends, before `_chain_reset_t` clears the chain.
- **Light and heavy rows:** `route(kind, _move_id, attacking, _chain_i, dashing, awakened)`. A heavy that routes to the neutral spin `H` is left out, because it isn't a continuation.
- **Dash row:** only while attacking and not already dashing. It always shows `DL` (dash, then light). It dims when `combo_window().dash` is false, which happens while the dash is on cooldown or before the move's first hit or 20% mark.
- **Charging:** a single `hold` row for `CH`.
- **The pause combo:** a press while L2 is still playing (even past its cancel point) is Triple Chop; Flurry needs L2 to finish, then a light press within the chain's grace (`_chain_reset_t`, 0.35s). The guide shows Flurry only in that gap, since the lookahead assumes the next press comes mid-move.
- **Lookahead (`_option`):** for any row below tier 3, call `route(k, id, true, chain_after(id), false, awakened)` for heavy and then light, and keep the highest-tier named combo. Heavy wins ties. `CH` is never offered as a follow-up, because it needs neutral.

Routing rules in `route()`, checked in order:

| Press | Condition | Move |
|---|---|---|
| light | `post_dash` | `DL` |
| light | not attacking, from `L2`, `chain == 2` (L2 finished, chain still live) | `LPL` (Flurry: the pause combo) |
| light | otherwise | `LIGHT_CHAIN[chain]`: L1 → L2 → L3 → L1 |
| heavy | `post_dash`, not attacking | `DH` (Cyclone) |
| heavy | Awakened, attacking, from `L3` / `LH` / `DL` | `AF` / `SKY` / `RUSH` |
| heavy | attacking from `LH` | `LHH` (Spike) |
| heavy | attacking from `L2`, or not attacking with `chain == 2` | `LLH` |
| heavy | attacking (from anything but `H`), or `chain > 0` | `LH` |
| heavy | otherwise | `H` (or `CH` if held, handled in `_state_move` / `_state_charge`) |

## Invariants

- **One routing function.** The moves (`_next_move`), the guide (`combo_options`, `_option`) and `tests/guide_check.gd` all go through `route()` and `chain_after()`. Never add a second copy of the routing rules anywhere. If the guide and the game ever disagree, the guide is lying to the player.
- **Lookahead uses invented states.** `_option` calls `route()` with `attacking = true` and `chain_after(id)`, which is the state the hero will be in once `id` starts. Any new state that affects routing has to be a parameter of `route()`, or the lookahead can't see it.
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
| `PLAIN_COLOR`, `BACK_COLOR` | Colours: plain moves, row backing. Key rims come from `Upgrades.PATHS[kind].color`. |
| `LABELS` | Button text. Only one control set (mouse and keyboard) is shown; the J/K/Shift and gamepad bindings in `Game` still work but appear nowhere in the UI. |
| `lit` in `_draw_row` | Brightness of the rows before the cancel window (0.78). |
| `player.input_buffer` | Also sets when the rows turn "ready". |
| `player.MOVE_NAMES`, `COMBOS`, `COMBO_TIER_COLORS` | Names and colours. |

## Extending

- **New named combo on the existing inputs:**
  1. Add the move to `MOVES` and `COMBOS` (name, input, tier).
  2. Add its rule to `route()`, and update `chain_after()` if it affects the light chain.
  3. Nothing in the guide needs to change. Run `tests/guide_check.gd`, and add the new move to its `FROM` list if it can be started directly.
- **Non-combo move:** give it a name in `MOVE_NAMES`, or the guide shows its raw id.
- **New input kind** (for example a special button):
  1. Add the action to `ACTIONS` and `LABELS`, and give it a path in `Upgrades.PATHS` (its colour).
  2. Add a row for it in `combo_options()`, and add it to the lookahead loop in `_option()`.
  3. Extend `route()` to accept the new kind.
- **Gamepad glyphs again:** an earlier version (`133ec7d`) tracked the last-used device in `_input` and kept a separate label set for each device. Zak asked for a single control set, so that version was removed. Restore it from that commit if it's wanted again.
- **Hiding the guide for more states:** add the condition to the `live` check in `combo_options()`, not to the guide. That keeps the rule in one place and makes it testable.

## Testing

- `godot --headless --path . -s tests/guide_check.gd` runs from every move in `FROM`, both resting and Awakened, and checks two things:
  1. Each row's move equals what `_next_move()` returns for that press (dash rows equal `DL`).
  2. Starting that move and pressing the hinted button gives the hinted combo.

  It also checks the post-dash rows, that neutral shows no rows, and the charge row. It prints `[guide] PASS` or `[guide] FAIL ...`.
- The same command without `--headless` also renders six states into `user://guide_sheet.png`: L1, L2, Awakened earth L3 with an early ring, Awakened earth LH, post-dash water, and charging. Look at it after any visual change.
- The autotest prints `guide=N`, the number of times the guide appeared, and saves `autotest_guide.png` the first time three rows are fully visible and ready.

## Gotchas / open questions

- The autotest bot presses buttons with `Input.action_press`, which generates no `InputEvent`, so bot presses never flash rows. `_on_press(kind)` can be called directly if a test needs the flash.
- `_box` is a single `StyleBoxFlat` reused for every pill. This works because `draw_style_box` issues its draw commands immediately. Don't cache draw commands that depend on it.
- `combo_options()` treats `State.DASH` as "dashing" so the Dash Stab row shows during the dash itself. `route()` only receives `post_dash`, which is set when the dash ends; any buffered light press resolves then.
- Still open in ROADMAP: a feel pass by hand (placement against the fight, and whether the follow-up hint becomes noise once the moves are learned). One option is to fade the hint after a combo has been landed N times.
