# Right click on the void arm: the tentacle, the elements and breakers

## What it does

For the comic hero (`player._void` isn't null) there are two attack buttons and no E. L is the weapon, and the count picks the element: axe storm, spear ice, hammer magma. Right click (H in the tables and the game's combo text) is the tentacle, which does that element's thing. H again goes further, and H in the slow-motion window is the breaker.

Each element treats foes differently, so lift-and-slam belongs to the storm alone:

- **Storm goes up and through:** foes go in the air and lightning runs along the tentacles.
- **Ice turns foes into objects:** they get skewered, thrown and shattered.
- **Magma goes down and apart:** they get shoved, dragged under and ripped open.
- **Dark pulls in and swallows:** no weapon first. They get dragged to one spot and something eats them.

The KayKit hero's `route()`, `BREAKERS` and `H` move are untouched.

## The kit

### Storm

| Input | Id | Name | Effect |
|---|---|---|---|
| L H | `EC` | Updraft Lash | The tentacle sweeps under them (`void_grab._tick_sweep`), a gale pulls them together and throws them up, and he rises after them. The kit's only knock-up |
| L H L | `AL1` | Air Slash | Up after them with the axe |
| L H H | `EE` | Live Wire | A tentacle on each, up to `SEIZE_MAX`, with lightning through all of them. The window opens |
| L H L H | `EW` | Live Wire | The same from the air, with two endings |

Live Wire is the hang itself: `void_grab.seized_tick` jolts every `WIRE_STEP`, so the lightning does its damage whether or not the press comes. Big foes can't be held, but the lightning still finds them (`reachable()`).

### Ice

| Input | Id | Name | Effect |
|---|---|---|---|
| L L H | `IP` | Frost Spear | Plants the spear ahead of him (`frost_spear.gd`). Frost spreads out from it and only slows. One at a time; it melts after `LIFE` |
| Dash L H H | `EA` | Ice Cube | Freezes the nearest foe and bowls it (`pierce`): whatever it passes takes the hit and freezes |
| L L H L | `IJ` | Vault | Up over the spear (`run_to_spear`) |
| L L H L H | `IS` | Deep Freeze | Comes down on the spear and it goes off: everyone on the frost takes a hit and freezes into a cube (`_deep_freeze`). The window opens |
| Dash L H | `EF` | Harpoon | A spear tip (`_tick_spear`) runs through a line of foes and reels them in, frozen together in cubes. H off it is Ice Cube |

### Magma

| Input | Id | Name | Effect |
|---|---|---|---|
| L L L H | `EM` | Molten Palm | The arm swells into a fist (`_tick_palm`) and shoves the crowd back through lava. A wall splats them (`quiet`, `wall_mult`) |
| L L L H H | `EV` | Undertow | Lava wells and tendrils out of the floor drag foes waist-deep (`floor_bind.gd`, `sink` moves `enemy.model`, not the body). It follows those Molten Palm just shoved (`shoved`, `UNDERTOW_CHASE`), taking hold where they land. Big foes are only slowed. The window opens |

### Dark

Right click with no weapon first. Dark gathers foes and swallows them, and the tentacle only starts it off. `dark_fx.gd` holds the things it makes, in flat ink and violet.

| Input | Id | Name | Effect |
|---|---|---|---|
| H | `GR` | Grab | Yanks a foe to him. Something too big drags him to it. Never goes for a pillar: that's R |
| H H | `VS` | Singularity | Heaves what it holds overhead and slams it, and a black hole opens there (`dark_fx.Hole`). It drags small foes in and slows big ones, burning all of them. The window opens |
| H L | `VR` | Reap | A crescent of darkness through everyone in front of him. It marks them (`dark_fx.mark`) |
| H L H | `VD` | Black Tide | A pool opens ahead and everyone marked is dragged across the floor into it, however far off. With nobody marked it takes who's near. Big foes hold their ground. The window opens |
| hold H | `OW` | Overwhelm | A black pool under the nearest foe in the cone, with tendrils piling on (`floor_bind.gd`). Works on big foes, which it slows instead of pinning. The window opens |
| Dash H | `TW` | Tow Line | Latches onto foes along the dash, then yanks them into each other |
| H during a swing | | Snatch | Takes a foe on the way past and carries it (`_carry_pick`, `_tick_carry`, `_drop_carry`) |

### Breakers (`VOID_ELEMENT.BREAKERS`)

| Input | Off | Name | Ending |
|---|---|---|---|
| L H H, H in window | `EE` | Grounded | Slammed down, with lightning under each |
| L H L H, H in window | `EW` | Worldbreaker | Slammed down, with magma erupting under each |
| L H L H, L in window | `EW`, its `alt` | Cold Front | Frozen solid and hurled at other foes as ice cubes |
| L L H L H, H in window | `IS` | Avalanche | A tentacle on every cube (`seize`, `press`). The press lifts them all and slams them together in the middle of where they stood (`aim_crush`, `crush_point`), landing on the frame he does, and he lands `short` of the pile. One cube comes down where it was. Anyone else within `CRUSH_RADIUS` takes `PRESS_NO_CUBE` of it. Elites in cubes go too; bosses never get a cube. Dedicated shatter damage is still to come; for now each takes the breaker's damage |
| H H, H in window | `VS` | Collapse | He comes down at the hole (`at_spot`, `short`), it falls in on itself, and everyone near is thrown clear |
| H L H, H in window | `VD` | Maw | He lands short of the pool and jaws of darkness shut on everyone in it |
| hold H, H in window | `OW` | Abyss | They sink through the floor (`ABYSS_SINK`) as he comes down, then black spikes throw them back up |
| L L L H H, H in window | `EV` | Meteor Fall | He goes up (`height`) with a tentacle on the biggest foe Undertow has (`bound`, `chased`, `rip_target`: a boss, the biggest, then whoever the palm shoved), then comes down on it inside `meteor_shell` wherever it is (`_meteor_aim`). Small foes come apart, shields come off (`rip_shield`), everyone within `RIP_SPLASH` takes some, and geysers erupt round him |

`alt` is merged over the breaker when the press was L (`_brk_alt`, `_start_dive`). The prompt shows both buttons and both names when a breaker has one (`breaker_window().alt_name`).

### Thrown foes (`scripts/thrown_foe.gd`)

`launch()` flies a foe at a spot, and its `opts` set what kind of flight it is:

| Option | Effect |
|---|---|
| `el` | What it bursts in (dark moves use `void`) |
| `pierce` | Runs through foes, hitting each once |
| `quiet` | Stops at the end instead of bursting, unless a wall stops it first |
| `solid` false | Ignores other foes |
| `tether` | Draws a tentacle to it |
| `wall_mult` | A wall splat's damage |

`VOID_ELEMENT.cube_target()` picks the spot for Cold Front: the nearest foe it wasn't holding, then another it was, then straight out. `cube_on()` is the look: a box for his throws, leaving the plain ice cylinder for other freezes. `encase()` freezes a foe and puts it in the box.

On the bench: Puppet, Knot, Maw, Meat shield, Hanging up.

## Files

| File | Role |
|---|---|
| `scripts/void_element.gd` | Routing tables (`AFTER`, `AIR_FROM`, `CHAIN`), `BREAKERS`, `fire()`, `zap()`, `breaker_impact()`, `cube_target()`, all tuning |
| `scripts/thrown_foe.gd` | A thrown foe, its cube |
| `scripts/floor_bind.gd` | Tendrils out of the floor holding foes: Undertow and Overwhelm |
| `scripts/frost_spear.gd` | The planted spear, its frost and `frost_ring()` |
| `scripts/dark_fx.gd` | The dark element's things in the world: `Hole`, `Mark`, `Pool`, `Maw`, `Splat`, `ink_drops()`, `spout()`, `reap()`, `burst()` |
| `shaders/dark_ink.gdshader`, `dark_splat.gdshader` | Churning floor ink (spiral streaks, wobbling rim, stepped time, `open`, `erode`) and the camera-facing ink burst (`progress`, stepped by `dark_fx.Splat`) |
| `scripts/player.gd` | `MOVES` and `COMBOS` rows, `void_route()`, `_breaker_for()`, `_breaker_pressed()`, the `tentacle` branches of `State.LEAP` |
| `scripts/void_grab.gd` | `reachable()`, `seize()`, `seized_tick()`, `slam_seized()`, `freeze_seized()`, `held_foes()`, `release_seized()`, `_tick_sweep()` |
| `scripts/breaker_prompt.gd` | Shows both buttons and names when a breaker has an `alt` |
| `scripts/comic_look.gd` | `HERO_MOVE_FORMS`: which weapon each move forms |
| `scripts/move_list.gd` | `VOID_SECTIONS`, `VOID_ONLY` |

## Invariants

- Void breakers stay out of `player.BREAKERS`: `move_list_check` and `comic_check` walk that table for the KayKit hero. `_breaker_for()` picks the table.
- A breaker entry is `_WINDOW` merged with its row (`entry()`).
- `leap` must be at or before the move's `cancel`.
- Every exit from the hang lets go: no press, dash out and `_end_leap` all call `release_seized()`. The tendrils stay in `_spare` for the next one.
- `_end_leap` clears `_buffered` for this hero, or the press that dove him would also start a move.
- Damage comes from `fire()`. The move's own blow in `MOVES` is small or none, and `fire()` returning above 0 counts as connecting.
- `fire()` runs once per move, on its first hit.
- A tentacle breaker rises from the height he's at (`_brk_y0`), so one off the air string doesn't pop to the floor.
- Re-stagger held foes every `RESTAGGER`, not every frame: each stagger flashes them white. It must stay under the 0.4 s a hit's stagger lasts, or a zapped foe wakes up in the tentacle's grip.
- A freed foe can reach `thrown_foe.launch()` and `remove_cube()` through a delayed call, so those arguments stay untyped: a typed argument errors before the validity check runs.
- These moves skip `_swoosh` and the weapon trail. All of them land on him and hid what the tentacle was doing.
- `AL1` and `L3` skip their casts for him (`NO_CAST`): their giant axes stood in front of the tentacle move that follows.
- His element and tentacle moves skip `Fx.combo_pop` entirely, and `ComicFx` spaces words by `WORD_GAP_HERETIC_MS` for him, since these moves hit whole crowds at once.
- Maw is the test of the new effect style: the jaws rise during the dive (`player._start_dive`) and `bite()` snaps them shut on impact, so the breaker's hitstop holds the shut frame. Its hit goes through `enemy.burn_hit(damage, true)`, one word for the bite, and `Splat` and `ink_drops` in place of gold sparks. A foe killed by it still gets the normal death effect.
- On this hero a style rank climb is a thin `hoop_run`, not the soft ring and star, which sat on him and fought his effects.
- While the frost spear stands, either button vaults (`vaults()`, from `player._routed`), not only during the plant's animation: that ends before the frost has finished spreading, so a player watching it got a plain slice. `tests/void_arm_check.gd` `_spear_by_hand` plays this with real button presses.
- Black Tide's flight is capped at `TIDE_ARRIVE`: far foes fly faster, so an early Maw press can't bite before they reach the pool.
- Damage that ticks on a whole crowd (`dark_fx.Hole`, `floor_bind.gd`) goes through `enemy.burn_hit`: the damage and number with no sparks, word or flash, which buried the thing holding them.
- Tentacle breakers use the `crisp` version of `breaker_cue.gd`, thin hard rings, since they land right on that spot.
- A breaker's cue, prompt and war cry come in `_brk_color()`, what it lands in, not his axe's teal. Tentacle breakers also skip the war cry's bubble: it hid him and filled the floor.
- Tentacle breakers skip the `Fx.combo_pop` on landing, and his element moves skip the `_land_slam` ring. Avalanche also skips the crater: its ice buried the cubes as they left.
- `cube_on()` hides the plain ice cylinder every time, even on a foe already in a cube: `enemy.freeze()` shows it again on each refreeze, and `seize()` refreezes the cubes for Avalanche's window.
- Nothing else may move a foe in flight: check `thrown_foe.flying()`.
- A lava well outlasts the Undertow that made it and goes on burning whoever stands in it.
- New moves go in `VOID_ONLY`, or `move_list_check` expects `route()` to reach them.
- Clips come straight from `MOVES.anim`, as with `GR` and `VS`, so hit fractions are frame / frames of that clip.

## Tuning

Damage: `CUTTER_DAMAGE`, `WIRE_DAMAGE`, each breaker's `damage` (times `perfect_mult` 1.5 and the chain's `_cast_power()`), `thrown_foe.OTHER_MULT` and `SPLASH_MULT`. Timing: `_WINDOW` (`open`, `sweet`, `close`, `perfect`), `WIRE_START`, `WIRE_STEP`. The hold: `SEIZE_RANGE`, `SEIZE_MAX`, `SEIZE_LIFT`. The throw: `thrown_foe.SPEED`, `SPLASH`, `CUBE_HIGH`, `CUBE_SEEK`. Each move's reach, damage and time are constants at the top of `void_element.gd`, named after it (`REAP_`, `TIDE_`, `COLLAPSE_`, `MAW_`, `ABYSS_`, `HARPOON_`, `SPEAR_`, `DEEP_FREEZE_`, `PRESS_`, `PALM_`, `UNDERTOW_`, `FLAIL_`, `OVERWHELM_`, `TOW_`). R with nothing to latch onto: `void_grab.SKY_MIN`, `SKY_MAX`.

## Not done

- Clips are borrowed from other moves, so the poses are approximate until the VFX update.
- Heavy foes aren't lifted. Their answers are the lightning, Meteor Fall and Overwhelm.
- Geysers, lightning and rings are the older soft or bright effects. Only the star and chips (`heretic_form_fx.gd`) are in the flat comic style.
- The storm, ice and magma strings and R have been played by hand. The dark string has not.
- Molten Palm's fist is a rough lump until the VFX update.

## Checks

`godot --headless --path . -s tests/void_arm_check.gd` covers routing, each move hurting a foe, each breaker holding and hurting a foe and letting go, both window endings, a missed window, cubes hitting foes and walls, the ice strings including the spear, the magma strings, the dark string and its breakers, and the snatch (PASS/FAIL, stand-in foes, in `agent.sh check`).

`godot --path . -s tests/element_shots.gd` is windowed. It films each string against real foes at the game camera, through the hang and the slam, and R's swing, to `user://element_shots/`.
