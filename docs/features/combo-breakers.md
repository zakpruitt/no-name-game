# Combo breakers

## What it does

A combo breaker is a timed finisher hanging off a combo ender. When the ender connects
(`_connected`; a whiff just plays out), the heretic leaps up and back with his tentacles on
what the string hit, a timing cue rings the landing, and the game drops into slow motion.
Right click (or L, for a breaker with an `alt`) inside the window dives him onto the zone and
slams what he holds; within `perfect` of the sweet spot it's a PERFECT (frame freeze, x`perfect_mult`,
more Awakening). Too early locks it out; no press floats him down; a dash in the hang calls
it off.

Which enders have breakers, and what each slam does, is the heretic's kit:
`VOID_ELEMENT.BREAKERS`, described in [void-element.md](void-element.md) (Grounded / Short Circuit, Worldbreaker /
Cold Front, Avalanche, Meteor Fall, Collapse, Maw, Abyss, and round 34's Cataclysm, Flash Freeze, Black Ice,
Eruption and Anvil). This doc is the shared machinery.

### Movement in the strings

Moves can leave the floor (`MOVES` keys, `hero_moves.hop()`; only the model lifts, the body stays):
- `hop` = [start, end, height]: an arc between those fractions of the move (L2, L3, EC, DL).
  A move started in the air comes down by its first hit (`land` overrides).
- `air`: holds the height the move started at; `climb` adds metres by its first hit (AL1
  climbs off Updraft Lash, IJ vaults 2.4 m onto the frost spear, XG Hailstorm climbs 2 m after the cubes and XM
  Meltdown holds him up there for Eruption, which rises from that height: `_brk_y0`). The climb stops at `AIR_MAX_HEIGHT`.
- Landing from a hop is a slam that grows with the fall (`land_slam()`, `SLAM_FULL_HEIGHT`,
  `SLAM_SCALE`); a move that starts in the air deals +`PLUNGE_PER_M` per metre (`plunge_mult()`).
- Moves started in the air home in on the nearest airborne foe (`air_home()`, `AIR_HOME_RANGE`, `AIR_HOME_MAX`).
- Air dash: dashing out of `AIR_DASH_FROM` (AL1) at least `AIR_DASH_MIN` up keeps his height, once
  per trip up (`AIR_DASHES`), and cuts with a spectral axe (`air_dash_cut()`, [spirit-casts.md](spirit-casts.md)).
  All of these, and their constants, are in `scripts/hero_moves.gd`.

## Files

- `scripts/void_element.gd`: `BREAKERS` (per breaker keys over the shared `_WINDOW` defaults, merged by
  `entry()`), `breaker_impact()` (each slam's effect), `breaker_element()`.
- `scripts/hero_leap.gd` (static functions over the hero; the `_brk_*` state stays on `player.gd`), with the
  `BREAKER_*` constants:
  - `entry_for(id)` (`player._breaker_for`): the merged entry when the move has one; `player._state_attack`
    starts the leap at the entry's `leap` once the move has connected.
  - `start()` (`player._start_leap`): state `LEAP`, the zone `zone` m ahead (`_clear_ahead`), `void_grab.seize()`,
    `_aim()` (`at_spot` breakers land `short` of `void_grab.dark_spot`; Meteor Fall on the best group, `VOID_ELEMENT.meteor_spot()`).
  - `tick()` (State.LEAP each frame): phase 0 rise / hang / cue / window / press, phase 1 dive (comet trail
    `_comet()`), phase 2 float down. `_pressed()` (heavy, L for `alt`, or the bot at `sweet`).
  - `_start_dive()`, `_impact()`, `_callout()`, `_dash_out()`, `_end()`.
  - `window()` (`player.breaker_window`): what the prompt reads. `player.breakers_landed`, `breaker_perfects`:
    the autotest's counts.
- `scripts/breaker_cue.gd`: the floor cue: a target ring and a closing ring that meet at `sweet`; `lock()`, `hit(perfect)`.
- `scripts/breaker_prompt.gd`: the timing circle up and to his left (the combo guide is on his right; `OFFSET`),
  filling to the sweet spot, with a mouse glyph and one chip per ending (round 43, below); on the player's own CanvasLayer.
  Round 33, part 3 (sleek HUD, `hud_ink.gd`): a see-through back disc (`BACK_ALPHA` 0.45) with halftone dots in
  the breaker's colour round the key (`DOTS_ALPHA`), a 6 px track between 1.5 px ink lines, 2 px rings, and the
  name in the words' font (Bangers, `NAME_SIZE` 18) with a thin ink outline.
- `scripts/comic_comet.gd`: the inked dive streak and landing star (`beat()` from `hero_leap._comet()`; the comet hangs off the model as the `comic_comet` meta).
- `scripts/breaker_quake.gd`: the barbaric look: `war_cry()` as the window opens, `crater()` on landing (not for
  `press` / `at_spot` breakers, which have their own), the element vents.

## How it works

1. The ender's hit lands with `_connected` and the move reaches `leap`: `_start_leap(id, entry)`.
2. Phase 0: he rises `height` m over `rise` s, hopping `back` m; at `cue` s the cue spawns on the zone.
   At `open` the window opens: `Game.hitstop()` at `BREAKER_FOCUS` time scale, camera push to
   `BREAKER_FOCUS_ZOOM`, heartbeat and war cry.
3. Presses: one in the first `BREAKER_SPILL` s is the ender's own mash (ignored); one within
   `BREAKER_EARLY` before `open` is held and fires as it opens; earlier locks it out (`_brk_ended = "lock"`).
4. A press in `open..close` is the dive: `alt` merges over the entry, the slam's set-up runs (cubes freeze,
   the maw opens, the abyss sinks, the press aims the crush), a PERFECT freezes `BREAKER_PERFECT_STOP`.
5. The dive takes `dive` s; `_breaker_impact()` calls `VOID_ELEMENT.breaker_impact()` with what the tentacles hold,
   cracks the floor, shakes, adds `awaken` / `awaken_perfect`, names the breaker and ends the leap.
6. No press by `close`: `_brk_ended = "miss"`, the held foes drop, he floats down over `fall` s.
7. Meteor Fall (`meteor`, round 42) holds nobody (`no_hold`). Each frame of the hang `_aim()` puts the cue on the
   group `VOID_ELEMENT.meteor_spot()` picks, and the press dives there: the biggest group within 12 m of the foes its Molten Palm hit (`palm_fresh`; foes the palm never touched do not draw the dive), the one Molten
   Palm just splatted on a wall winning ties and near-ties. A far group stretches the dive (`METEOR_DIVE_SPEED`).
   Round 34's three beats (the wall throw, the tentacle gather, phase 3 `_tick_beats`) are gone.

### Look

The landing's damage is one number (round 33, sleek; feel audit item 6): hits while he is in State.LEAP open
a breaker total over the middle of the pile (`comic_number.gd`, `BREAKER_SCALE` 1.15x a big number), and any
hit within `BREAKER_BEAT_S` (0.3 s real) of its last add goes into it, for at most `BREAKER_SPAN_S` (1 s), so
the thrown cubes and shoves that land a beat later add in. Check: `tests/fx_sleek_check.gd`.

The breaker draws flat and inked: the cue is always `crisp` (a paper target ring that turns gold in the
window and a closing ring in the breaker's colour, each between two ink bands, rebuilt every frame so
the band keeps its width as it closes: `CRISP_TARGET_W` 0.06 m, `CRISP_CLOSING_W` 0.075, `CRISP_INK` 0.03
since round 33's sleek pass (0.12 / 0.15 / 0.055 were the fattest shapes on a breaker's frames; at
0.16 / 0.24 / 0.07 the closing ring was a fat green hoop over every Live Wire frame), the war cry is radial
speed strokes round him and one thin inked hoop (`WAR_CRY_RING_W` 0.08 m)
under him (no shell, no glow dots, no smoke), and the dive is `scripts/comic_comet.gd`: one fat streak back
along his path (ink, element colour, hot core, at least `MIN_TAIL` m long because a tentacle breaker barely
moves him) that ends, when `comet()` stops being called, in a held-frame impact star at his feet
(`STAR_HOLD` steps). `Fx.ring` there is an inked floor hoop on twos.

## Invariants

- `leap` must be at or before the move's `cancel`, or the next input wins first.
- Every breaker is a tentacle breaker (`_WINDOW.tentacle`): `seize` / `seized_tick` / `release_seized` /
  `slam_seized` in `void_grab.gd` must all see the same held set.
- The autotest bot never dashes out of a hang (its dodge presses would throw the breakers away) and presses at `sweet`.

## Tuning

- `VOID_ELEMENT._WINDOW`: `rise`, `height`, `back`, `zone`, `cue`, `open`, `sweet`, `close`, `perfect`, `dive`,
  `perfect_mult`, `fall`. Per breaker overrides in `BREAKERS` (`damage`, `leap`, `awaken`, `awaken_perfect`, `height`, `short`, ...).
- `player.BREAKER_FOCUS` (0.6), `BREAKER_FOCUS_ZOOM` (0.86), `BREAKER_PERFECT_STOP` (0.07), `BREAKER_SPILL` (0.12), `BREAKER_EARLY` (0.12; 0.08 before round 30).
- **One window rhythm for every element** (round 30): `entry()` sets `open` = `rise` + `VOID_ELEMENT.BREAKER_HANG` (0.1),
  `sweet` = open + `BREAKER_TO_SWEET` (0.14), `close` = open + `BREAKER_TO_CLOSE` (0.32), unless a breaker sets `open`
  itself. The default rise (0.2) keeps 0.3 / 0.44 / 0.62, so Avalanche and the dark ones are unchanged; Meteor Fall's
  0.28 rise used to open 0.02 s after the top and now opens 0.38 / 0.52 / 0.70.
- Press timeline from take-off (default rise): 0-0.12 spill (ignored), 0.12-0.18 locks, 0.18-0.30 held (dives as it opens),
  0.30-0.62 the window, 0.38-0.50 PERFECT. `tests/rhythm_check.gd` prints each breaker's numbers and checks the held press.

## Extending

New breaker: add the ender to `VOID_ELEMENT.BREAKERS` (`names.spirit`, `erupt`, the keys its slam reads), add its
slam to `breaker_impact()`, add a row to `scripts/move_list.gd`, and put a string that reaches it in `main.BOT_STRINGS`
so the autotest lands it.

## Testing

- `godot --headless --path . -s tests/void_arm_check.gd`: the breakers' timing, holds and slams (PASS/FAIL).
- `godot --headless --path . -s tests/prompt_follow_check.gd`: the prompt stays on the hero, shows both endings of a
  two-ending window (LMB first, the chips running left, off him), one for a single ending, and keeps the chosen one.
- `void_arm_check` `_breaker_choice()`: real L / H presses in Live Wire's window pick Cold Front / Worldbreaker, and L
  in Grounded's picks Short Circuit (round 44 b; `_short_circuit()` checks its arcs); `move_list_check` `_check_endings()`: every ending listed, the second marked `or`.
- `godot --headless --path . -- --autotest`: prints `[autotest] combo_breaker #N <id> perfect=` per breaker and
  `breakers=N/N perfect_breakers=` on the done line (round 34: N is distinct `BREAKERS` ids landed, so an `alt` ending
  doesn't count twice; `endings=` names every ending landed, Black Ice included). The bot resets the dummies to their homes and the hero to
  `training_bot.BOT_SPOT` before each string and presses `BOT_LEAD` before each cancel point, so the run repeats
  exactly; `agent.sh check` fails unless every breaker and string landed (`breakers=11/11`, `strings=22/22` after round 34's
  third pass, which added the element matrix's three; `AUTOTEST_MAX` 80 s). A `"line"` token stands the dummies in a
  column for that string (`BOT_LINE_FROM`, `BOT_LINE_GAP`); `[improv]` counts the matrix payoffs the bot reached.
- Windowed: `godot --path . -s tests/breaker_prompt_preview.gd` → `user://breaker_prompt.png`; `tests/element_shots.gd`
  for each slam.

## Gotchas / open questions

- Tuned headless and in stills; the window's length and the slam's weight still want a hand play-test.

## Round 34, fourth pass: the last long beats

Bot `[rhythm]` beats (first hit to first hit), before -> after, contact frames unchanged:

| Beat | Was | Now | Lever |
|---|---|---|---|
| Updraft Lash -> Air Slash | 307-385 ms | 232-295 ms | `AL1_SPEED` 1.25 (the cut lands 173 ms in, was 216) and `EC_CONFIRM` 0.8 (the lash's hit-confirm) |
| L1 -> L2 (unawakened) | 311 ms | 280-292 ms | `L2_SPEED` 1.15: 204 ms in, still longer than L1's 196 (rhythm_check) |
| a move -> Dash Stab off a dash | 510-534 ms | 444-449 ms | `DASH_STAB_CANCEL` 0.5: a dash that cancelled a move (`player._dash_out`) hands over to a buffered light at half its 160 ms |

A fresh dash (from standing) still runs its whole `dash_time` before Dash Stab, so the D L openers are unchanged.

## Round 41 (feel audit 2 items 5 and 10): Dash Stab lands, and hands over sooner
Dash Stab and Harpoon read soft (x1.00 on their HIT frames) because they whiffed: the dash and the 16 m/s stab carried
him through a foe 2-3 m ahead, so the stab cut air and Harpoon fired at nobody (the lash cast's hits hid it in the
combo count). Now:
- **The dash arrives** (`hero_input.dash_hands_over`): a dash with a light buffered ends once a foe ahead
  (`DASH_ARRIVE_ARC` 35 deg) is inside `DASH_ARRIVE` 2.8 m, after at least `DASH_ARRIVE_MIN` 0.25 of it.
- **The stab brakes** (`hero_moves.brake`, `"brake"` in DL): it lunges only far enough to have the foe it aims at
  `DASH_STAB_BRAKE` 0.6 of its range ahead at the hit (never under `DASH_STAB_MIN_LUNGE` 3 m/s; a foe beyond the full
  lunge keeps it). Connected, it gets the stop, the tier-1 kick and punch and the star like any named hit.
- `DASH_STAB_STOP` 0.06 (a light), `HARPOON_STOP` 0.07 (a mid), `DASH_STAB_CONFIRM` 0.8, `DASH_STAB_CANCEL` 0.5 -> 0.4.

| Hand-over (bot gap, move start to start) | Was | Now |
|---|---|---|
| Updraft Lash / Rockslide -> Dash Stab (a dash out of a move) | 405-421 ms | 326-406 ms |
| Dash Stab -> Harpoon (connected) | 432-435 ms | 282-312 ms (343-370 on a line) |

Tow Line off a dash still waits out the whole dash (EF -> TW 457-526, IP -> TW 479-482): handing it over at
`DASH_STAB_CANCEL` too made it 371-411 ms but shortened its line, and the bot's frozen x dark cell went 3 -> 0.

## Round 34, third pass: air timing and the hold's `reel`

- A breaker entry with `reel` (Anvil) has `void_grab.seize()` lift each foe at a spot `reel` of the way from where it
  stood to `ANVIL_REEL_GAP` in front of him, so phase 0's haul pulls them in. Use it when the move before the leap
  throws foes the leap comes too soon to show (the foe's hit freeze eats the first ~0.1 s of any knockback).
  With `reel` the foes also take a slot across his aim (`ANVIL_SPREAD` apart, sorted by where they stand so the
  tentacles don't cross), and the dive adds `fan * SEIZE_IN` to the landing so the slots survive the pull in.
- Air strings: size a launch against the hero's height at the next hit, not the room. Hailstorm's 12 m/s flew a real
  foe past him (training dummies launch at `LAUNCH_SCALE` 0.55 and stayed under him); 9 m/s puts it in its apex hang
  at his ~2.5 m as Meltdown lands. Probe heights per physics frame (hero `global_position.y + model.position.y`,
  each foe's y, flat distance, airborne, frozen) before judging the film.

## Round 42: Meteor Fall dives on the group

Zak: Meteor Fall shouldn't slam everyone into the nearest wall with the tentacles and then regather them; every
combo should have a best situation, and a player using them on purpose should be strong. Molten Palm (L L L H) is
the punch-a-group-into-a-wall move (x2.5 on the splat); its breaker Meteor Fall (L L L H H, H) now just dive-bombs
the biggest group in reach, so the flow is: punch them into the wall, then drop on the pile at the wall. Numbers:
group = foes within `METEOR_PILE_R` 3 m of each other, a wall-splatted foe (last 3 s) counts 1.5, the landing hits
everyone in 3 m, x1.3 on the freshly splatted, x1.5 on big ones (perfect x1.5 as every breaker). Check:
`void_arm_check` `_meteor_target()` (stray vs group, splatted vs equal group, bigger group vs splatted stray, empty)
and the palm -> Undertow -> meteor run that dives past a nearer foe onto the splatted one.

### Round 42 e: the palm reaches the wall

The training room is ~32 m across and the palm's 6 m shove never reached a wall, so the flow never showed there.
Molten Palm now carries a foe on to a wall within `PALM_WALL_REACH` 10.5 m behind it (past that, the plain 6 m
shove), and Meteor Fall looks for a fresh splat up to `METEOR_SPLAT_REACH` 17 m away (other groups: 12 m, unchanged).
Chosen over pillars or a wall segment in the training room: geometry there would also catch every other string's
throws (Ice Cube's 12 m bowl, Fault Line, Storm Pitch) and the bot's layout, and a palm that seeks a nearby wall
works in any room. Films: `tests/string_film.gd -- --from=11 --to=11 --layout=wall` (three of four carried ~6.5 m into
the back wall for ~37 each, then the meteor lands on them for ~150 each) and `--layout=stray` (one splatted alone,
three bunched to the side: the cue and the dive go to the three). The splat lands ~9.5 m up-screen of him, at the top
edge of the frame for a beat; the hang and the dive keep hero and target in frame. Checks: `void_arm_check` (a wall
9 m behind: carried and splatted; no wall: 6 m; a splat past 12 m still a target, not past 17 m).

## Round 43: the window shows every ending

Zak: "make sure the indicator shows each option for the player to choose. We can later incentivize people to do one
or the other based on items and game mechanics, but still have environmental."

### What the prompt shows

`hero_leap.options(hero)` lists the endings the breaker in play offers, left button first: `{button, name, element,
color}` per ending, `color` = the element's `fx_palette` body (`PAL.of(erupt).body`). `window()` passes it as `options`
and, once the window is over, says which button `chose` it. `breaker_prompt.gd` draws from that:

- **A little inked mouse in the middle of the circle** (`_mouse()`, `MOUSE_W` x `MOUSE_H` px; it was a "RMB" key):
  each button that does something is filled in its ending's colour. Two endings: both buttons lit (Black Ice's ice
  blue on the left, Maw's violet on the right). One ending: only the right button.
- **One chip per ending under the circle** (`_chips()`): `[LMB] BLACK ICE  or  [RMB] MAW`, each a key pill (the
  combo guide's key style, its rim in the ending's colour) and the name in the words' font (`NAME_SIZE` 19) in that
  colour, on a see-through ink capsule (`CHIP_BACK` 0.55; the names sat unread on Maw's violet pool without it).
  One ending: `[RMB] GROUNDED`, the same chip. The row is centred under the circle unless it would reach more than
  `CHIP_REACH` px past the circle's right edge, toward the hero; then it ends there and runs left (`_group_l` /
  `_group_r`, which `_follow()` also keeps on screen).
- **With two endings the fill is paper** (`PAPER`) until the window turns it gold: neither ending's colour.
- **The press keeps the chosen chip** and drops the other (`_option_alpha()`); the circle and its ring flash in the
  chosen ending's colour (gold on a PERFECT). A lockout or a miss greys both.

Filmed at 1600x900 from the game camera (`tests/string_film.gd`, strings 4, 16 and 1): both chips read in every frame
of the hang, about 0.6 s real from take-off to the press, at 12 fps that is 6-7 frames with both on screen. The
combo-name callout ("BLACK TIDE") still overlaps the top of the circle, as before this round.

### The floor cue

Both two-ending pairs land on the same spot with the same reach (Worldbreaker / Cold Front at the zone ahead; Maw /
Black Ice on the pool, `MAW_RADIUS` round `dark_spot`; only where he touches down differs, `short` 4.6 vs 2.0 m),
so the cue keeps one target ring. What used to lie was its colour: the closing ring and its snap-out were the first
ending's (violet) even when L picked Black Ice. Now the closing ring alternates both colours (`breaker_cue.alt_color`,
`DASHES` 8 pieces) until he picks, and `_start_dive()` sets the cue to the picked ending's colour before `hit()`.

### Pause menu

`move_list.gd` rows for a breaker's second ending carry `"or": true`, and the MOVES panel prints them as
`or L in the window` under the first (`pause_menu.input_text()`), so the pair reads as one choice:

```
H L H, H in the window      Maw
      or L in the window    Black Ice
```

### Audit: every breaker's endings (round 43)

| Ender (input) | Id | Endings | Buttons |
|---|---|---|---|
| Live Wire (L H H) | EE | Grounded | RMB |
| Live Wire, air (L H L H) | EW | Worldbreaker / Cold Front | RMB / LMB |
| Deep Freeze (L L H L H) | IS | Avalanche | RMB |
| Undertow (L L L H H) | EV | Meteor Fall / Meteor Shower (breaker pairs) | RMB / LMB |
| Singularity (H H) | VS | Collapse | RMB |
| Black Tide (H L H) | VD | Maw / Black Ice | RMB / LMB |
| Overwhelm (hold H) | OW | Abyss | RMB |
| Fault Line (L H L L H) | XF | Cataclysm / Tempest (breaker pairs) | RMB / LMB |
| Steam Burst (Dash L H H L) | XS | Flash Freeze | RMB |
| Meltdown (Dash L H H H L) | XM | Eruption | RMB |
| Backdraft (L L H, Dash H H L) | XW | Anvil / Pinwheel (breaker pairs) | RMB / LMB |
| Harpoon, then a pause (Dash L H) | EF | Shatterstorm / Slapshot (round 47) | RMB / LMB |

Two of eleven have a second ending. No ending, number or damage changed in this round.

### Proposal: a second ending for each single-ending breaker (for Zak to pick)

Following the design review's setup-vs-payoff pairing (`docs/design-review-2026-11-05.md`, section 2 and top-ten
items 3 and 4): one ending of a pair is the **payoff** (ends the fight: big damage, a crater, a wall splat) and the
other the **setup** (leaves the pile in a state the next string cashes in: frozen, stunned, up in the air, bound).
A suggested convention: **RMB = payoff, LMB = setup**, which Maw / Black Ice already fit once Black Ice keeps them
frozen instead of shattering (the review's proposal). Items and mechanics can then weight one side (a relic that
pays on frozen foes pulls players to LMB). Environmental payoffs stay: Molten Palm into Meteor Fall's wall pile,
Collapse's throw into walls, and any proposal below that uses a wall or pillar keeps it.

| Breaker (now, RMB) | Its role now | Proposed LMB ending | Role | Notes |
|---|---|---|---|---|
| Grounded | payoff (slam, lightning under each) | **Short Circuit** (built round 44 b, a different shape): he lands, the held take `SC_HELD_MULT` 0.5 and stay down, and the charge arcs out one after another (`SC_STEP` 0.06 s, a longer hit stop each link) to up to `SC_ARCS` 8 foes NOT held within `SC_REACH` 12 m, 0.75 of the damage x (1 + 0.15 per other held), a stagger, and charged | reach | Best when the room is full past the tentacles' reach (`SEIZE_RANGE` 8 m, `SEIZE_MAX` 5); Grounded bursts the held group. Bot string `spread far alt L H H` |
| Worldbreaker / Cold Front | already two | (Cold Front could become the setup: the cubes stay frozen where they land) | setup | Today both are payoffs |
| Avalanche | payoff | none proposed | | Not to be touched |
| Meteor Fall | payoff, environmental (the wall pile) | **Slag Pin**: he lands short and a ring of lava pins the pile against the wall, burning (molten + bound) | setup | Keeps the wall: the pile stays on it for a second string |
| Collapse | payoff, environmental (throws everyone into walls) | **Event Horizon**: the hole holds instead of falling in, pulling everyone tight to its middle | setup | A gather to feed a crowd string; Collapse keeps the wall throws |
| Maw / Black Ice | already two | (Black Ice as the setup: leave them frozen, no shatter) | setup | The review's pair |
| Abyss | payoff (one big foe) | **Sinkhole**: the foe stays sunk waist-deep, bound, for the next string | setup | The review's "execute" stays on RMB |
| Cataclysm | payoff (craters) | **Updraft**: the gale throws them back up off the strike, so an air string goes on | setup | The review's "bounce" extender, so it isn't a third crater |
| Flash Freeze | setup loop (they land frozen) | **Scald**: the steam goes off instead, everyone held burns hard | payoff | Here the existing ending is the setup; with the convention it would move to LMB |
| Eruption | payoff (floor goes up) | **Ash Rain**: they go up burning and hang, for an air string | setup | |
| Anvil | spread payoff (a crater each) | **Kebab Throw**: the frozen kebab is hurled into the nearest wall or pillar (wall splat) | payoff, environmental | An environmental pair: Anvil in the open, the throw near a wall |

Each new ending needs its keys in `BREAKERS[...].alt`, a branch in `breaker_impact()`, an `or` row in `move_list.gd`
and a bot string (`"alt"`) so the autotest lands it; the prompt and the cue need nothing.


## Breaker pairs: a second ending only where it is compelling

Zak: "start refining the breakers to be really flashy and awesome. existing ones are good but offer two breaker
options", then "NOT everyone needs a dual, but only when its truly compelling and awesome." Each candidate from the
proposal above was ranked by how distinct, flashy and clear its best situation would be; only the top ones were built.
Convention kept: RMB the existing ending, LMB the new one. Each new ending has its keys in `BREAKERS[...].alt`, a branch
in `breaker_impact()`, its look in `scripts/breaker_alt_fx.gd` (designed sheets only), a word (`ComicFx.BREAKER_WORDS`),
an `or` row in `move_list.gd`, a bot string, and `void_arm_check` `_breaker_pairs()` asserts it beats its sibling in its
best situation and loses in its worst. The autotest's done line has `endings_n=N/N` (every name a window offers, each
`alt` included), and `agent.sh check` fails unless every ending landed (Cold Front had no bot string until this lane).

| Breaker (RMB) | New LMB ending | Best situation for LMB / for RMB | void_arm_check (bot press at sweet, PERFECT) |
|---|---|---|---|
| Meteor Fall | **Meteor Shower**: a fireball out of the sky on every foe the palm hit, wherever it went; leaves them molten | the palm scattered them / the palm piled them on a wall | 4 scattered: shower 310 vs fall 175; 3 piled on a wall: fall 628 vs shower 336 |
| Anvil | **Pinwheel**: the tentacles whirl the kebab round him in a twister and hurl it into the nearest wall or pillar | a wall or pillar within 10 m / the open | wall: pinwheel 519 vs anvil 406; open: anvil 406 vs pinwheel 152 |
| Cataclysm | **Tempest**: a twister on the pile takes everyone near up its column, and bolts blast each out in turn, harder for every other one in it | a crowd (four or more) / a few | five: tempest 666 vs cataclysm 524; two: cataclysm 209 vs tempest 144 |

Skipped, single on purpose (each stays one ending):

- **Avalanche**: Harpoon's Shatterstorm / Slapshot already are the two things to do with a row of cubes (thunder where
  they stand, a punch into the wall); a third cube ending would repeat one of them, and the proposal said leave it.
- **Collapse**: Event Horizon (the hole holds them tight) is a pause, not a beat, and a gather Singularity's own hole
  already does; Collapse's throw into the walls is the environmental payoff.
- **Abyss**: Sinkhole (left sunk, bound) is Abyss without its spikes, and Overwhelm's job is one big foe, so there is
  no second situation for it to win.
- **Flash Freeze**: Scald (the steam goes off for damage) is the same landing on the same held foes with a bigger
  number; nothing about where they are or what they are picks it.
- **Eruption**: Ash Rain (they hang burning) repeats Eruption's launch, and Meteor Shower now owns fire from above.

Bot strings: `spread alt L L L H H` (Meteor Shower), `wall alt L L H D H H L` (Pinwheel), `alt L H L H` (Cold Front).
