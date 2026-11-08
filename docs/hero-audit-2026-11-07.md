# Hero audit, 2026-11-07 (hero-fix lane)

Zak, after an hour of play: "The character looks awful. The design is OK but the implementation in game is awful.
The head is bobbing and doesn't fit at all, the model is a mess, the idea is alright."

This lane made the current hero (`--hero=chibi`, `assets/comic/heretic_chibi.glb`: the round-44 hand-built body from
`tools/hero_build/hero_v2.py` on the round-40 Meshy chibi rig, hand-keyed clips) look right in game now, with no new
Meshy models and no Meshy credits. It is also the hand-over for the redesign lane.

Sheets: `Desktop/awaken-combo-clips/63 hero head before-after.png` and `64 hero mess before-after.png`.

## 1. The bob: diagnosis

Root cause in two sentences: every clip was hand-keyed (`tools/meshy_rig/chibi_keys.py`) for the Meshy chibi, whose
hood was a small cap over the neck joint, and round 44 put a head 40-42% of his height on the same keys, so the
neck and head turns, the hood squash (`hsq`) and the whole-body run squash (`bsq`, root bone scale) that read as small
accents on the cap threw the big head around. In the run the 18 cm hip bob, a +-6% whole-body squash, a 0.91-1.05
hood squash and a 14 degree head nod held on twos (the body moves on ones) added up to the hood's crown travelling
46 cm up and down per step, 4.7 times a second.

Measured headless from the skeleton (`godot --headless --path . -s tests/hero_head_check.gd [-- --raw] [--frames]`):
the clip played through the AnimationPlayer at 30 fps with `MODEL_SCALE` 1.15. "Crown" is a fixed point 0.55 m over
the head joint (the hood's crown in rest); "screen" is its travel against his feet as the game camera sees it (53
degrees down), the larger of facing the camera and side-on; "tilt" is the head's tilt off upright.

| Clip | crown height range, cm (before -> after) | screen travel, cm | head tilt, deg |
|---|---|---|---|
| Run_F | 45.8 -> 12.4 | 46.0 -> 21.2 | 14-39 -> 14-19 |
| Run_B | 37.0 -> 10.2 | 42.5 -> 20.6 | 3-12 -> 1-4 |
| Strafe_L | 40.5 -> 10.9 | 36.9 -> 17.3 | 9-26 -> 7-11 |
| Strafe_R | 40.7 -> 9.9 | 37.6 -> 16.1 | 8-26 -> 7-10 |
| Run_Start | 34.5 -> 8.4 | 36.5 -> 17.0 | 27-32 -> 17-19 |
| Run_Stop | 35.3 -> 8.6 | 90.9 -> 48.5 | 3-59 -> 2-17 |
| Idle | 5.0 -> 2.8 | 10.8 -> 7.3 | 15-21 -> 7-9 |
| Idle_Ready | 6.6 -> 2.8 | 11.9 -> 7.3 | 20-28 -> 11-14 |
| Ab_L1 | 61.8 -> 52.4 | 60.9 -> 50.0 | 8-38 -> 4-25 |
| Ab_L3 (slam, squash kept) | 82.4 -> 76.8 | 126 -> 106 | 16-67 -> 10-48 |
| Dodge_Forward | 41.1 -> 34.8 | 68.4 -> 51.5 | 4-40 -> 1-25 |

Run_F before, per frame (cm): hips 69 62 63 68 75 80 74 69 62 63 68 75 80 74; crown 150 137 132 144 165 174 166 156
133 135 147 159 178 167. Of the 46 cm: 18 cm is the hips (RUN_HIPS -0.125 .. -0.02 m in the keys, x1.15), about
15-20 cm the root squash (`RUN_SQUASH` 6% each way about the floor), the rest the head on the chest (hsq and the nod,
which also stepped every second frame against legs keyed every frame).

Idle: the head sat 15-21 degrees off upright because the keyed chest hunch (16 degrees) and a slow head roll
(22 cm side to side at the crown, on the chest) carry it; from the close camera the hood hung forward and to one side
of the shoulders: "doesn't fit".

The other candidates from the brief, checked:
- `hsq` / `HOOD_SQUASH_K`: yes, a part (above). The old engine damping (0.45) only halved it.
- Root motion vs feet: no. Feet are locked (`hero_stride_check` 1.00); the bob is the hips' own keys.
- Run cycle keys: yes, the main part (hips + root squash).
- FACE attachment: no. Eyes and grin are on a `BoneAttachment3D(head)` laid on the face plate; they follow the head
  exactly and add nothing.
- SpringBone on the skirt: no. `SkirtSprings` only moves `skirt.*`; the torso has no spring.
- clip_warp retiming: no. Only Ab_AF was retimed (round 51) and it keeps its drawings.

## 2. The fix

**Engine, `scripts/heretic_rig.gd` `steady()` / `_steady_head()`** (runs every frame after the clip, before the
scarf and face):
- Neck and head keep `HEAD_TURN_K` 0.35 of their keyed turn from rest (`HEAD_TURN_ATTACK_K` 0.5 in attacks, so the
  lunge into a hit still reads).
- The head then levels: it takes back `HEAD_LEVEL_K` 0.5 of its tilt off upright (pitch and roll, never the turn
  about the vertical), 0.25 in attacks.
- No hood squash (`HOOD_SQUASH_K` 0) except on the slams, `SLAM_MOVES` L3, VS (and the breaker dive), EF:
  `SLAM_SQUASH_K` 0.45, as before.
- In `State.MOVE` (eased over 0.15 s): the root keeps `RUN_SQUASH_K` 0.3 of its squash, and the spine gives back
  `RUN_BOB_K` 0.6 of the hips' bob and `RUN_ROCK_K` 0.6 of their pitch / roll rocking about their running mean
  (`RUN_BOB_TAU` 0.3 s; a step is 0.21 s). The legs still bound, the top of him glides. The spine shift is under 6 cm.
- Contact frames and hit timing are untouched: no hand bone is under the head, and the spine work only runs while
  moving (`contact_frames.gd` measures the GLB tracks; all 22 chibi lines print `ok`).
- `tests/hero_head_check.gd` (in `agent.sh check`): every looping run keeps the crown's screen travel under 24 cm,
  Idle under 10 cm, every locomotion clip keeps the head's tilt within 15 degrees of its range.

**Model, `tools/hero_build/hero_v2.py`:** the head group (hood, horns, stripe, rim, face plate) is scaled
`HEAD_K` 0.86 about the neck joint at export, and the back point runs `BACK_K` 0.7 of its length (env
`HERO_HEAD_K`, `HERO_BACK_K`; 1 and 1 rebuild round 44). The face spots in `face.txt` carry the scale;
`heretic_rig.FACE["chibi"]` holds them and its `"k"` sizes the eye and grin shapes (`_scaled`). Hood crown (rest,
glTF space) 1.64 -> 1.55 m, neck joint to crown 0.66 -> 0.57 m (40% -> 37% of the crown's height; art-direction.md
asks about a third), horn tips 1.95 -> 1.87 m. Same 21,900 body tris, 80 skinned bones, weapons unchanged.
`heretic_shots` `FACE_PX` 250 -> 180 (the plate is 0.74x the area; Idle measures 220).

Rebuild (from the repo root of a worktree; Blender 5.2; `vendor_src/hero_v2/` is gitignored and needs a `.gdignore`,
or `godot --import` stops on the `.blend` and silently keeps the old GLB import):

```
cp assets/comic/heretic_chibi.glb vendor_src/hero_v2/base_r63.glb
blender -b --factory-startup -P tools/hero_build/hero_v2.py -- <abs assets/comic/heretic_chibi.glb> <abs vendor_src/hero_v2/fix1> horns render
python tools/hero_build/glb_swap.py vendor_src/hero_v2/base_r63.glb vendor_src/hero_v2/fix1 assets/comic/heretic_chibi.glb
# copy face.txt's three spots into heretic_rig.FACE["chibi"], "k" = HEAD_K
godot --headless --path . --import
godot --headless --path . -s tests/contact_frames.gd   # + comic_check, hero_stride_check, hero_head_check, heretic_shots
```

The base must be the committed GLB (it carries round 51's Ab_AF re-key), not `base_r40.glb`. The build sources
(`base_r40.glb`, round 44's `out/`) live only in `../awaken-model-hero2/vendor_src/hero_v2`; this lane's copy and
`fix1/` are in `../awaken-hero-fix/vendor_src/hero_v2` until the worktree is removed.

## 3. The mess catalogue (sheet 64)

Fixed here:
1. The head swallowed the body from the game camera: one pale cone. Head 0.86, back point 0.7: the shoulders, glove
   and claw now show round it.
2. The 0.8 m back point read as an onion or garlic tip from above. Shorter, the hood reads as a hood with horns.
3. The head hung off the shoulders (Idle hunch + roll): levelled.
4. Hood squash pancaked the hood and threw the horns wide on every attack's anticipation: now only on slams.

Remains (for the redesign; nothing below is fixable without changing the design):
5. The crimson stripe ends in a blocky slab over the brow (`build_stripe` starts 30 degrees ahead of the crown):
   a mail slot / visor from above.
6. Horns are void-dark on the indigo floor: only their crimson tips read, and the tip's colour boundary is a
   sawtooth (flat per-face colour on a decimated tube; a separate tip part would give a clean edge).
7. The face rim is a 4 cm crimson torus: a life ring up close, a red dot at the game camera. The face is 7-8% of him.
8. The scarf tail (0.89 m + 0.16 m past its last bone) is the biggest red shape from behind and reads as a blade or
   a flag.
9. Blue-black tunic, skirt, trousers and boots on the indigo floor: the body has no value contrast; only the paper
   rim separates it.
10. The paper rim (`hero_rim`) draws stray white strokes along thin parts (scarf tail edge, skirt points).
11. The bone-white hood is the training dummies' cream: in a crowd he merges with them. The claw held up beside the
    hood in Idle / Idle_Ready crowds the head's outline.
- Seams and intersections: none open (every part is a closed voxel-remeshed shell); horn roots and the stripe sink into
  the hood by design. Claw scale reads (the claw is the brightest, biggest shape; keep it). Outline breaks: none seen
  apart from item 10. Texture noise: the halftone dots in the toon shading of the hood and horn tips, by design.

## 4. Hand-over for the redesign lane

**What the rig contract is.** `assets/comic/heretic_chibi.glb` = one skinned mesh (`char1`, material
`P_HereticPaint`, a 128 px swatch palette) + eleven weapon meshes (`axe_void_*`, `spear_void_*`, `hammer_void_*`,
each 100% on its `weapon.<form>` bone, white `COLOR_0`, the farthest vertex from the hand at the haft's top) on 93
joints, bind pose = rest pose (joint world x IBM = identity, so rest-pose world coordinates are bind coordinates).
Checks that must stay green: `comic_check` (HERO_MOVES `hit` / `frames` against `contact_frames.gd`),
`contact_frames`, `hero_stride_check` (run feet vs `player.move_speed`, x `MODEL_SCALE`), `hero_head_check`,
`heretic_shots` (bones, forms, haft alignment, claw grip spreads, face facing and pixels, feet at rest height),
`void_arm_check`, `lean_spike_check`.

**Bones (93).** root; hips; spine, chest, neck, head; scarf.01-04 (off chest); shoulder / upperarm / lowerarm /
wrist / hand / handslot .l and .r; tent.main.01-05, tent.up / out / mid / low .01-04, tent.back.01-03 (all off
hand.r); weapon.axe / hammer / spear (on hand.r, head at the hand); skirt.00-11 .1-.3 (36, off hips); upperleg /
lowerleg / foot / toes .l and .r. Head joint at 0.996 m (skeleton rest), neck 0.94, chest 0.82, hips 0.69;
the Armature node is scaled 0.987 and the game scales it 1.15 (`heretic_rig.MODEL_SCALE`).

**Clips (62).** Played and hand-keyed: Idle, Idle_Ready, Run_F / Run_B / Strafe_L / Strafe_R, Run_Start(_B/_L/_R),
Run_Stop(_B/_L/_R)(_Ready), Dodge_Forward, Jump_Start, Jump_Idle, Hit_A, Death_A, Ab_L1, Ab_AL1, Ab_L2, Ab_L3, Ab_DL,
Ab_GR, Ab_VS, Ab_LH, Ab_H, Ab_LLH, Ab_AF, Ab_Swing. Still the shaman's with keyed claws: the fidgets (Idle_Heft,
Idle_Listen, Idle_Swing), 2H_Melee_Idle, and the KayKit-era / unreached Ab_ clips (Ab_AH, Ab_AL2, Ab_AL3, Ab_CH,
Ab_DH, Ab_LHH, Ab_LPL, Ab_RUSH, Ab_SKY, the 1H / 2H / Dualwield attacks, Spellcast_*, Running_A).
Contacts: L1 11/31, L2 12/33, L3 24/56, DL 12/61, AL1 11/30; GR 7, VS 17, LH 14, H 15, LLH 20, AF 32.

**What the build scripts can and cannot change.**
- `hero_v2.py` + `glb_swap.py` can change any mesh, its colours (palette regions) and its weights, the weapon meshes,
  the head proportions (`HERO_HEAD_K`, `HERO_BACK_K`) and the face spots, in seconds, with every clip byte for byte.
  Keep parts closed (remesh) and keep the face as geometry on the plate.
- They cannot change a clip. The keyed clips come from `chibi_keys.py` over a baked blend (`p2/hook.blend` chain)
  that is not on this machine (the round-29 `out_1.5` blends in `../awaken-anim-chibi*` predate the presence /
  scarf / faceup / hook passes and the scarf bones). So re-keying a pose means either finding that blend, rebuilding
  the chain, or editing the GLB's tracks directly (`tools/meshy_rig/clip_warp.py` shows how: samplers by clip,
  retimed in place). A new body with different proportions keeps the old keys: anything the keys assume (hip height,
  head size, claw length) has to fit them or be corrected in the engine, as this lane did for the head.
- They cannot add bones without `glb_swap.py` learning to write a new skin (it copies the base's nodes and skin).

**Proportions that work at the game camera (13 m, 53 degrees down, FOV 37, hero ~130-140 px tall).**
- Head (neck joint to crown) at most about 37% of his crown height, its widest part no wider than the shoulders +
  skirt seen from above, or it hides the body: from that camera the top of the head is most of what shows.
- No point or tail longer than about 0.55 m behind the head; past that the head reads as a cone.
- The face plate needs `FACE_TILT` 35 degrees up and the head levelled (`HEAD_LEVEL_K`) to face the camera:
  `face_dot` 0.91-0.92 in Idle (0.83 before the levelling).
- The signature limb (claw) at least 1.5x a natural hand and brighter than anything else on him.
- Something light on the body: today the body is blue-black on an indigo floor and vanishes; the hood is the only
  light value and it is the dummies' cream.
- Motion: a body 2.1 m tall in game should not move its crown more than about 20 cm per step on screen; keep big
  squash for slams. Anything keyed for a smaller head needs the `steady()` treatment or new keys.

## 5. Not done

- Not played by hand; judged from `heretic_shots` (close, game, clip films) and `string_film` frames.
- The clips are not re-keyed (no baked blend); the steadying is a procedural layer over them.
- Attacks still move the crown 50-110 cm (lunges and slams, by design); only their head turn and tilt were damped.
- Items 5-11 above.
