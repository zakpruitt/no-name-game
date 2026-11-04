# The heretic hero (Meshy model)

## What it does

A second comic hero behind a flag: `--comic --heretic`, never saved. The model and texture come from Meshy; the rig, weights and clips are rebuilt here. Without the flag nothing changes.

His right arm is a bundle of five tentacles. At rest they hang free and sway. When a move asks for a weapon the old one pulls back, the new one shoots out of the limb, the loose tips coil away and the main tentacle straightens to grip the haft. They unfurl again when he stops attacking.

How to make more models like this: [meshy-pipeline.md](meshy-pipeline.md).

## Files

| File | Role |
|---|---|
| `tools/meshy_rig/heretic_rig.py` | Meshy FBX → rig blend: bones, tentacle chains traced from the mesh, skirt chains, weights |
| `tools/meshy_rig/heretic_stress.py` | Stress poses and stretch numbers on the rig blend |
| `tools/meshy_rig/heretic_bake.py` | Copies `shaman_comic.glb`'s clips and weapons onto the rig, exports the GLB |
| `assets/comic/heretic.glb` | The result |
| `scripts/heretic_rig.gd` | Modifier: sway, weapon changes, limb pose off attacks; adds the skirt's `SpringBoneSimulator3D` |
| `scripts/heretic_form_fx.gd` | The burst on a change: flat camera-facing shapes redrawn on twos. `LOOKS` holds each form's tones, star size and chips |
| `scripts/comic_look.gd` | `HERETIC`, `hero_kind()`, `PAINTED`, `painted()`, his `KIND_TONES` (weapons and the reach tube in the limb's magenta) |
| `shaders/comic_toon.gdshader` | `paint`: optional texture, white when unset, so other models don't change |
| `tests/heretic_shots.gd` | Check and pictures |

## Rebuilding

Sources live in `vendor_src/meshy/source` (gitignored). From the repo root, with Blender 5.2:

```
blender -b --factory-startup -P tools/meshy_rig/heretic_rig.py -- <rigged.fbx> vendor_src/meshy/heretic/heretic_rig_v1.blend
blender -b vendor_src/meshy/heretic/heretic_rig_v1.blend -P tools/meshy_rig/heretic_stress.py -- vendor_src/meshy/heretic/stress
blender -b vendor_src/meshy/heretic/heretic_rig_v1.blend -P tools/meshy_rig/heretic_bake.py -- assets/comic/shaman_comic.glb vendor_src/meshy/heretic/out/heretic.glb
python tools/comic_glb.py vendor_src/meshy/heretic/out heretic
godot --headless --import --path .
```

Paths must be absolute on Windows.

## The rig

- Bone names match the current hero, so `MOVES`, `HERO_MOVES` and `hand.r` lookups work unchanged. Extras: `neck`, `shoulder.*`, left `finger.*`, `tent.*`, `skirt.*`.
- `upperarm.r` to `hand.r` run along the longest tentacle (`tent.main.*` continue past it). `up` and `out` leave at the shoulder; `mid` and `low` split from `lowerarm.r`.
- The top settings in `heretic_rig.py` are per character: `TIPS`, `ARM_SPLITS`, `JOIN`, `TRIM`, the skirt values.
- Tentacle weights use distance along the surface, so a tip never takes weight from a neighbour across a gap.
- The skirt has 12 chains of 3 bones. It is fused to the thighs down to about z = 0.5 m, so that part only flexes.

## Weapon changes

`void_arm.form` says which shape is wanted (`ComicLook.HERO_FORMS`; `HERO_MOVE_FORMS` picks per move). `heretic_rig.gd` animates getting there, so `void_arm.pops` is off for him.

1. The old weapon scales down over `RETRACT_TIME` (0.05 s).
2. Below `RETRACT_FIRST` of its size, the new one grows over `GROW_TIME` (0.1 s), reaching `OVERSHOOT` of its length at `PEAK_AT`, then settling.
3. Meanwhile the loose tips coil to `COLLAPSED`, and the main tentacle bends along the haft (`GRIP`).
4. `heretic_form_fx.gd` draws the burst: an inked star at the hand, a tapered stroke and speed lines down the haft, and chips of ink and element (axe slivers, spear needles, hammer chunks). Back to `hand` it's a small magenta star and chips, with no stroke.

Each weapon has its own bone, `weapon.<form>`, from the hand to the farthest vertex (`heretic_bake.py`). It stretches along whichever local axis `_read_form` finds lying along the haft, read from the meshes at setup.

Strikes land from about 0.25 s, so a change must finish before then. Lengthening `GROW_TIME` past about 0.15 s risks a swing with a half-grown weapon. For the same reason the star peaks on its first frame and is gone by 0.25 s, and it sits up the haft so it doesn't cover him.

The burst uses its own flat material, not `Fx.flare` or `Fx.burst`: soft glows and dots look out of place beside the inked hero. It draws with depth testing off, in triangle order, so it shows over him. `_warm_fx` keeps its material loaded so the first change doesn't have to set it up mid-swing; that hasn't been measured.

## Clips

`heretic_bake.py` gives each mapped bone the source bone's direction and world rotation, which keeps a weapon in `hand.r` swinging as it did. Feet and toes copy rotation only, because the rigs' foot bones point different ways. Hips are shifted per frame to keep the feet at the source's height. Tentacle and skirt bones have no keys.

## Invariants

- Read modifier results inside `Skeleton3D.skeleton_updated`. The skeleton restores poses afterwards, so reading them later shows the pre-modifier pose.
- `void_arm.rest_form` is `"hand"` for him and `"axe"` for the old hero. `void_arm_check` expects `"axe"`, so run with `--heretic` its 6 rest-form checks fail by design.
- `void_surge`, `void_seep` and `void_frost` aren't in his GLB: they're shaped to wrap the old arm. `void_arm` skips absent parts, and the same run fails 4 checks that look for those meshes.

## Not done

- Clips are still the old hero's. Nothing is keyed for tentacles, so swings read as an arm with a weapon.
- The change has no sound of its own.
- The orbiting motes are still the old soft cyan dots (`elements.Orbit`).
- Weapons are the old hero's size: axe 2.75 m and spear 2.68 m on a 1.95 m hero.
- The main tentacle's last bone assumes `Vector3.UP` as its direction, because nothing follows it to measure from.
- `mid` and `low` bulge when coiled hard, where they're fused to the limb.
- High knees can stretch the skirt where it meets the thigh.
- Element effects on the tentacle are missing, and so are his veins recolouring on an Ascendancy.
- The KayKit-era clip names and the Ab_ clips he can't reach yet are baked but unchecked by eye.

## Checks

`godot --headless --path . -s tests/heretic_shots.gd` (PASS/FAIL). Windowed, it also saves `user://heretic_shots/`, including `strip_<close|game>_<form>_<i>.png`: the change in 20 ms steps from a close camera and the game's, with the weights printed as `[strip]`. Playing: `godot --path . -- --comic --heretic`.

Anything testing the change steps the skeleton by hand: set `MODIFIER_CALLBACK_MODE_PROCESS_MANUAL`, call `advance(delta)`, then await `skeleton_updated`, since `advance` only queues the time. Timers don't work, even at a low `Engine.time_scale`: one slow frame covers the whole change.
