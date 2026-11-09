# The void arm: right click, R, weapon shapes, grab, swing, slam

The heretic's right arm is a purple tentacle that shapes itself into his weapons. Right click sends it out, and R swings him on it (pad: left bumper). He is the only hero, so `player._void` is always set and `hero_moves.void_route()` is the only routing. There is no E any more.

## His moves

`hero_moves.void_route()` (`hero_moves.void_route()`) replaces `route()` for him (through `hero_moves.routed()`, which `_next_move` and the combo guide share). What right click does off each weapon, and the kit still to come, are in [void-element.md](void-element.md).

| Input | Move | Shape |
|---|---|---|
| L, L L, L L L | `L1`, `L2`, `L3` | axe, spear, hammer |
| L L H | `IP` | spear |
| L L H L, L L H L H | `IJ`, `IS` | bare |
| Dash L | `DL` | spear |
| H (right click) | `GR` | bare |
| H H | `VS` | bare |
| H L | `VR` | bare |
| H L H | `VD` | bare |
| hold H | `OW` | bare |
| Dash H | `TW` | bare |
| R | swing, below | bare |

The KayKit hero's moves (`LH`, `LHH`, `AL2`, `AH`, `AL3`, `LLH`, `LPL`, `H`, `CH`, `DH`), the ultimates and their breakers were removed in round 28. Q still Awakens. The pause menu lists `move_list.SECTIONS`.

## Right click from neutral

`void_grab.pick()` scores everything in a `CONE` by angle plus distance. Right click passes it no pillars.

- **Foe:** `GR` plays. The tentacle arrives at `hits[0]`, then drags the foe to `YANK_TO` in front of him. The move cancels at `cancel` into anything; H is the slam, which keeps hold of the same foe.
- **Heavy** (`is_heavy()`: radius 0.9+; no foe in play is, since the boss and elites went 2026-11-08): takes the `GR` hit where it stands. (The right-click pull that flew him to a far heavy was removed with them.)
- **Nothing:** `GR` whips to `WHIP_REACH` and plays out.

## R: the swing

`player._try_swing()` takes the press from `State.MOVE`, or from an attack once it has hit, on `SWING_COOLDOWN`. `void_grab.traverse()` looks where he's aiming, at pillars only, and runs State.SWING. Unlike the dash, none of these have invulnerability frames.

- **Pillar** (group `grab_anchors`, added in `main.gd`): kind "swing". He circles at `SWING_R` with lift, raking what he passes once each. A tap runs `SWING_MIN_ARC`; holding R runs to `SWING_MAX_ARC`.
- **Nothing:** kind "sky". The tentacle shoots to `_pivot`, `SKY_HIGH` up and off the top of the screen, as if gripping an unseen ceiling. He runs along `_dir`, steering at `SKY_TURN`, for `SKY_MIN` on a tap and up to `SKY_MAX` holding R. A wall ends it.

Any press releases early. Release flings him: `_fling_t` lowers his grip in `_state_move`, and `_post_dash_t` makes L off the fling the `DL` lunge. Dash cancels every travel state (`travel_tick`).

## The slam (`VS`)

`attack_tick` carries the foe by hand: tentacle out by `SLAM_SHOOT_END`, overhead by `SLAM_TOP_AT`, down at `hits[0]`. `slam_lands()` puts it on the floor just before `_do_hit`, so the ordinary hit loop strikes it and whatever stands near it. `slam_landed()` then adds the crater and ring. (The heavy variant, where the foe stayed put and the tentacle alone came down on it, was removed 2026-11-08 with the heavy foes.)

## Shapes

`void_arm.gd` is a `SkeletonModifier3D` on the hero's skeleton. `shape()` shows one list of `ComicLook.HERO_FORMS`, hides the axe's aura unless that's the shape, and pops `hand.r` small and back (`SNAP_*`) so the swap reads as reshaping. Moves ask for shapes through `HERO_MOVE_FORMS`; anything else is the axe, and leaving the attack states puts the axe back.

All forms are built along one grip line (`rig_comic.py`: `axe`, `hammer`, `spear` share `dirv` and `face`), skinned to `hand.r`, so any clip swings any of them. Whether it *looks* right per clip is a separate matter: `L2` and `DL` were re-keyed as thrusts for the spear (`THRUST_R`, `DASH_R`).

Each form brings its element onto the arm: `void_surge` (green storm) with the axe, `void_seep` (lava) with the hammer, `void_frost` (ice) with the spear.

## The tentacle

A reach this long can't be baked, so `void_tendril.gd` rebuilds a tube each frame from the hand to the target, in world space: `reach` runs it out, `wave` whips it, `coil` wraps its end round what it holds. It uses `P_Tendril` and the hero's ink (`Fx.ink_material()`). It's marked `no_ghost` and isn't under the model, so afterimages skip it. Since round 44 it is drawn as a designed ribbon (smooth tapered spine, authored skin with suckers, a claw tip, a tangent coil, a smear on a fast lash; `docs/features/designed-fx.md` "Round 44"); `points()` returns its world polyline for effects that ride it.

## Clips

`Ab_GR`, `Ab_VS`, `Ab_Swing` in `abilities.py`. They aren't in `HERO_MOVES`: `MOVES` names them directly and its timings are fractions of these clips, so nothing is retimed. `Ab_Swing` is a held pose.

## Not done

- Spectral casts on `L2`, `L3`, `CH`, `DL` still throw spectral **axes** whatever shape the arm is.
- The weapon trail follows the axe head's position for every form.
- The baked arm still bends like an arm: no tendril bones.
- Hand form for interactions, element movement (air gust, lava launch, ice slide), wind off the whole arm.
- The bot never presses R, so `--autotest` doesn't exercise it; `void_arm_check` does.

## Checks

`godot --headless --path . -s tests/void_arm_check.gd` (PASS/FAIL, in `agent.sh check`): routing, picking, shapes, yank, every kind of swing and fling, dash out, slam, whiff. Stand-in foes, no pixels: only playing it shows how it feels.

`vendor_src/.../unfinished_poc/form_look.py` renders each form in its clip at the game's angle, with stand-in materials.
