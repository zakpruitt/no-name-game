# Powers: paths, masteries, fusions and icons

Added in Round 20. Builds on the combo-slot upgrades (`Upgrades.ALL`),
levels and synergies from earlier rounds.

## What it does

Every power belongs to a **path**: the button it upgrades. The path's colour
is used for the power everywhere, so a player stacking light attacks is
looking for blue cards.

| Path | Key | Colour | Hooks | Mastery (own 3) |
|---|---|---|---|---|
| Light | LMB | blue | L1, L2, L3, light attacks | light attacks +15% damage |
| Heavy | RMB | gold | Spin, Launcher, Ground Breaker, Charged Slam, heavy kills | heavy attacks +15% damage |
| Dash | SPACE | green | dash, Dash Stab, perfect dodge | dashes recover 40% faster, Dash Stab +25% |
| Awaken | Q | violet | Awakening | Awakening lasts 2s longer |
| Soul | (none) | rose | kills, killing blows, juggles | +20 max HP |

- **Mastery.** Owning `MASTERY_NEED` (3) powers of a path switches its mastery on, with an announcement, a sound and a ring in the path colour. This rewards stacking one colour.
- **Fusions.** These are two-colour cards that hook one path into another (Crescendo: L3 → Heavy, Flicker: Dash → Light, Shockstep: Heavy → Dash, Undying Flame: Awaken + Soul).
  - A fusion is only offered once you own a non-fusion power on both of its paths. When one is eligible, an offer has a `FUSION_CHANCE` (50%) to swap its last card for it.
  - Fusions count toward both paths' masteries. This rewards mixing colours.
- **Synergies** (Storm, Tremor, Ember, Blood, Night, Bone) are unchanged. They're theme tags that cut across paths. They show in teal, and the paths never use teal.

**Where the player sees it**
- **Reward cards** (`reward_screen.gd`):
  - a colour band (split for fusions), key chips and the path name, and the move the power hooks;
  - the icon (with level pips on a level-up), the name, NEW or LEVEL UP;
  - the description with its numbers in bold in the path colour;
  - mastery progress ("HEAVY ■■□ MASTERY", "UNLOCKS LIGHT MASTERY", "LIGHT MASTERY ACTIVE"), synergy completion, and the synergy tags.
  - Cards deal in with a short stagger. Hovering a card makes its icon glow.
- **Pause build view** (`pause_menu._build_powers`): powers grouped by path (fusions last). Each group has a header with the key chip and mastery pips, or the mastery's effect once it's on. Each power gets a row with the icon, name and current text. Active synergies are at the bottom. The view scrolls when the build is long.
- **HUD** (`hud.power_strip`): owned powers as 44px icons with level pips, bottom right, in path order. A new or levelled icon pops in.
- **Run summary**: the icons above the list of power names.
- **Combo guide**: key rims use `Upgrades.PATHS[kind].color`, so LMB is the same blue as the Light powers.

## Files

| File | Role |
|---|---|
| `scripts/upgrades.gd` | Data. Each `ALL` entry has a `path` (and a `fusion` second path). Also `PATHS` (name, key, colour, mastery numbers), `MASTERY_NEED`, `FUSION_CHANCE` and `SLOT_NAMES`. Helpers: `paths_of`, `color`, `can_fuse`, `path_counts`, `masteries`, `mastery_text`, `slot_name`, `icon` (cached), `describe(..., bb)` for BBCode numbers. `roll()` keeps new fusions in a separate pool. |
| `scripts/player.gd` | The effects. `masteries` is kept by `_refresh_masteries()`, which `add_upgrade` and `remove_upgrade` call. `_mastery(path, key)` returns the number, or 0 while the mastery is off. `_awaken_len()` and `_base_anim_mult()`. New powers: `quickblade` (in `_start_attack`), `thousand_cuts` (`_thousand_cuts`, per-enemy `cuts` meta), `slipstream` (`_slipstream`, from `_state_dash`), `eruption` (in `try_awaken`), `razor_gale` (`_razor_gale`, on Flurry's last hit in `_do_hit`), `eye_of_storm` (`_eye_of_storm`, every Cyclone hit), `rebound` (`_rebound`, after `_spike`), `war_chant` (in `_combo_callout`, `_last_combo`). Fusions: `crescendo` (`_crescendo` flag set by a landed L3, used by the next heavy in `_start_attack`), `flicker` (`_effective_move`, uses `_since_dash`), `shockstep` (the dash-cancel in `_state_attack`), `undying_flame` (`_on_enemy_killed`). `power_procs` counts these for the autotest. |
| `scripts/power_icon.gd` | `PowerIcon`, a `Control` drawn in `_draw`: a ring in the path colour (split for fusions), the tinted glyph, level pips and an optional `glow`. `make(id, px, level)`, `chip(path)` (key cap) and `mastery_pips(n)`. |
| `tools/gen_power_icons.py` | The glyphs, one SVG body per id on a 64x64 grid, written to `assets/icons/powers/<id>.svg`. |
| `scripts/reward_screen.gd` | The cards (`_card`). |
| `scripts/pause_menu.gd` | `_build_powers`, `_path_header`, `_power_row`. |
| `scripts/hud.gd` | `power_strip` (an `HFlowContainer`, `reverse_fill` so rows stack upward) and `set_upgrades`. |
| `scripts/run_summary.gd` | The icon row. |
| `scripts/combo_guide.gd` | Key rim colours. |
| `scripts/main.gd` | The autotest line gains `masteries=` and `power_procs=`. |
| `tests/power_check.gd` | Checks and screenshots (see Testing). |

## How it works

1. **Offers.** `Upgrades.roll(owned, count, level_ups_only, rng)` builds a pool of every power below `MAX_LEVEL`.
   - An unowned fusion goes into a separate pool, and only when `can_fuse()` is true.
   - Owned fusions level up through the normal pool.
   - After shuffling, with `FUSION_CHANCE`, the last card is replaced by a random eligible fusion. This uses the run's `rng`, so seeded runs still repeat.
2. **Picking.** `player.add_upgrade(id)` updates the level, then synergies, then `_refresh_masteries()`. A newly reached mastery is announced. The Soul mastery adds max HP (and removing a power that breaks it takes the HP back).
3. **Effects.** Mastery damage is applied in `_effective_move()` when a move starts. The dash mastery applies in `_start_dash()`, and the Awaken mastery through `_awaken_len()`, which is used both for the timer and the meter drain so they stay in step.
4. **UI.** Each screen reads `player.upgrades` / `masteries` / `synergies` and the `Upgrades` helpers. Nothing in the UI changes state.

## Invariants

- **One colour table.** Path colours come from `Upgrades.PATHS` only: cards, icons, HUD, build view, guide keys and power FX all read it. Don't hard-code a path colour anywhere else. Teal stays reserved for synergies.
- **A fusion is never offered without both paths.** `can_fuse()` counts non-fusion powers only, so one fusion can't unlock another.
- **Fusions count for both paths** in `path_counts()`. The cards' mastery progress and `player.masteries` both come from it, so they always agree.
- **Keep textures referenced.** `Upgrades.icon()` caches every texture. A texture that is only referenced by a `draw_texture_rect` call is freed before the frame renders, and then draws as a solid square (this happened during the build).
- **Awakening timer and meter.** Anything that lengthens Awakening must change `_awaken_t` and set `Game.awakening` to match (see Undying Flame), because the meter drain uses `_awaken_len()`.

## Tuning

| Where | What |
|---|---|
| `Upgrades.PATHS[path].mastery` | Mastery numbers and text (`{key}` placeholders fill from the same dict). |
| `Upgrades.MASTERY_NEED` | Powers needed for a mastery (3). |
| `Upgrades.FUSION_CHANCE` | How often an eligible fusion takes the last card (0.5). |
| Each power's `lv` | Per-level numbers, as before. |
| `Upgrades.SLOT_NAMES` | Readable slot names on cards. |
| `PowerIcon.BACK`, `PIP_OFF` | Icon backing and empty-pip colours. |
| `reward_screen.CARD_BG`, card size in `_card` | Card look. |
| `hud.POWER_ICON` | HUD icon size (44). |

## Extending

- **New power:**
  1. Add the entry to `Upgrades.ALL` with `path`, `slot` (add it to `SLOT_NAMES` if new), `desc` and `lv`.
  2. Implement the effect in `player.gd` by id. Call `_proc(id)` if the autotest should count it.
  3. Add a glyph to `ICONS` in `tools/gen_power_icons.py`, run it, then `godot --headless --import --path .`.
  4. Run `tests/power_check.gd`. It fails on a missing path, icon or slot name.
  5. Run `python tools/wiki.py`.
- **New fusion:** the same steps, plus a `fusion` key with the second path. Make the effect actually connect the two inputs.
- **New path** (for example element powers): add it to `PATHS` with a colour that isn't teal and isn't already used, implement its mastery in `player.gd` (`_mastery(path, key)`), and give it at least `MASTERY_NEED` powers. The test checks that count.

## Testing

- `godot --headless --path . -s tests/power_check.gd` checks:
  - **Data:** every power has a path, an icon, a slot name and placeholders for its numbers.
  - **Fusion offers:** none are offered with one path (200 seeds); Crescendo is offered with Light + Heavy.
  - **Masteries:** a fusion counts toward one; Soul adds HP and takes it back.
  - **New effects:** Quickblade speed, Thousand Cuts on the Nth hit, Crescendo, Shockstep, Slipstream once per dash, Flicker, Undying Flame, Razor Gale's blades, Eye of the Storm's pull.

  It prints `[powers] PASS` or `[powers] FAIL ...`.
- Windowed (drop `--headless`), it also saves `user://power_cards.png` (a new card, a level-up and a fusion), `power_hud.png` and `power_build.png`.
- `-- --autotest --all-upgrades` turns on every mastery and prints `power_procs=`. The bot rarely dash-cancels heavies or dashes through foes, so Shockstep and Slipstream are mainly covered by `power_check`.

## Gotchas / open questions

- `Upgrades.describe(u, level, active, bb)` with a colour wraps numbers in `[b][color]`. Only use that form in a `RichTextLabel` (with `bold_font_size` set), never in a `Label`.
- The HUD strip removes the old icons with `remove_child` before freeing them, because a queued-free child still takes space in the flow container until the end of the frame.
- Open (ROADMAP Round 20): a feel pass on the mastery numbers and fusion frequency, the weaker icons (Riposte, Shockstep) at HUD size, and showing paths and fusions on the wiki.
