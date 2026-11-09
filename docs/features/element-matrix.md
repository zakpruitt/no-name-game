# Element matrix

## What it does

Round 49 (kit grammar section 3, [kit-grammar.md](../characters/kit-grammar.md)): **six states, one payoff rule
each.** A foe left in a state pays that state's rule when any other element's move hits it, so a dash out of any
string into a move of another element does more than a plain hit, and a new character or element never adds cells.
The rules are written once (`void_element.RULES`, `_pay()`); the old per-cell payoffs are **upgrades**
(`IMPROV_UPGRADE`, `Kit.has()`), off in the base kit and played in the rule's place with their Kit id on
(`--kit=full`, `--kit=<id>,<id>`). States last `ELEMENT_HOLD` (2 s; charged `CHARGED_HOLD` 3 s) and each payoff reads
the state, not the input that set it ([void-element.md](void-element.md), "Improvising").

Elements by base move. Storm: Updraft Lash (L H), Live Wire (L H H, L H L H). Ice: Frost Spear (L L H), Harpoon
(Dash L H), Ice Cube (Dash L H H), Deep Freeze. Magma: Molten Palm (L L L H), Undertow (L L L H H). Dark: Reap,
Black Tide, Singularity, Overwhelm, Tow Line.

## The six rules

| State (set by) | Rule | What any hit does | Not the rule (the move's own) |
|---|---|---|---|
| **frozen** (Harpoon, Ice Cube, Deep Freeze, Impale, Hailstorm, Black Ice) | **Shatter** | x`RULE_SHATTER_MULT` 1.6 (and the ice's `FREEZE_BREAK`, as any hit on it), and the ice is gone (`_break_ice()`) | ice on ice (refreezes, Ice Cube bowls the frozen first); Molten Palm (its steam: Steam Burst) |
| **charged** (Live Wire's jolts, Grounded, Storm Pitch, Galvanize, Fault Line, Cataclysm) | **Arc** | the hit, then a lime bolt path (`designed_fx.bolt_path`) on through every other charged foe within `RULE_ARC_R` 6 m of the payer, nearest from the last, `IMPROV_CHAIN_DAMAGE` 5 each; all discharged (`_arc()`) | storm: Live Wire's own pulse |
| **molten** (Meltdown) | **Burst** | x`IMPROV_MULT` 1.5, and the burn catches everyone within `RULE_BURST_R` 2.2 m for 5 (a quiet `burn_hit`, `_burst()`); spent | magma: Eruption |
| **bound** (Undertow, Overwhelm's tendrils: `floor_bind.holds()`) | **Snap** | x1.5 with no knockback, so no shield turns it and the held can't dodge; the hold ends (`floor_bind.let_go_of`) | dark: Abyss off Overwhelm; Meteor Fall is Undertow's own window |
| **airborne** (any launcher) | **Juggle** | `IMPROV_DAMAGE` 8, kept up at `RULE_JUGGLE_LAUNCH` 7 m/s (not the heavy) | storm (the air string: Air Slash, Live Wire); Tow Line (its own rip, `TOW_AIR_MULT`) |
| **buried** (Rockslide) | **Crater** | x1.5 driven back into the floor (`Vector3.DOWN * IMPROV_DOWN`); spent | Updraft Lash (`_cash_buried`: digs them up itself); Fault Line |

The "own" column is `RULE_OWN` (the element that leaves the state: the hero's own element on its own state does
the move's own thing) and `RULE_SELF` (an element or a move id that pays the state in its own body, so it never pays
twice). `improv_cell(e, el, id)` returns what pays: the upgrade cell when its id is on, else the state's rule, else "".
The skewered (Impale) are frozen too: with neither skewered upgrade on they pay Shatter.

## Upgrades (the old grid)

Off: the rule plays. On: the cell plays in the rule's place, as round 34 to round 44 built it.

| Cell | Kit id | Payoff | Instead of |
|---|---|---|---|
| frozen x storm | `gale_lift` | **Gale Lift**: the cube goes up, still in its ice (`freeze_aloft`) | Shatter |
| frozen x dark | `shard_cut` | **Shard Cut**: the ice crushed, the shards cut the nearest foe (`_chain`) | Shatter |
| buried x ice | `frozen_in` | **Frozen In**: frozen where it is stuck | Crater |
| buried x dark | `swallowed` | **Swallowed**: x1.5 crater, held `IMPROV_HOLD` | Crater |
| molten x storm | `firestorm` | **Firestorm**: launched, the flames catch the nearest foe (molten, a chain hit) | Burst |
| molten x ice | `quench` | **Quench**: steam, x`IMPROV_STEAM_MULT` 1.6, launched | Burst |
| molten x magma | `flare_up` | **Flare-up**: the floor erupts under it (x`ERUPT_MOLTEN_MULT`) | nothing (own) |
| molten x dark | `smother` | **Smother**: x1.5, a crater | Burst |
| skewered x ice | `ice_spreads` | **Ice Spreads**: the nearest foe frozen and skewered too | nothing (own) |
| skewered x dark | `torn_off` | **Torn Off**: x1.5, yanked off the spear towards him | Shatter |
| airborne x ice | `freeze_aloft` | **Freeze Aloft**: frozen up there, comes down a cube | Juggle |
| airborne x magma | `meteor_spike` | **Meteor Spike**: driven down into a crater, x1.5 | Juggle |
| bound x storm | `torn_loose` | **Torn Loose**: out of the bind and launched, x1.5 | Snap |
| bound x ice | `frozen_dark` | **Frozen in the Dark**: frozen where they're held | Snap |
| charged x storm | `overload` | **Overload**: every charged foe within `OVERLOAD_R` 8 m of the move goes off at once, chained, each x(1 + `OVERLOAD_PER` 0.35 per other charged) | nothing (own: Live Wire's pulse) |
| charged x ice | `superconduct` | **Superconduct**: x1.5 and frozen, the charge runs on through every frozen foe within `SUPER_R` 7 m (`SUPER_DAMAGE` 6 each, charged) | Arc |
| charged x magma | `arc_flash` | **Arc Flash**: x1.5, everyone within `FLASH_R` 2.8 m blown `FLASH_THROW` 4.5 m away (`FLASH_DAMAGE` 5, `FLASH_SPLAT` 6 where they land, x `PALM_WALL_MULT` on a wall) | Arc |
| charged x dark | `conduct` | **Conduct**: the payer stays charged, the charge goes on to every uncharged foe within `CONDUCT_R` 3 m (`CONDUCT_MOST` 4, `CONDUCT_DAMAGE` 5 each) | Arc |

buried x magma (Aftershock) was a crater already: it is the Crater rule now, not an upgrade. The cells the moves
paid themselves (Ice Cube on the frozen, Molten Palm's steam, `_cash_buried`, Backdraft hauling the skewered, the air
string, Tow Line's rip, Meteor Fall, Abyss) were never cells and are unchanged. Every id has its doc line in
`kit.gd` `UPGRADES`.

### Looks

Each rule has **one** tell keyed by the state, tinted by the element that hit (`comic_improv.gd` `LOOKS` with
`rule`, `spawn(..., hitter)`; designed mode `designed_polish.improv(..., hitter)`), and its word
(`ComicFx.IMPROV_WORDS` by state). Real time, gone by 0.35-0.45 s. The upgrade cells keep their own looks and words
(the table in round 37's notes below).

| Rule | Look | Word |
|---|---|---|
| Shatter | the ice shattering, a pop in the hitter's colour | SHA-KRASH! |
| Arc | a pop in the hitter's colour, the current crawling on it; the lime bolt path on through the charged | ZZAK-ZAK! |
| Burst | magma spurting up under it, a pop and a shock line in the hitter's colour out to the burn | FWOOMPH! |
| Snap | a violet pop at its feet (the hold), a hit star in the hitter's colour | SNAP! |
| Juggle | a hit star and speed strokes up, in the hitter's colour | WHAP-UP! |
| Crater | the crater heaving, a shock line in the hitter's colour | KA-THOOM! |

Upgrade cells' looks (round 37 / 44, unchanged): Gale Lift FWISSH! (wind bands round the cube), Shard Cut SHA-KRAK!
(violet tear, plates, one at the foe it cuts), Frozen In KRRIK!, Swallowed GULP!, Firestorm FWAAASH!, Quench HSSSSK!,
Flare-up FWUMP!, Smother SMOOSH!, Ice Spreads KRIK-KRIK!, Torn Off RRRIP! (`comic_rip`), Freeze Aloft FRZZK!, Meteor
Spike KA-CHUNK!, Torn Loose SNAPP!, Frozen in the Dark KLINNK!, Overload ZZRAAAK!, Superconduct KRZZZK!, Arc Flash
FWA-KOOM!, Conduct BZZT-ZAP!.

Charged is last in `IMPROV_ORDER`: nearly every Live Wire leaves it, so it pays only when nothing rarer is there.
Live Wire marks the foes it zapped only when the hang ends (`void_grab._charge_jolted`), so the crackle tell isn't
drawn over the held pile; Short Circuit (Grounded's L ending) spends the held foes' charge and moves it into the
ones it arcs to. The training bot clears states at the start of each string (`_reset_spots`). Foes carry their
states visibly (`comic_state_tell.gd`).

## Files

| File | Role |
|---|---|
| `scripts/void_element.gd` | `RULES`, `RULE_NAMES`, `RULE_OWN`, `RULE_SELF`, `RULE_*` numbers, `IMPROV` (the upgrade cells' kinds), `IMPROV_UPGRADE`, `IMPROV_ORDER`, `improv_cell()`, `improv_name()`, `improvise()`, `improv_reach()`, `_pay()`, `_arc()`, `_burst()`, `_break_ice()`, the cells' `_chain()` / `_conduct()` / `_superconduct()` / `_arc_flash()` / `_overload()`; `fire()` calls `improvise()` and then `_fire()` (the move) |
| `scripts/kit.gd` | `UPGRADES`: every cell's id and doc line; `Kit.has()`, `set_on()` |
| `scripts/comic_improv.gd` | The tells: `LOOKS` (the six rules keyed by state, each borrowing a cell's drawing, tinted; the cells), one draw function per cell on `comic_flat.gd`; `spawn()` from `_pay()` (comic style only) |
| `scripts/designed_polish.gd` | `improv()`: the designed tells (the default), the six rules first |
| `scripts/comic_fx.gd` | `IMPROV_WORDS` by rule state and by cell, `improv()` (once a move), the move's own word held `IMPROV_HOLD_MS` after it |
| `tests/improv_shots.gd` | Look (windowed): each rule, then each upgrade cell with its id on, played for real on the dummies, six crops 83 ms apart (`--alone`, `--only=frozen,charged,frozen_x_void`) |
| `scripts/floor_bind.gd` | The "bound" state: `BOUND` meta while a bind holds a foe, `holds()`, `let_go_of()` (Snap, Torn Loose) |
| `scripts/move_list.gd` | The MIX ELEMENTS page: the six rules (`state`, `rule`), then the upgrade cells (`state` / `el` / `upgrade`); `mix_name()` |
| `scripts/hero_moves.gd` | `pays()`: the payoff a guide row's move would cash in now (`improv_cell()` / `improv_name()`: the combo guide's "+ Shatter", "+ Overload" tag) |
| `scripts/training_bot.gd` | Six bot strings reach a rule each (tokens `face`, `out`, `wait`, `spread`); `improv_line()` prints `[improv]` |
| `tests/void_arm_check.gd` | `_element_matrix()`: the six rules on a stand-in foe for every element, the own pairs left alone, each upgrade cell on and off, the arc past the move's reach, Overload, Superconduct, reach shapes, a whole Harpoon cashing in `buried` |

## How it works

1. `fire()` (a move's first hit) calls `improvise(hero, id, at, power, fwd)` first. Only base element moves improvise
   (`ELEMENT_OF`, not `X*`: the crossovers read their own states in their bodies).
2. It collects the foes the move itself lands on (`improv_reach()`), skips anyone in flight (`THROWN.flying`), and asks
   `improv_cell()` for each: the first state in `IMPROV_ORDER` the foe is in that has an upgrade cell on for this
   element, or a rule this element and move don't own. Every foe is read before any pays, so a chain that sets a
   state on the neighbour doesn't pay again in the same move.
3. `_pay()` spends `buried` / `molten` / `skewered` / `charged` (once) and runs the kind: a rule (`shatter`, `arc`,
   `burst`, `snap`, `juggle`, `crater`) or a cell's (`lift`, `shards`, `encase`, `swallow`, `fan`, `quench`, `erupt`,
   `smother`, `spread`, `tear`, `freeze`, `spike`, `loose`, `conduct`, `superconduct`, `flash`, `overload`).
4. Then the move itself runs (`_fire()`). A payoff never throws the foe that pays (`THROWN.launch`), so the move
   can still throw it. Arc Flash throws the ones beside it.

**Reach = the move's own hit shape** (`improv_reach()`, read before the move fires, from the move body's own
numbers):

| Move | Who its payoff reaches |
|---|---|
| Updraft Lash (EC) | the gale's circle, `CUTTER_RADIUS` x the chain's grow, `CUTTER_AHEAD` in front of him |
| Live Wire (EE, EW) | whoever the tentacles reach (`void_grab.reachable()`, `SEIZE_RANGE`) |
| Ice Cube (EA) | the nearest within `BOWL_REACH` and the roll ahead of it (`BOWL_LENGTH`, `IMPROV_ROLL_HALF_WIDTH` 1 m either side) |
| Harpoon (EF) | everyone its tentacles take (round 47: `harpoon_targets()`, `HARPOON_REACH` 8 m round him, nearest `HARPOON_MAX` 5) |
| Frost Spear (IP) | the frost round where the spear goes in (`frost_spear.RADIUS`) |
| Vault (IJ) | nobody: it hits nothing |
| Deep Freeze (IS) | the frost ring round the spear (`DEEP_FREEZE_RADIUS`) |
| Molten Palm (EM) | the fist's lava line (`PALM_LENGTH`, `PALM_HALF_WIDTH`) |
| Undertow (EV) | `UNDERTOW_RADIUS` round him, and whoever the palm shoved within `UNDERTOW_CHASE` |
| Singularity (VS) | the hole where the slam lands (`dark_fx.Hole.RADIUS`) |
| Reap (VR) | the crescent: `REAP_REACH`, `REAP_HALF_ANGLE` either side of his aim |
| Black Tide (VD) | the marked within `TIDE_REACH`, else `TIDE_NEAR` round him |
| Overwhelm (OW) | the pool on whoever he aims at (`_overwhelm_spot()` = `overwhelm_aim()`'s foe, `OVERWHELM_RADIUS`) |
| Tow Line (TW) | the line he just dashed along (`_tow_line()`) |

Every base id has its arm (`improvise()` returns first for the `X*` ids and anything not in `ELEMENT_OF`), so there
is no fallback shape.

The arc rule and the upgrade cells' chains go on past the move's shape (that is their point); only the payer must
be in it. Breakers don't improvise (they read their own states in `breaker_impact()`).

## Invariants

- Six rules, one per state; a new element or character maps onto them and adds no cell. A richer per-element payoff
  is an upgrade (an `IMPROV_UPGRADE` id with a `Kit.UPGRADES` line), never a new base cell.
- The state's own element (`RULE_OWN`) and a move that pays the state in its body (`RULE_SELF`) never pay the rule,
  or the state pays twice. `_element_matrix()` checks improvise leaves them.
- Knockback directions follow the foe contract: craters pass `Vector3.DOWN * IMPROV_DOWN`; Snap passes none.
- A payoff hits on ice x `FREEZE_BREAK` like any hit, and the hit thaws it; ice cells (`encase`, `freeze`, `spread`)
  hit first and freeze after.
- Bosses never freeze (`encase`, `freeze_aloft`) and the heavy aren't launched (Juggle, the launching cells).
- A payoff lands only where the move does: a foe inside 5 m of him but outside the move's shape never pays.

## Tuning

Rules: `RULE_SHATTER_MULT` (1.6), `RULE_ARC_R` (6 m), `RULE_BURST_R` (2.2 m), `RULE_JUGGLE_LAUNCH` (7 m/s),
`IMPROV_DAMAGE` (8), `IMPROV_MULT` (1.5: Burst, Snap, Crater), `IMPROV_CHAIN_DAMAGE` (5: each arc link and burn),
`IMPROV_DOWN` (6 m/s). Cells: `IMPROV_ROLL_HALF_WIDTH` (1 m), `IMPROV_LAUNCH` (8 m/s),
`IMPROV_CHAIN_R` (2.6 m), `IMPROV_PULL` (6 m/s), `IMPROV_STEAM_MULT` (1.6), `IMPROV_HOLD` (0.6 s); charged cells
`CONDUCT_*`, `SUPER_*`, `FLASH_*`, `OVERLOAD_*` (the upgrades table).

## Extending

- A new state: no. Map it onto one of the six (a plant's "rooted" is bound, a blood character's "bleeding" is molten).
- A new character's element: say which state it leaves (its `RULE_OWN`), and it pays every other state's rule for
  free. A move that pays a state in its own body goes in `RULE_SELF`.
- A richer cell: a kind in `_pay()`, an `IMPROV` entry, an `IMPROV_UPGRADE` id, a `Kit.UPGRADES` line, a look in
  `comic_improv.LOOKS` / `designed_polish.improv`, a word, a MIX ELEMENTS row and a case in `_element_matrix()`.

## Testing

- `godot --headless --path . -s tests/void_arm_check.gd`: `_element_matrix()` prints `element matrix: 18 rule pairs,
  18 upgrade cells on and off` (PASS/FAIL).
- `godot --headless --path . -- --autotest`: `[improv] bound=1 molten=3 buried=3 frozen=3 airborne=4 charged=4`, each
  rule from its bot string: frozen `line D L H D H` (Tow Line shatters Harpoon's ice), buried `face L H L L D L H`
  (Harpoon craters Rockslide's buried), airborne `face L H D L H` (Harpoon juggles), molten `line out face D L H H H L
  D wait L H` (Updraft Lash bursts Meltdown's molten), bound `out face L L L H H D wait L H` (Updraft Lash snaps
  Undertow's hold), charged `spread H L L wait H L` / `wait L L L H` / `wait L L H` (Reap, Molten Palm, Frost Spear arc
  Galvanize's charge; `wait L H` is storm's own).
- `godot --headless --path . -- --autotest --kit=full` (the second run in `agent.sh check`): the rules give way to
  the cells, `[improv] bound=0 molten=0 buried=0 frozen=0 airborne=1 charged=0 | ice_spreads=0 torn_off=0
  firestorm=1 quench=0 flare_up=0 smother=0 frozen_in=3 swallowed=0 torn_loose=1 frozen_dark=0 gale_lift=0
  shard_cut=3 freeze_aloft=3 meteor_spike=0 conduct=3 superconduct=4 arc_flash=2 overload=1`.
- Contact sheets per rule: `awaken-combo-clips/32 Matrix <n> <state> rule - <name>.png` (string_film of those strings).

## Gotchas / open questions

- Snap's "undodgeable": a held foe can't start a dodge and a hit with no knockback never meets a shield; a foe
  already mid-dodge (`enemy.State.DODGE`) still takes nothing, as every hit (enemy.gd is the counter lane's).
- "marked" (Reap's mark) is not a state here: it is the signature's own setup (Black Tide, Galvanize); the bound
  half of marked/bound is the state.
- Gale Lift is not a slot move, so it went to the upgrades (kit-grammar section 3 suggested a crossover home).
- `buried` stays Updraft Lash's own (`RULE_SELF`) while `_cash_buried` digs them up. Rockslide's buried payoff stays
  in the base kit (kit-slots, round 49), so the buried state and its Crater rule play without `--kit`.
- `Kit.set_on(id, false)` can't turn one off under `--kit=full` (it reads `_all`): the tests run without `--kit`.
- Meteor Spike's falling line hides under Molten Palm's stars when the move plays; its word and dent carry it.
- Coverage per crop (round 37 numbers, cells): 0.04-0.15 alone, at most 0.27 with the move's own hit.
- **Read every state before paying any.** A chain that marks the neighbour `molten` / `skewered` made it pay in the
  same move and chain back ("spent once" failed): collect `[foe, state]` first, then pay. Leave out the cells a move
  already pays itself, and have the check assert `improvise()` returns 0 on those.
- **A payoff's reach is the move's own shape** (`improv_reach()`): a test that puts a foe behind him inside the old
  radius must fail on the old code. Zero `Game.combo_count` in such a test: the chain's `hero_fx.cast_grow()` swells
  Updraft Lash's gale circle until it reaches behind him.
- **Dummies launch at 0.55** (`training_dummy.LAUNCH_SCALE`, `MAX_HEIGHT` 3) and hide a real foe's arc: tune air
  timing on `enemy.launch_speed_for()` and `AIR_GRAVITY` / `HANG_*`, then check the dummy still reads (Hailstorm
  12 m/s was 5.3 m on a foe and 1.7 m on a dummy).
- **A shape change can silently drop a bot cell** (`buried_x_water` 1 -> 0 when the dash carried him past the buried):
  read `[improv]` after any reach or dash change, not only `breakers=`. The bot's `line` / `face` tokens exist for this.
- **Guide tags that read state are not routes:** `mix` / `pay` ride on a real row (guide_check compares the row's id
  and next), never as a row of their own.
