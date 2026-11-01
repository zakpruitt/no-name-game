# Run map, vaults and trials

Added in Round 21. It replaces the two-door choice (`path_options()` and
`path_choice.gd`, which have been removed).

## What it does

When a run starts, the whole run is laid out as a map, and shown once before room 1 ("YOUR RUN", Enter begins; skipped by the autotest and by restarts that skip the title):
- 8 columns (`main.RUN_LENGTH`) of up to 3 lanes, linked left to right;
- room 1 is a lone fight, room 2 is two fights, and the Bone Warden is alone at the end.

After each room, the map opens (`CHOOSE YOUR PATH`) and the player picks one of the rooms linked to where they stand. They can pick with a click, with keys 1–3, or with the arrows plus Enter.

What the map shows:
- each room's icon, and its colour by kind;
- for a vault, the colour of its path;
- for an elite, pips for its twists;
- the route so far, lit, and the hero marker over the current room;
- the reachable rooms, pulsing with their key number;
- the routes the focused choice leads to (brighter links); rooms it can't reach are dimmed;
- a legend of room kinds along the bottom.

Hovering any room shows its detail, with "on your way" / "out of reach now". After a pick the marker walks to the room (`MOVE_TIME`) before the map closes. The HUD (`map_screen.cover`) hides while the map is open.

A panel describes the focused choice, for example "Elite · Volatile + Hasted — foes burst when slain, faster foes, 2 powers". For a vault, the panel adds how many powers of that path you own, with mastery pips. Every room's panel ends with what it leads on to ("Leads on to: 2 elites · Light vault · 1 rest", `_ahead_text` over `_reach`).

Pause → **Map** shows the same map read-only.

**New rooms:**
- **Vault.** A gold chest rises, lit in the vault's path colour. It offers 1 of 3 powers of that path (fusions on that path count), under the title "LIGHT VAULT" etc. This lets you route toward your colour. There is no fight.
- **Trial.** A fight at three-quarter size with a condition from `RunMap.TRIALS`, shown live under the room title:
  - **Untouched:** take no damage.
  - **Swift:** clear within `20 + 4 × room` s.
  - **Stylish:** reach style rank A.

  On clear, the normal power comes first, then "TRIAL COMPLETE" or "TRIAL FAILED". Meeting the condition offers up to 2 fusion cards (`Upgrades.roll_fusion`). If none can be offered, it falls back to a level-up roll, then to `main.TRIAL_BONES` (20).

## Files

| File | Role |
|---|---|
| `scripts/run_map.gd` | `RunMap`, which is static data plus generation. It holds the tuning (`LANES`, `UNLOCK_ROOM`, `BRANCH_CHANCE`, `PRE_BOSS_REST`, `KINDS`, `WEIGHTS`, `TRIALS`) and builds the map (`generate`, `_link`, `_assign`, `_ensure_rest`, `_dress`). Queries: `node_at`, `next_nodes`, `preds`, `is_fightless`. Text: `color`, `title`, `describe`, `trial_text`, `trial_time`. |
| `scripts/map_screen.gd` | The screen: one `Control` drawn by `_draw_map` / `_draw_node` / `_draw_legend`, plus a detail panel (`_update_detail`, `_show_room`). `open(map, visited, choices, read_only, counts)`, `open_intro(map, visited)`, `pick(i)` (walks the marker, then `signal chosen(index)`). Hover: `_node_under`, `_set_hover`; routes: `_reach_from`, `_ahead_text`. Layer 12, pauses the tree, hides `cover` (the HUD). |
| `scripts/main.gd` | `run_map` and `map_route` (the `Vector2i` column/lane of each room so far). `_start_map()` (after the title, before room 1), `_choose_path()` (opens the map), `_enter_node()`, `show_map()` (pause), `_vault()`, the trial (`_update_trial`, `_finish_trial`, `_on_hero_hp`, `_trial_t`, `_trial_state`), `_room_tag()` for the HUD, and `_take_reward(choices, reroll_cost, title)`, shared by all rewards. |
| `scripts/vault_prop.gd` | The chest, candles and path-coloured light. `rise()`, `burst()`, `sink()`. |
| `scripts/upgrades.gd` | `roll(..., path)` (the vault filter, topped up from any path when short) and `roll_fusion()`. |
| `scripts/reward_screen.gd` | `open(choices, reroll_cost, title)`. |
| `scripts/hud.gd` | `trial_label` / `set_trial(text, state)`; `set_room` banners for vault and trial; `route_strip` / `set_route(colors, total)`: a dot per room across the top, the rooms taken in their map colours (set from `main._next_room`). |
| `scripts/pause_menu.gd` | The **Map** button (index 1; Settings is now 2). |
| `tools/gen_power_icons.py` | `ROOMS` glyphs → `assets/icons/rooms/<kind>.svg`. |
| `assets/kaykit/dungeon/chest_gold.glb` | The vault's chest model (already in the repo). |
| `tests/map_check.gd` | Map invariants and the screenshot. |

## How it works

1. **Generation** (`RunMap.generate(rng, length, twist_ids, double_twist_room)`), once per run in `main._start_map()`. This happens after the title, because a daily run or replay reseeds `run_rng` there.
   1. **Shape:** one node per lane per column.
   2. **Links** (`_link`):
      - a single-node column links to every node next to it;
      - otherwise each node links to the nearest lane, and with `BRANCH_CHANCE` also to a neighbouring lane, as long as that link doesn't cross another one;
      - then any node with no way in gets one from its nearest neighbour.
   3. **Kinds** (`_assign`): rolled from `WEIGHTS` for rooms from `UNLOCK_ROOM` (3) on, leaving out fightless kinds when any predecessor is fightless.
   4. **Rest before the boss** (`_ensure_rest`): makes one node in the column before the boss a rest, and turns fightless predecessors into fights.
   5. **Details** (`_dress`): elite twists (2 from `main.DOUBLE_TWIST_ROOM` on), the vault's path and the trial's condition. These are rolled now so the map can show them.
2. **Start flags** (`--start-room`, `--twist`, `--start-rest/shrine/vault/trial`) override the first node in the start column, so the map shows what you're actually in.
3. **Choosing** (`_choose_path`):
   - with one option (the boss), it goes straight on;
   - otherwise it opens the map, appends the pick to `map_route` and copies the node's kind, twists, path and trial into `room_kind` / `room_twists` / `room_path` / `room_trial`;
   - the tour bypasses the map and forces `TOUR`.
4. **Rooms:** `_next_room()` dispatches on `room_kind`, and a trial scales `wave_composition` by `TRIAL_SIZE`. The trial's state is updated every frame from `_process` (Swift's clock, Stylish's rank) and from `player.health_changed` (Untouched). `_finish_trial()` runs after the normal reward.

## Invariants

- **One map per run, rolled from `run_rng`.** Nothing rerolls it, and the map screen only reads it. Seeded and daily runs must get the same map: `map_check` checks seed → same map.
- **No two fightless rooms are linked** (rest, shrine, vault: `KINDS[..].fightless`). This replaces the old "not after a rest or shrine" door rule. `_ensure_rest` keeps it by turning predecessors into fights.
- **Every room is reachable and has a way out.** Links only go forward, so together these mean every room can reach the boss.
- **Nodes are dictionaries.** Look them up by (column, lane), never with `Array.find`. Equal-looking nodes exist in other columns, and `find` compares by content (`map_screen._choice_index`).
- **`main.room` is still the room number.** `map_route[-1].x == room - 1` once a room has started. The tour jumps `room` to the boss and adds a matching route entry.

## Tuning

| Where | What |
|---|---|
| `RunMap.WEIGHTS` | How often each kind appears from room 3 on (fight 32, elite 18, rest 10, shrine 9, vault 22, trial 12). Vaults are weighted up because they can't follow a rest or shrine; this gives about 2 vaults and 2 trials a map (`map_check` prints the totals over 500 seeds). |
| `RunMap.BRANCH_CHANCE` | How many crossroads (0.45). |
| `RunMap.UNLOCK_ROOM`, `PRE_BOSS_REST` | Plain fights at the start, and the rest before the boss. |
| `RunMap.TRIALS` | Conditions; Swift's `time` and `per_room`; Stylish's `rank`. |
| `RunMap.KINDS` | Name, map text and colour per kind. |
| `main.TRIAL_SIZE`, `main.TRIAL_BONES` | Trial fight size; bones when no card can be offered. |
| `map_screen.X0/X1/Y_MID/LANE_GAP/R` | Layout. |
| `map_screen.AHEAD`, `OFF_ROUTE`, `MOVE_TIME`, `LEGEND` | Route highlight, dimming of unreachable rooms, the marker's walk, legend order. |

## Extending

- **New room kind:**
  1. Add it to `KINDS` (and `fightless` if it has no fight) and to `WEIGHTS`.
  2. Add a glyph to `ROOMS` in `tools/gen_power_icons.py` and rerun it, then `--import`.
  3. Add a branch in `main._next_room()` and a banner in `hud.set_room()`.
  4. Add it to `TOUR` if the tour should cover it.
  5. `map_check` fails until the kind shows up in its seeds.
- **New trial condition:** add an entry to `TRIALS`, a case in `main._update_trial()` (state and HUD text), and settle it in `_finish_trial()` if it isn't "still holds at the end".
- **Longer runs:** `generate` uses `length`, so raise `RUN_LENGTH`. Also extend `main.ROOM_LAYOUTS`, which is indexed by room.

## Testing

- `godot --headless --path . -s tests/map_check.gd` generates 500 seeds. It checks the shape, links, reachability, the fightless rule, the pre-boss rest, valid twists, paths and trials, and determinism, and prints how often each kind appeared. It also checks the screen on its own, headless: hover shows any room, hovering a choice focuses it, the pick walks before `chosen`, and the HUD comes back. It prints `[map] PASS` or `[map] FAIL`. Windowed, it saves `user://map_check.png`, four rooms in with a vault focused if one is offered.
- `-- --autotest --tour` runs fight → rest → shrine → elite → vault (Light) → trial (Swift) → boss. PASS needs the vault to have offered only Light cards.
- `--start-vault=<path>` and `--start-trial=<id>`, with `--pace` to stop at the first clear. The autotest prints `[autotest] trial=<id> met|failed fusions=<n>` and saves `autotest_map.png` and `autotest_vault_room.png`.
- `tests/menu_check.gd` saves `menu_intro.png` (the run's first map) and `menu_map.png`, the map mid-run.

## Gotchas / open questions

- The map screen handles input in `_input` and marks it handled, so the pause menu's Esc doesn't fire under a read-only map.
- `RunMap.main_twist` loads `main.gd` for `ELITE_TWISTS`, because main has no `class_name`.
- Open (ROADMAP Round 21): a feel pass on the kind weights, Swift's time for a person rather than the bot, and whether Untouched should forgive a chip hit.
