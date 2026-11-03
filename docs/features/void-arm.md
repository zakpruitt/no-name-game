# The void arm: E, weapon shapes, grab, swing, slam

The comic hero's right arm is a purple tentacle that shapes itself into his weapons. E (pad: left bumper) sends it out. All of this is the comic hero only: `player._void` is null on the KayKit hero, and `route()` and the checks that walk it are untouched.

## His moves, for now

`player.void_route()` replaces `route()` for him (through `player._routed()`, which `_next_move` and the combo guide share). The set is deliberately small while E's place in the moveset is worked out.

| Input | Move | Shape |
|---|---|---|
| L, L L, L L L | `L1`, `L2`, `L3` | axe, spear, hammer |
| H | `H` | axe |
| hold H | `CH` | hammer |
| Dash L, Dash H | `DL`, `DH` | spear, axe |
| E from neutral | `GR` (or travel, below) | bare |
| E off any move | `VS` | bare |
| L L L E | `VS`, named `SHAPEBREAKER` | bare |

Unreachable for him until they're brought back: the launcher and air string (`LH`, `LHH`, `AL1`, `AL2`, `AH`, `AL3`), `LLH`, `LPL`, the Awakened ultimates (`SKY`, `RUSH`, `AF`), the breakers on those moves, and any power hooked only to them. Q still Awakens. The pause menu lists `move_list.VOID_SECTIONS` for him (`sections_for()`).

## What E does

`void_grab.pick()` scores everything in a `CONE` by angle plus distance; a pillar pays `ANCHOR_HANDICAP`, so a foe wins a near tie.

- **Foe:** `GR` plays. The tentacle arrives at `hits[0]`, then drags the foe to `YANK_TO` in front of him. The move cancels at `cancel` into anything; E is the slam, which keeps hold of the same foe.
- **Heavy** (`is_heavy()`: boss, elite, or radius 0.9+), further than a short reach: State.SWING, kind "pull". He flies to it and arrives in `L1`. A heavy already in reach just takes the `GR` hit.
- **Pillar** (group `grab_anchors`, added in `main.gd`): State.SWING, kind "swing". He circles at `SWING_R` with lift, raking what he passes once each. A tap runs `SWING_MIN_ARC`; holding E runs to `SWING_MAX_ARC`, so release picks the direction. Any press releases early. Release flings him: `_fling_t` lowers his grip in `_state_move`, and `_post_dash_t` makes L off the fling the `DL` lunge.
- **Nothing:** `GR` whips to `WHIP_REACH` and plays out.

Dash cancels every travel state (`travel_tick`).

## The slam (`VS`)

`attack_tick` carries the foe by hand: tentacle out by `SLAM_SHOOT_END`, overhead by `SLAM_TOP_AT`, down at `hits[0]`. `slam_lands()` puts it on the floor just before `_do_hit`, so the ordinary hit loop strikes it and whatever stands near it. `slam_landed()` then adds the crater and ring. A heavy stays put and the tentacle alone comes down on it (`_move.range` grows to reach it). Off `L3` it is `SHAPEBREAKER`: tier 3, `STRING_SLAM_MULT` damage, bigger crater.

## Shapes

`void_arm.gd` is a `SkeletonModifier3D` on the hero's skeleton. `shape()` shows one list of `ComicLook.HERO_FORMS`, hides the axe's aura unless that's the shape, and pops `hand.r` small and back (`SNAP_*`) so the swap reads as reshaping. Moves ask for shapes through `HERO_MOVE_FORMS`; anything else is the axe, and leaving the attack states puts the axe back.

All forms are built along one grip line (`rig_comic.py`: `axe`, `hammer`, `spear` share `dirv` and `face`), skinned to `hand.r`, so any clip swings any of them. Whether it *looks* right per clip is a separate matter: `L2` and `DL` were re-keyed as thrusts for the spear (`THRUST_R`, `DASH_R`).

Each form brings its element onto the arm: `void_surge` (green storm) with the axe, `void_seep` (lava) with the hammer, `void_frost` (ice) with the spear.

## The tentacle

A reach this long can't be baked, so `void_tendril.gd` rebuilds a tube each frame from the hand to the target, in world space: `reach` runs it out, `wave` whips it, `coil` wraps its end round what it holds. It uses `P_Tendril` and the hero's ink (`Fx.ink_material()`). It's marked `no_ghost` and isn't under the model, so afterimages skip it.

## Clips

`Ab_GR`, `Ab_VS`, `Ab_Swing` in `abilities.py`. They aren't in `HERO_MOVES`: `MOVES` names them directly and its timings are fractions of these clips, so nothing is retimed. `Ab_Swing` is a held pose.

## Not done

- Spectral casts on `L2`, `L3`, `CH`, `DL` still throw spectral **axes** whatever shape the arm is.
- The weapon trail follows the axe head's position for every form.
- The baked arm still bends like an arm: no tendril bones.
- Hand form for interactions, element movement (air gust, lava launch, ice slide), wind off the whole arm.
- The bot never presses E, so `--autotest --comic` doesn't exercise it; `void_arm_check` does.

## Checks

`godot --headless --path . -s tests/void_arm_check.gd` (PASS/FAIL, in `agent.sh check`): routing, picking, shapes, yank, pull, swing and fling, dash out, finisher, whiff. Stand-in foes, no pixels: only playing it shows how it feels.

`vendor_src/.../unfinished_poc/form_look.py` renders each form in its clip at the game's angle, with stand-in materials.
