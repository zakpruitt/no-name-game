# Element matrix

## What it does

Every state a crossover leaves on a foe, against every element the hero hits it with. Each cell pays something,
so a dash out of any string into a move of another element does more than a plain hit. States last
`ELEMENT_HOLD` (2 s) and each payoff reads the state, not the input that set it
([void-element.md](void-element.md), "Improvising").

Elements by base move. Storm: Updraft Lash (L H), Live Wire (L H H, L H L H). Ice: Frost Spear (L L H), Harpoon
(Dash L H), Ice Cube (Dash L H H), Deep Freeze. Magma: Molten Palm (L L L H), Undertow (L L L H H). Dark: Reap,
Black Tide, Singularity, Overwhelm, Tow Line.

| State (set by) | storm | ice | magma | dark |
|---|---|---|---|---|
| **frozen** (Harpoon, Ice Cube, Deep Freeze, Impale, Hailstorm, Black Ice) | Hailstorm lifts them in their ice; **Gale Lift**: any storm move takes the cube up, still frozen | Ice Cube bowls the frozen first; ice on ice refreezes | Molten Palm goes off as Steam Burst; Steam Burst; Meltdown bursts the ice | **Shatter**: the ice is crushed (x `FREEZE_BREAK`) and the shards cut the nearest foe |
| **buried** (Rockslide) | Updraft Lash / Storm Pitch hit again (`_cash_buried`); Fault Line x2 | **Frozen In**: frozen where it's stuck | **Aftershock**: driven back in x1.5, a crater | **Swallowed**: x1.5, a crater, held `IMPROV_HOLD` |
| **molten** (Meltdown) | **Firestorm**: launched, and the flames catch the nearest foe (`molten`, a chain hit) | **Quench**: a steam burst, x1.6, launched | Eruption x`ERUPT_MOLTEN_MULT`; **Flare-up**: any magma move erupts the floor under them | **Smother**: x1.5, a crater |
| **skewered** (Impale) | Backdraft hauls them back in full | **Ice Spreads**: the nearest foe is frozen and skewered too | (still frozen) Molten Palm's steam; Anvil | **Torn Off**: x1.5, yanked off the spear towards him |
| **airborne** (any launcher) | the air string: Air Slash re-juggles, Live Wire holds them up | **Freeze Aloft**: frozen up there, comes down a cube | Rockslide x2, Meltdown x1.5, Anvil; **Meteor Spike**: any magma move drives them down into a crater, x1.5 | Tow Line rips them out of the air (x`TOW_AIR_MULT`) |
| **bound** (Undertow, Overwhelm tendrils) | **Torn Loose**: out of the bind and launched, x1.5 | **Frozen in the Dark**: frozen where they're held | Meteor Fall rips the biggest out of Undertow | Abyss off Overwhelm |

Bold cells are the third pass's (`VOID_ELEMENT.IMPROV`); the rest were already paid by the moves themselves.

### Looks

Each bold cell has a one-beat tell that says which two elements met, in both elements' palettes (`fx_palette`), and
its own word over the move's (`scripts/comic_improv.gd` `LOOKS`, `ComicFx.IMPROV_WORDS`). Real time, gone by 0.35-0.45 s.

| Cell | Payoff | Look | Word |
|---|---|---|---|
| frozen x storm | Gale Lift | two wind bands spin up round the cube, ice chips flung off them (rides it up) | FWISSH! |
| frozen x dark | Shatter | a violet tear across the ice, five ice plates flung out, one streaking at the foe it cuts | SHA-KRAK! |
| buried x ice | Frozen In | six ice plates close over a crack ring on the floor, three ice tips in front of it | KRRIK! |
| buried x magma | Aftershock | two hot shock rings run out of the crater with four cracks, one drive stroke down | BA-DOOM! |
| buried x dark | Swallowed | a dark mouth on the floor shuts its toothed jaws over the crater, a hot seam where it closed | GULP! |
| molten x storm | Firestorm | a wind band carrying ember streaks round it, an ember line out to the foe it catches | FWAAASH! |
| molten x ice | Quench | three small steam puffs over it, ice chips spilling, a hot star going out | HSSSSK! |
| molten x magma | Flare-up | a hot floor splat under it, three flame tongues licking up after it | FWUMP! |
| molten x dark | Smother | a violet lid drops onto it, embers squirting out at its feet | SMOOSH! |
| skewered x ice | Ice Spreads | a frost line runs along the floor to the next foe, ice tips where it arrives | KRIK-KRIK! |
| skewered x dark | Torn Off | the stake snaps into two spinning halves, Tow Line's void tear (`comic_rip`) | RRRIP! |
| airborne x ice | Freeze Aloft | a burst of seven thin ice spikes round it in the air, a glint | FRZZK! |
| airborne x magma | Meteor Spike | an ember line falls through it into the floor, a hot dent where it lands | KA-CHUNK! |
| bound x storm | Torn Loose | the violet ropes snap and whip off its feet, three wind strokes up | SNAPP! |
| bound x ice | Frozen in the Dark | the violet coils round its legs ice over from one end, small ice plates at its feet | KLINNK! |

## Files

| File | Role |
|---|---|
| `scripts/void_element.gd` | `IMPROV` (state -> element -> payoff kind), `IMPROV_ORDER`, the `IMPROV_*` constants, `improvise()`, `improv_state()`, `in_state()`, `_pay()`, `_chain()`; `fire()` calls `improvise()` and then `_fire()` (the move) |
| `scripts/comic_improv.gd` | The tells: `LOOKS` (cell -> name, life, ride, palettes), one draw function per cell on `comic_flat.gd`; `spawn()` from `_pay()` (comic style only), Torn Off adds `comic_rip` |
| `scripts/comic_fx.gd` | `IMPROV_WORDS` by cell, `improv()` (once a move), the move's own word held `IMPROV_HOLD_MS` after it |
| `tests/improv_shots.gd` | Look (windowed): every cell played for real on the dummies, six crops 83 ms apart (`--alone`: the payoff only, `--only=<cells>`) |
| `scripts/floor_bind.gd` | The "bound" state: `BOUND` meta while a bind holds a foe, `holds()`, `let_go_of()` (Torn Loose) |
| `scripts/move_list.gd` | The IMPROVISING section: one text row per bold cell |
| `scripts/training_bot.gd` | Three bot strings reach a cell each; the autotest prints `[improv] <state>_x_<element>=N` |
| `tests/void_arm_check.gd` | `_element_matrix()`: every cell on a stand-in foe, the moves' own cells left alone, a whole Harpoon cashing in `buried` |

## How it works

1. `fire()` (a move's first hit) calls `improvise(hero, id, at, power, fwd)` first. Only base element moves improvise
   (`ELEMENT_OF`, not `X*`: the crossovers read their own states in their bodies).
2. It collects the foes the move itself lands on (`improv_reach()`, round 4: was everyone `IMPROV_REACH` round
   him), skips anyone in flight (`THROWN.flying`), and reads each one's state for this element:
   the first in `IMPROV_ORDER` with a cell. Every state is read before any is paid, so a chain that sets a state
   on the neighbour doesn't pay again in the same move.
3. `_pay()` spends `buried` / `molten` / `skewered` (once) and runs the cell's kind: one hit of
   `IMPROV_DAMAGE` and a launch (`IMPROV_LAUNCH`), a crater (`Vector3.DOWN * IMPROV_DOWN`), ice (`encase()`,
   `freeze_aloft()`) or a chain (`_chain()`: the nearest foe within `IMPROV_CHAIN_R`).
4. Then the move itself runs (`_fire()`). A payoff never throws (`THROWN.launch`), so the move can still throw
   the same foe.

**Reach = the move's own hit shape** (`improv_reach()`, read before the move fires, from the move body's own
numbers):

| Move | Who its payoff reaches |
|---|---|
| Updraft Lash (EC) | the gale's circle, `CUTTER_RADIUS` x the chain's grow, `CUTTER_AHEAD` in front of him |
| Live Wire (EE, EW) | whoever the tentacles reach (`void_grab.reachable()`, `SEIZE_RANGE`) |
| Ice Cube (EA) | the nearest within `BOWL_REACH` and the roll ahead of it (`BOWL_LENGTH`, `IMPROV_ROLL_HALF_WIDTH` 1 m either side) |
| Harpoon (EF) | the spear tip's line (`HARPOON_LENGTH`, `HARPOON_HALF_WIDTH`, cut short by a wall) |
| Frost Spear (IP) | the frost round where the spear goes in (`frost_spear.RADIUS`) |
| Vault (IJ) | nobody: it hits nothing |
| Deep Freeze (IS) | the frost ring round the spear (`DEEP_FREEZE_RADIUS`) |
| Molten Palm (EM) | the fist's lava line (`PALM_LENGTH`, `PALM_HALF_WIDTH`) |
| Undertow (EV) | `UNDERTOW_RADIUS` round him, and whoever the palm shoved within `UNDERTOW_CHASE` |
| Singularity (VS) | the hole where the slam lands (`dark_fx.Hole.RADIUS`) |
| Reap (VR) | the crescent: `REAP_REACH`, `REAP_HALF_ANGLE` either side of his aim |
| Black Tide (VD) | the marked within `TIDE_REACH`, else `TIDE_NEAR` round him |
| Overwhelm (OW) | the pool on whoever he aims at (`_overwhelm_spot()`, `OVERWHELM_RADIUS`) |
| Tow Line (TW) | the line he just dashed along (`_tow_line()`) |
| anything else | its MOVES `range` / `arc` / `width`, else `IMPROV_REACH` round him |

Breakers don't improvise (they read their own states in `breaker_impact()`), so a breaker zone never pays a cell.

## Invariants

- The cells a move already pays itself stay out of `IMPROV`, or the state pays twice (Molten Palm's steam reads
  the ice, `_cash_buried` the buried, Tow Line's rip the airborne). `_element_matrix()` checks improvise leaves them.
- Knockback directions follow the foe contract: craters pass `Vector3.DOWN * IMPROV_DOWN`, launches at least
  `enemy.RELAUNCH_MIN` (`IMPROV_LAUNCH` 8) so one in the air re-launches.
- A payoff hits on ice x `FREEZE_BREAK` like any hit, and the hit thaws it: ice payoffs (`encase`, `freeze`,
  `spread`) hit first and freeze after.
- Bosses never freeze (`encase`, `freeze_aloft`) and the heavy aren't launched.
- A payoff lands only where the move does: a foe inside 5 m of him but outside the move's shape (behind him, off
  the harpoon's line) never pays (`_element_matrix()`).

## Tuning

`IMPROV_REACH` (5 m, only for a move with no shape in `improv_reach()`), `IMPROV_ROLL_HALF_WIDTH` (1 m), `IMPROV_DAMAGE` (8), `IMPROV_MULT` (1.5), `IMPROV_LAUNCH` (8 m/s), `IMPROV_DOWN` (6 m/s),
`IMPROV_CHAIN_R` (2.6 m), `IMPROV_CHAIN_DAMAGE` (5), `IMPROV_PULL` (6 m/s), `IMPROV_STEAM_MULT` (1.6),
`IMPROV_HOLD` (0.6 s). Quench and Flare-up reuse `STEAM_LAUNCH`, `ERUPT_MOLTEN_MULT` and `ERUPT_LAUNCH`.

## Extending

- A new state: set it with `mark(e, "<state>")` (or a check in `in_state()`), add a row to `IMPROV` and a place in
  `IMPROV_ORDER`, a kind in `_pay()` if none fits, a move_list row, a case in `_element_matrix()` and a line here.
- A new base move pays its element's column for free (`ELEMENT_OF`).

## Testing

- `godot --headless --path . -s tests/void_arm_check.gd`: `_element_matrix()` (PASS/FAIL).
- `godot --headless --path . -- --autotest`: `[improv] frozen_x_void=3, buried_x_water=1, airborne_x_water=1`
  from the bot's `line D L H D H`, `L H L L D L H` and `L H D L H`.

## Gotchas / open questions

- The placeholders (wind pillars, shards, steam, rim geyser + spikes, ink bursts, scorch, `ELEMENTS.arc` on chains)
  are gone in the comic style; `_chain()` returns where it jumped so the tell draws the jump. Coverage per crop round
  the payer (the middle 60% of 640x480, effect-coloured pixels): 0.04-0.15 alone, at most 0.27 with the move's own hit
  (Molten Palm's stars), under the 0.40 cap.
- Meteor Spike's falling line hides under Molten Palm's stars when the move plays; its word and dent carry it.
- Only three cells have a bot string; the rest are covered by the headless check. Molten can't be reached by the
  bot (Meltdown always opens its window and the bot always takes it): try it by hand, dashing out of the hang.
- The reach follows each move's own shape since round 4. A long chain grows the shapes (`_cast_grow()`): Updraft
  Lash's 4.5 m gale circle 3.5 m ahead then reaches behind him, as its own hit does.
- The bot's dash strings aim at the nearest foe (`face` token): the dash and Dash Stab's lunge carry him past the
  buried, and with the 5 m circle gone a harpoon thrown the other way paid nobody (`buried_x_water` 1 -> 0).
