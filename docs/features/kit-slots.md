# Kit slots: the slot table in code

Round 49. The kit grammar (`docs/characters/kit-grammar.md`) says every character fills the same slots, with
the same input shapes. This page is how that table lives in code, and how to fill it in for a new character.

## What it does

- `scripts/kit_slots.gd` (`KitSlots`) holds the grammar's ten groups and 24 slots as data. It also holds one
  **card** per character: which move id fills each slot and the input that starts it, the route steps, and the
  demoted upgrades. `KitSlots.of(Game.hero)` returns the card.
- The pause menu's MOVES panel is laid out by slot group. Each group heading has its number, name and role line
  ("2  LIGHT ENDERS: One per element..."). After the groups come ROUTE STEPS, UPGRADES and MIX ELEMENTS. Each move
  row ends with its slot's one-word tag. A slot nobody has filled yet shows as "Dark x magma: pending".
- The combo guide shows the same tag after the move's name (`launch`, `plant`, `payoff`, `cross`, `step`, ...).
  It only appears while the guide is on (`Game.combo_guide`).
- Demoted moves stay in the game behind `Kit.has()` (`scripts/kit.gd`). With the upgrade off, the routing goes
  past them and the panel draws them as dim "upgrade" rows. `--kit=full` or `--kit=<id>` turns them on.
- Each autotest bot string names its slot. The autotest prints
  `[kit] slots=N/N windows=N/N upgrades=N/N missing=...`, and `agent.sh check` fails unless every number is full.
- `tests/kit_check.gd` checks the heretic's card against the grammar and the real routing.

## The heretic's card

| # | Slot | Tag | Move (input) | Window |
|---|---|---|---|---|
| 1 | `light_string` | string | Slice `L1` (L), Hurl `L2` (L L), Triple Chop `L3` (L L L) | |
| 2 | `ender_1` | launch | Updraft Lash `EC` (L H) | |
| 2 | `ender_2` | plant | Frost Spear `IP` (L L H) | |
| 2 | `ender_3` | carry | Molten Palm `EM` (L L L H) | |
| 3 | `big_1` | payoff | Live Wire `EE` (L H H) | Grounded / Short Circuit |
| 3 | `big_2` | payoff | Deep Freeze `IS` (L L H L H, through the vault) | Avalanche |
| 3 | `big_3` | payoff | Undertow `EV` (L L L H H) | Meteor Fall / Meteor Shower |
| 4 | `air_route` | air | Live Wire air `EW` (L H L H) | Worldbreaker / Cold Front |
| 5 | `sig_mark` | mark | Reap `VR` (H L) | |
| 5 | `sig_gather` | gather | Singularity `VS` (H H) | Collapse |
| 5 | `sig_drag` | drag | Black Tide `VD` (H L H) | Maw / Black Ice |
| 5 | `sig_pin` | pin | Overwhelm `OW` (hold H) | Abyss |
| 6 | `dash_l` | lunge | Dash Stab `DL` (Dash L) | |
| 6 | `dash_h` | snare | Tow Line `TW` (Dash H) | |
| 7 | `dash_ender_l` | crowd | Harpoon `EF` (Dash L H) | Shatterstorm / Slapshot |
| 7 | `dash_ender_h` | skewer | Impale `XK` (Dash H H) | none yet |
| 8 | `cross_storm_magma` | cross | Fault Line `XF` (L H L L H) | Cataclysm / Tempest |
| 8 | `cross_ice_magma` | cross | Steam Burst `XS` (Dash L H H L) | Flash Freeze |
| 8 | `cross_dark_storm` | cross | Galvanize `XC` (H L L) | |
| 8 | `cross_ice_storm` | cross | Hailstorm `XG` (Dash L H H H), then Meltdown `XM` (+ L) | Eruption |
| 8 | `cross_dark_ice` | cross | Backdraft `XW` (Dash H H L) | Anvil / Pinwheel |
| 8 | `cross_dark_magma` | cross | pending (the dark-magma lane) | |
| 9 | `counter` | counter | Backlash (Dash into a strike; `counter.gd`, not a routed move: the fill is its window `CB`, `routed: false`) | Ricochet |
| 10 | `awakening` | awaken | the meter (Q), no move id | |

That is 22 slots filled, 1 pending and the meter. There are 13 windows with 20 endings in all.

- **Route steps** (not slots, never an upgrade target): the grab `GR` (H), Air Slash `AL1` (L H L), the vault
  `IJ` (L L H L), Rockslide `XR` (L H L L), Ice Cube `EA` (Dash L H H). R and R-then-H (the swing and Snatch) are
  listed with them on the panel.
- **Upgrades** (`HERETIC.upgrades`), one:
  - `storm_pitch` gates the **route**: `Dash H L` is Tow Line then Slice until it is on.
  - Rockslide's buried payoff was demoted too (`rockslide_payoff`), then put back in the base kit (Zak, round 49):
    Fault Line's buried x2 and the buried rule (Crater) need the buried state, and Rockslide is its only source.
  - The `"payoff"` kind of gate stays in `KitSlots` and `kit_check` (a move that routes, with its payoff behind
    `Kit.has()` at the payoff site), unused for now.

## Files

| File | Role |
|---|---|
| `scripts/kit_slots.gd` | `GROUPS`, `SLOTS` (id, group, name, shape, tag, role, window, `pair` on crossovers), `HERETIC` / `PRINCE` cards, `of()`, `slot()`, `slot_of()`, `pending()`, `upgrade_of()`, `open()` (may the routing reach this id?), `tag_of()` |
| `scripts/kit.gd` | `Kit.has(id)`, `--kit=full` / `--kit=<ids>`, `set_on()` for tests |
| `scripts/hero_moves.gd` | `void_route()` asks `KitSlots.open()` before `LIGHT_AFTER` / `AFTER`; `option()` adds `role` |
| `scripts/move_list.gd` | `SECTIONS` by `group`, then ROUTE STEPS, UPGRADES, MIX ELEMENTS; `heading()`, `pending_slots()`, `row_upgrade()`, `row_locked()`, `row_tag()` |
| `scripts/pause_menu.gd` | draws the headings, the slot tag per row, dim "upgrade" rows and pending slots |
| `scripts/combo_guide.gd` | the `role` tag (`ROLE_SIZE`, `ROLE_COLOR`) |
| `scripts/training_bot.gd` | `BOT_STRINGS` entries `{slot or upgrade, tokens}`; `active()` / `strings` (upgrade strings only with their upgrade on); `labels_of()`; `kit_report()` and the `[kit]` line |
| `tests/kit_check.gd` | the card against the grammar (below) |
| `tests/move_list_check.gd` | routes every row with the upgrades off, then on |
| `tools/agent.sh` | runs `kit_check`, and runs the autotest twice: plain and with `--kit=full`. It asserts `[kit]` on both |

## How the counts work

- **`[kit] slots=`** counts every slot with a fill (not pending, not the meter). A slot counts as landed when a
  bot string labelled with it played and every move in its fill connected (`player._connected` in ATTACK or LEAP).
  The counter has no move id: it lands when its window's ending (Ricochet) does.
- **`windows=`** counts every BREAKERS key on a slot's move. A window counts when one of its endings is in
  `player.endings_seen`. `endings_n=` still asks for every ending.
- **`upgrades=`** counts only the upgrades that are on in this run. An upgrade counts when its labelled string
  played and its moves connected. On a plain run this is `0/0`; with `--kit=full` it is `1/1`.
- **`missing=`** names the slots, windows and upgrades that did not land.

`kit_check` fails on any of these:

- a slot that is empty and is neither the meter nor in `PENDING_OK` (`cross_dark_magma`);
- a `routed: false` slot (the counter) whose fill isn't a BREAKERS key;
- a fill whose input does not start its move through `void_route()`;
- an input outside the slot's `shape`. Shapes are exact, except:
  - `*`: one route step's press between the ender and the last H (Deep Freeze's vault);
  - `+`: one L or H off an input already on the card (every crossover);
- a breaker on a route step or upgrade, a window with more than 2 endings, or more than 15 windows;
- more than 6 crossovers, two crossovers on one colour pair, or a crossover whose pair's two elements are not on
  its route (`ELEMENT_OF` along the presses);
- a MOVES id that is not on the card;
- a bot string with no label, or a filled slot or upgrade with no string;
- a "route" upgrade's move that can be reached with the upgrade off (by its input or by any presses from neutral),
  or one that can't be reached with it on. A "payoff" upgrade's move must route both ways.

It also prints the window slots the grammar wants but that have no breaker yet (today: `dash_ender_h`, Impale).

## Filling the card for a new character, step by step

The worked example is the dragon prince (`KitSlots.PRINCE`, paused, `docs/characters/dragon-prince.md`).

1. **Write the card on paper first** (kit-grammar.md section 6): the signature and its colour, three elements,
   and one line per window saying when L wins and when H wins. The prince: the crown is his signature, Sunbrand's
   fire is element 1, and elements 2 and 3 are still open.
2. **Add a card const** next to `HERETIC`, with every slot id as a key, and return it from `of()` for that
   `Game.hero`. Mark it `"todo": true` until every slot is filled; `kit_check` only checks the shape of a todo card.
3. **Fill the obvious slots from moves that exist.** The prince's light string is `P_SLASH` / `P_RIPOSTE` /
   `P_CLEAVE` (L, L L, L L L). His enders are Ember Flick `P_FLICK` (L H, the launch slot), Javelin `P_JAVELIN`
   (L L H, the plant: the sword sticks in the foe) and Dragon Breath `P_BREATH` as the L L L H stand-in. Skyfall
   `P_SMASH` is Javelin's payoff, so it goes in `big_2`.
4. **Put the hits that only walk somewhere in `route`.** For the prince that is Talon Fury's three claws and
   Rightful Return (sword out). Decide whether the claws are the light string's second form; it is a TODO on his
   card.
5. **Leave a slot `{}` until its move exists.** It shows as "pending" on the panel and doesn't count in `[kit]`.
   Don't invent a move to fill it.
6. **Give the character a routing function the checks can walk**, like `hero_moves.void_route()`. `kit_check`
   walks the heretic's; a second character's card needs its own walk. The prince's `prince_moves.route()` takes
   the sword's state, so that walk has to set the state too.
7. **Label a bot string for every filled slot** in the character's autotest strings (`{"slot": ..., "tokens": ...}`).
   Then `[kit] slots=N/N` says the bot reached every slot.
8. **Demote, don't delete.** A move outside the slots goes in `upgrades` with a `Kit.UPGRADES` id. Gate its route
   (`KitSlots.open`) or its payoff (`Kit.has` at the payoff site). Give it an `upgrade` bot string so `--kit=full`
   still plays it.
9. **Run** `kit_check`, `move_list_check` and both autotests (`bash tools/agent.sh check`). Once every slot is
   filled, drop `todo`.

**Pending lanes:** when a move lands for a pending slot, fill it with one line, for example
`"cross_dark_magma": {"<id>": "<input>"}` in `HERETIC.fill` (the counter was filled that way, `{"CB": ...}`). Then add a labelled bot string, and drop the slot from
`kit_check.PENDING_OK`.

## Invariants

- Never remove the code behind a gate. `Kit.has()` sits at the routing or payoff site.
- Route steps are never upgrade targets. Run upgrades target a slot or a window (kit-grammar.md section 7).
- The MOVES panel's move rows and the card's fills must both route (`move_list_check`, `kit_check`). The panel may
  show the longer, practical input: Impale is listed as "L L H, Dash H H" and filled as "Dash H H".

## Testing

- `godot --headless --path . -s tests/kit_check.gd` prints `[kit] PASS/FAIL`, the window count and the pending slots.
- `godot --headless --path . -- --autotest` prints `[kit] slots=22/22 windows=13/13 upgrades=0/0 missing=none`.
- With `-- --autotest --kit=full`: 37 strings (36 plain: Storm Pitch's joins), `upgrades=1/1`.
