# The heretic hero (Meshy model)

## What it does

A second comic hero behind a flag: `--comic --heretic`, never saved. The model and texture come from Meshy; the rig, weights and clips are rebuilt here. Without the flag nothing changes.

His right arm is a bundle of five tentacles. At rest they hang free and sway. When a move asks for a weapon the tips coil into the limb and the weapon pops out of it, then they unfurl again when he stops attacking.

How to make more models like this: [meshy-pipeline.md](meshy-pipeline.md).

## Files

| File | Role |
|---|---|
| `tools/meshy_rig/heretic_rig.py` | Meshy FBX → rig blend: bones, tentacle chains traced from the mesh, skirt chains, weights |
| `tools/meshy_rig/heretic_stress.py` | Stress poses and stretch numbers on the rig blend |
| `tools/meshy_rig/heretic_bake.py` | Copies `shaman_comic.glb`'s clips and weapons onto the rig, exports the GLB |
| `assets/comic/heretic.glb` | The result |
| `scripts/heretic_rig.gd` | Modifier: sway, coil-in, limb pose off attacks; adds the skirt's `SpringBoneSimulator3D` |
| `scripts/comic_look.gd` | `HERETIC`, `hero_kind()`, `PAINTED`, `painted()` |
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

## Clips

`heretic_bake.py` gives each mapped bone the source bone's direction and world rotation, which keeps a weapon in `hand.r` swinging as it did. Feet and toes copy rotation only, because the rigs' foot bones point different ways. Hips are shifted per frame to keep the feet at the source's height. Tentacle and skirt bones have no keys.

## Invariants

- Read modifier results inside `Skeleton3D.skeleton_updated`. The skeleton restores poses afterwards, so reading them later shows the pre-modifier pose.
- `void_arm.rest_form` is `"hand"` for him and `"axe"` for the old hero. `void_arm_check` expects `"axe"`, so run with `--heretic` its 6 rest-form checks fail by design.
- `void_surge`, `void_seep` and `void_frost` aren't in his GLB: they're shaped to wrap the old arm. `void_arm` skips absent parts, and the same run fails 4 checks that look for those meshes.

## Not done

- Clips are still the old hero's. Nothing is keyed for tentacles, so swings read as an arm with a weapon.
- No per-weapon coil animation or ink burst on the change; only the scale pop and tips collapsing.
- The long-reach tube (`void_tendril.gd`) still uses `P_Tendril`, unmatched to the painted purple.
- `mid` and `low` bulge when coiled hard, where they're fused to the limb.
- High knees can stretch the skirt where it meets the thigh.
- Element effects on the tentacle are missing, and so are his veins recolouring on an Ascendancy.
- The KayKit-era clip names and the Ab_ clips he can't reach yet are baked but unchecked by eye.

## Checks

`godot --headless --path . -s tests/heretic_shots.gd` (PASS/FAIL). Windowed, it also saves `user://heretic_shots/`. Playing: `godot --path . -- --comic --heretic`.
