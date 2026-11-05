# The heretic hero (Meshy model)

## What it does

The hero (the only one since round 28). The model and texture come from Meshy; the rig, weights and clips are rebuilt here.

His right arm is a bundle of five tentacles. At rest they hang free and sway. When a move asks for a weapon the old one pulls back, the new one shoots out of the limb, the loose tips coil away and the main tentacle straightens to grip the haft. They unfurl again when he stops attacking.

How to make more models like this: [meshy-pipeline.md](meshy-pipeline.md).

## Files

| File | Role |
|---|---|
| `tools/meshy_rig/heretic_rig.py` | Meshy FBX → rig blend: bones, tentacle chains traced from the mesh, skirt chains, weights |
| `tools/meshy_rig/heretic_stress.py` | Stress poses and stretch numbers on the rig blend |
| `tools/meshy_rig/heretic_refine.py` | Rig blend → refined rig blend: flattened texture in, tentacle limb thickened, head and left fist grown. Bones and weights untouched |
| `tools/meshy_rig/flatten_texture.py` | The texture flattening (k-means in Lab, mode filter, islands from the UVs, mip padding) |
| `tools/meshy_rig/heretic_bake.py` | Copies `shaman_comic.glb`'s clips and weapons onto the rig, exports the GLB. Optional height |
| `tools/meshy_rig/heretic_audit.py` | Prints a hero GLB's tris, materials, texture, bones, rig-contract chains and height |
| `tools/meshy_rig/chibi_decimate.py` | Meshy GLB → welded, decimated (two collapse passes), recentred, optionally mirrored GLB, plus front/side/back/top renders |
| `tools/meshy_rig/chibi_paint.py` | Repaints the chibi's claw texels (found from the hand's UV triangles) in the heretic's magenta |
| `tools/meshy_rig/chibi_keys.py` | The chibi's hand-keyed clips (L1, AL1, L2, L3, DL, GR, VS, Idle, Idle_Ready, Run_F) and claw keys on the rest, over the baked blend, then the GLB again |
| `tools/meshy_rig/chibi_repaint.py` | Round 40: repaints the whole texture into flat regions by triangle class and bones, 2-3 design tones each |
| `tools/meshy_rig/chibi_shape.py` | Round 40: the hood's sharper, flopped peak and the fatter claws (vertices only) |
| `tools/meshy_rig/chibi_weapons.py` | Round 40: weapon hafts, spear head and hammer resized (vertices only) |
| `tools/meshy_rig/chibi_face.py` | Hides the chibi's chin and nose in the hood's shadow (skin texels under the face's UV triangles go dark indigo) and brightens the eye texels to cyan |
| `assets/comic/heretic_chibi.glb` | The chibi heretic, the default hero since round 29 (`--hero=heretic` for the old one), same rig contract |
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
blender -b vendor_src/meshy/heretic/heretic_rig_v1.blend -P tools/meshy_rig/heretic_refine.py -- dump vendor_src/meshy/heretic/v2/uvtris.npy
python tools/meshy_rig/flatten_texture.py vendor_src/meshy/source/Meshy_AI_elemental_heretic_v2_20261103_texture_fbx/Meshy_AI_elemental_heretic_v2_20261103_texture.png vendor_src/meshy/heretic/v2/uvtris.npy vendor_src/meshy/heretic/v2/flat.png 14 0.2
blender -b vendor_src/meshy/heretic/heretic_rig_v1.blend -P tools/meshy_rig/heretic_refine.py -- vendor_src/meshy/heretic/v2/flat.png vendor_src/meshy/heretic/v2/heretic_rig_v2.blend 0.02 1.22 1.3
blender -b vendor_src/meshy/heretic/v2/heretic_rig_v2.blend -P tools/meshy_rig/heretic_bake.py -- assets/comic/shaman_comic.glb vendor_src/meshy/heretic/v2/out/heretic.glb 2.2
python tools/comic_glb.py vendor_src/meshy/heretic/v2/out heretic
cp vendor_src/meshy/heretic/v2/flat.png assets/comic/heretic_Material_0_baseColor.png
godot --headless --import --path .
```

Paths must be absolute on Windows. Without the refine step and the `2.2` (bake `heretic_rig_v1.blend` straight) you get round 28's model back; it is also in git before round 29.

`vendor_src/.gdignore` must exist in the worktree before the import. Without it Godot scans the Meshy FBX and blends, fails on the `.blend` importer, and silently re-imports nothing, so the game keeps the old GLB.

Godot never overwrites an extracted texture that already exists (`heretic_Material_0_baseColor.png`). Copy the new one over it, as above, or the new GLB shows the old texture.

## Round 29 refinement

Audit of round 28's GLB: 15,901 tris on the body (17,125 with weapons), one 2048 texture, one material, 101 bones (21 `tent.*`, 36 `skirt.*`, 3 `weapon.*`, 15 fingers), 1.95 m tall against KayKit's 2.18 m. Seen from the game camera he was about 110 px tall: the white mane took most of what you see, the tentacle limb was a thin magenta clump at rest, the Meshy paint's baked shading broke up into speckle under the cut tones, and the 2.7 m weapons dwarfed him.

What changed, all in `heretic_refine.py` and the bake, the rig untouched:
- Texture flattened into 14 colour regions with 20% of the original lightness kept for the face and seams (`flatten_texture.py`), and `PAINTED.brush` 0.2 → 0.12.
- Tentacle limb pushed out 2 cm along its normals (fading in over 10 cm from the shoulder), so it reads at rest.
- Head and hair grown 1.22x about the neck, left fist 1.3x about the wrist, towards the chibi direction in [art-direction.md](art-direction.md).
- Baked at 2.2 m instead of the old hero's head height, so he matches KayKit and grows into the weapons.

Result: same tris, bones and clips; `heretic_shots`, `comic_check`, `training_check` and the autotest pass. Seen in windowed stills only, not played.

Two Meshy candidates were generated for a new base (60 credits, see [art-direction.md](art-direction.md)) and neither was used: one realistic with no tentacle arm, one chibi with a broken patchwork texture. Both are in `vendor_src/meshy/source/` (`cand1_t2r_01a1a6bc.glb`, `chibi_t2r_01a1a6c4.glb`); the chibi's Meshy task ids are preview `01a1a6c3-871e-77fc-89fd-883d5fac3e76`, refine `01a1a6c4-842d-77b6-9f97-05a5d24782e8`, so it can be retextured and auto-rigged from Meshy without generating again.

## The chibi heretic (round 29, the default)

A second heretic model with the same rig contract: `assets/comic/heretic_chibi.glb`. **It is the default hero** (`Game.HERO_DEFAULT = "chibi"`), an orchestrator decision in round 29 that Zak can veto by changing that one constant. `--hero=heretic` plays the round-28 model for this process only, or Settings → "Hero model (on restart)": Chibi heretic / Heretic (saved as `video/hero_model`, only written when not the default). `--hero=chibi` forces the default. `Game.hero_model` picks the file through `ComicLook.HERETIC_MODELS`; the kind stays `heretic`, so `KIND_TONES`, `CLIPS`, `heretic_rig.gd` and every `hero_kind() == HERETIC` check work for both. `painted()` caches per texture, since both models call their material `P_HereticPaint`.

What it is: the round-29 chibi candidate (big pointed bone-white hood, short body, a six-claw tentacle hand on an ordinary right arm), decimated, mirrored so the claw is the right hand, retextured and auto-rigged through Meshy's REST API, then rebuilt with `heretic_rig.py ... chibi`.

| | Heretic | Chibi |
|---|---|---|
| Body tris | 15,901 | 21,999 (23,223 with weapons) |
| Height | 2.2 m | 1.85 m (1.75 m before round 29's second pass) |
| Bones | 101 (21 tent, 36 skirt, 15 fingers) | 89 (24 tent, 36 skirt, no fingers) |
| Tentacle | five tips on a tentacle arm | six claws (`main`, `up`, `out`, `mid`, `low`, `back`) from the wrist, grown 1.5x about it |
| Weapons | old hero's size (axe 2.75 m) | x0.7 about the hand: axe 1.92 m, spear 1.88 m, hammer 1.34 m |
| Texture | flattened Meshy paint | Meshy retexture as is (already flat), claws repainted magenta, face under the hood darkened |
| Eyes | none | `heretic_rig.gd` `EYES`: two glowing cyan almonds at the hood's brim |

Rebuild (from the repo root, Blender 5.2, absolute Windows paths; sources in `vendor_src/meshy/source/` and `vendor_src/meshy/chibi/`):

```
blender -b --factory-startup -P tools/meshy_rig/chibi_decimate.py -- vendor_src/meshy/source/chibi_t2r_01a1a6c4.glb vendor_src/meshy/chibi/dec22k.glb 22000 vendor_src/meshy/chibi/dec_render 1
# Meshy REST (key from the Blender add-on): POST /openapi/v1/retexture {model_url: data URI of dec22k.glb, text_style_prompt, enable_original_uv: false}
#   -> task 01a1a6d6-f321-74ba-884f-4757b66cad3d (10 credits), then POST /openapi/v1/rigging {input_task_id: that, height_meters: 1.7}
#   -> task 01a1a6d9-45e2-7612-983b-118deb1b38ed (5 credits): vendor_src/meshy/source/chibi_rig_01a1a6d9/chibi_rigged.fbx
blender -b --factory-startup -P tools/meshy_rig/heretic_rig.py -- vendor_src/meshy/source/chibi_rig_01a1a6d9/chibi_rigged.fbx vendor_src/meshy/chibi/chibi_rig_v1.blend chibi
blender -b vendor_src/meshy/chibi/chibi_rig_v1.blend -P tools/meshy_rig/chibi_paint.py -- vendor_src/meshy/chibi/paint.png
blender -b vendor_src/meshy/chibi/chibi_rig_v1.blend -P tools/meshy_rig/chibi_face.py -- vendor_src/meshy/chibi/paint.png vendor_src/meshy/chibi/face.png
blender -b vendor_src/meshy/chibi/chibi_rig_v1.blend -P tools/meshy_rig/heretic_refine.py -- vendor_src/meshy/chibi/face.png vendor_src/meshy/chibi/chibi_rig_v3_1.5.blend 0 1 1 1.5
blender -b vendor_src/meshy/chibi/chibi_rig_v3_1.5.blend -P tools/meshy_rig/heretic_bake.py -- assets/comic/shaman_comic.glb vendor_src/meshy/chibi/out_1.5/heretic_chibi.glb 1.85 0.7
python tools/comic_glb.py vendor_src/meshy/chibi/out_1.5 heretic_chibi
python -c "from PIL import Image; Image.open('vendor_src/meshy/chibi/face.png').convert('RGB').save('assets/comic/heretic_chibi_Material_0_baseColor.jpg', quality=92)"
godot --headless --import --path .
```

The `chibi` profile in `heretic_rig.py` holds its values: Meshy's REST rig names (`Spine02` lowest, `Spine`, `neck`, `head_end`) are aliased to the Mixamo-style names; `ARM_FROM_SKELETON` keeps Meshy's upper and lower arm and starts the tentacle at the wrist (`SHOULDER` = the wrist, `RING_R` 0.07, `ROOT_BLEND` 0.04 into `lowerarm.r`); `ARM_SPLITS` wrist.r 0-0.03 m, hand.r 0.03-0.10 m along `main`; every claw parented to `hand.r`; `TIP_SEG` 0.06; claw paint hue 0.82-0.94, saturation over 0.4, x below -0.15; skirt from 0.62 m (fade to 0.52) down to 0.18 m, leg radius 0.085 below 0.3 m and 0.075 above, axis (0.02, 0.2). The default `heretic` profile reproduces round 28's rig unchanged.

`heretic_rig.gd` reads chain lengths from the skeleton (up to `MAX_CHAIN` bones per tip) and also sways a `back` tip, so the chibi's sixth claw moves; the heretic has no `back` chain and is unchanged.

Seen in windowed `heretic_shots` stills only (`user://heretic_shots_chibi/`), not played. From the game camera the hood is a big pale shape that reads clearly on the indigo floor, and the weapons are about his height.

### Second pass (round 29): claw, height, face, eyes, grip

From the game camera the first chibi read clean and on-style, but the claw hand was too small to read at rest, the pale chin and nose showed under the hood, the weapon-change star sat over the hood, and the grab and slam did little with the claw. What changed:
- **Claw 1.5x** about the right wrist (`heretic_refine.py`'s sixth argument, `claw_scale`): every vertex weighted to `hand.r` or `tent.*` grows by its weight, and the `tent.*` bones and `hand.r`'s tail move with it so the claws bend at their own joints; `hand.r`'s head stays on the wrist, so weapons sit where they did. 1.3, 1.4 and 1.5 were compared at the game camera (scratchpad `chibi_claw_scales.png`): 1.5 is the first that reads as a big claw at rest without tearing at the wrist. Same 21,999 tris and 89 bones.
- **Baked at 1.85 m** (was 1.75 m), so he is about as big on screen as the old 2.2 m heretic's bulk; weapons stay x0.7 (axe 1.92 m), about his height.
- **Face in shadow** (`chibi_face.py`): head triangles inside a box round the hood opening (x -0.2..0.28, y -0.05..0.3, z 0.92..1.3 m on `chibi_rig_v1.blend`), texels of hue .02-.075, saturation .21-.45, value over .7 (the peach skin; the hood's bone white is hue .1, saturation under .2) go to (0.045, 0.035, 0.085); 36,806 texels. The jagged lower edge of the black mask is left pale and reads as a sawtooth grin. Eye texels (hue .4-.56) go bright cyan.
- **Glowing eyes** (`heretic_rig.gd` `EYES`, per `Game.hero_model`): from the game camera, 54 degrees down, the hood hides the face entirely, so a texture can't be seen. Two flat camera-facing almonds (ink, cyan `EYE_LOW`, white core; 9.5 x 4 cm, inner corners tilted down 16 degrees) on a `BoneAttachment3D` on `head`, at the texture's eyes pushed forward to the brim (skeleton space (-0.034, 1.25, 0.13) and (0.155, 1.25, 0.13)). They draw with no depth test, like the burst, and hide when his face turns more than about 80 degrees from the camera (`EYE_FACING`). In the stills they read as two cyan slits under the hood when he faces the camera, and as a pair of specks from the game camera. They need `cull_mode = CULL_DISABLED`: the fan winds the wrong way for Godot and was culled the first time. Since round 29's second animation pass each eye also hides while the claw or a weapon is between it and the camera (`_covered`: any point along `hand.r`, the `tent.*` bones and their midpoints, or a haft that is out, nearer the camera than the eye and within `EYE_CLAW_R` (7 cm, times the hand's swell) plus the eye's half-width of its line of sight), so they read over the hood but behind a lifted claw. It runs last in the modifier, on this frame's claw.
- **Burst off the hood**: `heretic_form_fx.STAR_OFF_HAND` 0.6 → 1.5 of the star's size up the haft. Axe and hammer stars now sit above the hood at +20/+60/+100 ms; the spear's, which points down and forward, still touches the hood's edge from the game camera.
- **Claw grip on GR and VS** (`heretic_rig.gd` `GRIP_MOVES`, visual only): reads `player._move_id` and how far the clip has played against the move's first hit. GR splays the claws back as it reaches (up to `GRIP_SPLAY_DEG` 22 per bone, the claws' base swelling `GRIP_SPLAY_GROW` 1.18) and snaps them shut on the hit (`GRIP_CLENCH_DEG` 32 per bone, in `GRIP_SNAP` 0.05 s); VS holds them clenched with a shake (`GRIP_SHAKE_DEG` 6 at 19 Hz) while it heaves, then flings them open on the slam. Only when the form is `hand`; it fades back to the free sway over `GRIP_FADE` 0.15 s. The main tentacle curls with the claws. `heretic_shots` checks the four states and the release.

Before/after sheet at the game camera: scratchpad `chibi_round3_sheet.png` (idle, run, L1-L3, GR reach and catch, VS lift and slam, change frames).

## Animation (round 29: the chibi's own clips)

The chibi's signature clips are hand-keyed on his own rig by `tools/meshy_rig/chibi_keys.py`, written over the shaman clips `heretic_bake.py` copied, and exported again with the same bones, weapons and clip names. The round-28 heretic (`heretic.glb`) is unchanged.

| Clip | Moves | Frames (30 fps) | Contact before | Contact after | What it does |
|---|---|---|---|---|---|
| `Ab_L1` | L1 | 31 (1.033 s) | 11 (0.367 s) | 11 (0.367 s) | axe cocked behind his right shoulder, crouched and squashed; one smear drawing; a flat cut across the front to his left, held 5 frames, small overshoot |
| `Ab_AL1` | AL1 | 30 (1.0 s) | 11 (0.367 s) | 11 (0.367 s) | L1's keys in the air, legs tucked |
| `Ab_L2` | L2 | 33 (1.1 s) | 12 (0.4 s) | 12 (0.4 s) | coiled back with the spear cocked out to his right, then punched straight out with the body lunging behind it |
| `Ab_L3` | L3 | 56 (1.867 s) | 24 (0.8 s) | 24 (0.8 s) | rises tall with the hammer behind his head (held 6 frames), crashes it onto the floor ahead, squashed flat |
| `Ab_DL` | DL | 61 (2.033 s) | 12 (0.4 s) | 12 (0.4 s) | crouch, spear cocked up for the pounce, stabbed down ahead with the body stretched after it |
| `Ab_GR` | GR, EE, EW, EA, EV, VD, TW | 31 (1.033 s) | hit 0.248 s | hand arrives frame 5 (0.167 s), claws snap shut frame 7 (0.233 s), held to 12 | claw pulled back splayed, shot out at full reach swollen 1.45x, snapped shut, yanked home |
| `Ab_VS` | VS, OW, IS | 46 (1.533 s) | hit 0.598 s | slam frame 17 (0.567 s), held to 23 | the catch heaved over his head clenched and shaking, smashed down ahead with the claws flung open |
| `Idle` | relaxed | 120 (4.0 s, a seamless loop) | | | hunched; the weight rolls onto one leg (hips 3.5 cm over it, the free heel lifting) and over to the other once a loop, two breaths heaving chest, hood and body, the head tilting with the weight and glancing; claw held out at his side, swollen 1.2x, opening and closing and drifting out and back, one flex |
| `Idle_Ready` | the guard | 60 (1.8 s at 1.1, a seamless loop) | | | round 35 b: Idle's weight shift and breathing, wider and lower: weight rolled from leg to leg once a loop, two breaths, claw held up in front of his face open and flexing, fist raised |
| `Run_F` | running ahead | 14 (0.467 s, a seamless loop) | | | round 35, see Locomotion: contact, down, push-off, a long leap and contact again on each foot (left down on 0, right on 7), feet locked to the floor at 7.5 m/s, leaning 26 degrees, the whole body squashing on the down pose and stretching in the air, the claw trailing splayed behind his right, the fist pumping |
| `Ab_LH` | EC, IJ | 51 (1.7 s) | 16 (0.533 s) | 14 (0.467 s; EC hits at 0.493 s) | crouched and twisted, claw dragged back low and splayed; raked along the floor ahead under them (swollen 1.45x), held; clenched and heaved overhead in four drawings while the game's hop lifts him, tall and stretched |
| `Ab_H` | VR | 63 (2.1 s) | 42 (the shaman's spin) | 15 (0.5 s; VR hits at 0.504 s) | claw cocked high behind his right shoulder, splayed; one smear; a flat crescent across the front to his left, claws wide, swollen 1.4-1.5x, held; shut on the follow-through |
| `Ab_LLH` | EF, IP | 59 (1.967 s) | 21 (0.7 s) | 20 (0.667 s; hit 0.669 s) | up on his toes, tall, spear raised high (round 35 c: the hand straight up over the hood, el 84 was 72, the spear swollen 1.1 and only -32 tip-down, was -55, since a steeper spear foreshortened to a stub from the game camera), a shake at the top; lunged and driven into the floor ahead at -22 degrees, squashed flat, held, leaning on it |
| `Ab_AF` | EM | 99 (3.3 s) | 51 (1.7 s) | 50 (1.667 s; hit 1.683 s) | a drawing every 6 frames (played at 1.7 x 1.6): claw pulled back to his hip, clenched into a fist swelling to 1.5x, shaking; shoved out flat ahead as a huge open palm (1.65x), body lunging after it, held |
| `Hit_A` | getting hit | 21 (0.7 s) | | | knocked back on frame 2 with the hood squashed flat and wide and the claw flung open, held 5 frames, a stretched rebound, back to the guard |
| `Dodge_Forward` | the dash | 13 (0.433 s) | | | a drawing every 2 frames: one crouched drawing (body and hood squashed), then the streak from frame 2 to 7 (pitched 48 degrees, body stretched long and thin, hood stretched along the dash, leading knee tucked up and the other leg straight out behind, claw and fist trailing), a skid landing squashed low with the feet wide, back to the guard |
| `Run_B`, `Strafe_L`, `Strafe_R` | running back and sideways | 14 (0.467 s) | | | Run_F's cycle and footfalls, feet locked to the floor the same way; back: leaning back, claw up in guard, the fist pumping small; sideways: facing ahead, hips turned and leaning into the travel, the swinging foot passing ahead (left) or behind (right) the planted one, a 2-frame plant |
| `Death_A` | dying (round 35 c) | 46 (0.9 s at 1.7; the room restarts 1.8 s after) | | | flinched (hood squashed), a woozy stagger with the head lolling, the knees buckle onto the floor and the hood flops forward, a topple onto his face with the hood squashed flat and a small bounce; the claw lies out ahead splayed, twitches twice and dissolves last (`hs` 1.25 -> 0.12 over frames 33-43) |
| `Ab_Swing` | R onto a pillar (round 35 c) | 41 (played once; the swing runs 0.5-1.6 s on) | | | anticipation: crouched, claw cocked down behind him (frame 3); flung up and out splayed, stretched, swollen 1.45x (5); the yank: body pulled up after it past the hang, legs swinging through (7, the overshoot); the hang: tucked, leaning in, claw up and clenched, a slow drift and flex to frame 41 |
| `Jump_Start`, `Jump_Idle` | the breaker leap | 20, 33 | | | a deep squash, sprung up stretched with the claw thrown up beside his head; then tucked and hanging, claw high and splayed, slowly flexing |

Moves outside `HERO_MOVES` (the tentacle moves: GR and the six other Ab_GR moves, VS / OW, EC, VR, EF, IP, EM) play their clips raw, and since round 30 (second pass) their first hit is the chibi's keyed contact exactly: `void_element.gd` `GR_HIT` (f7, the claw snap), `VS_HIT` (f17, the slam), `LH_HIT` (f14), `H_HIT` (f15), `LLH_HIT` (f20), `AF_HIT` (f50), with cancel / end / breaker `leap` keeping their time after the hit. `tests/contact_frames.gd` measures them (`VOID_CLIPS`: the 40% swing rule, or for Ab_GR the claw snap, since the 40% rule finds its yank home on f16) and `comic_check` fails on a mismatch. IJ (the vault) and IS (Avalanche's ender) are exempt (`VOID_EXEMPT`). The round-28 heretic's clips are the shaman's and contact 1-27 frames later; contact_frames prints how far (`info`).

Lengths are unchanged and every `HERO_MOVES` contact frame (the last frame `hand.r` moves at 40% of its peak, `tests/contact_frames.gd`) lands where it did, so `ComicLook.HERO_MOVES` and `player.MOVES` are unchanged and both models share the table. GR and VS are not in `HERO_MOVES`: their hits are `MOVES`' fractions set from the keyed contact (above), so the hitstop freezes on the snap and the slam.

Every other clip is still the shaman's. Those the game plays (`PLAYED`: the fidgets, 2H_Melee_Idle) get claw keys (`copied_claws`): half curled, splaying into the clip's contact (found by the same 40% rule on its hand), clenched on it for 4 frames, easing back, a drawing every 6 frames; loops get a slow curl. The 27 clips nothing plays get none.

**GLB size.** 2.93 MB baked, 4.07 MB after round 29's claw keys (written every frame on all 50 clips), 2.96 MB now with 21 clips keyed. Each track is a sampler, two accessors and buffer views in the GLB's JSON (about 280 bytes of JSON per track before any keys), so the track count matters as much as the keys. `write()` keys claws only where a drawing changes, CONSTANT (glTF STEP), and everything else on the frame before each change and on the change, LINEAR: the same curve as a key on every frame. `share_anim_accessors` then shares byte-identical sampler accessors and repacks the BIN (lossless, about 40 KB). `contact_frames.gd` measures the same contacts as before.

**How a clip is keyed.** `CLIPS` lists each clip's extremes, `(frame, pose, ease to the next)`. A drawing falls every `STEP_ATTACK` (4) frames for attacks, `STEP_STANCE` (3) for stances, and on every extreme; each drawing is the eased mix of the extremes round it and is held to the next: on twos at the game's play speed (1.7 for attacks, 1.1 for stances), with the move to a new drawing taking one 30 fps frame. Poses say where things go, not bone angles: `rh` (az, el, r) puts the right hand from its shoulder (az 0 ahead, +90 his right), `w` where the weapon or the bare claw points, `f` the axe edge's facing; two-bone IK solves both arms and both legs (feet planted from `fl`/`fr`), the torso takes `hip`/`hipr`/`spine`/`chest`/`head` as world-space turns on top of their parents, `hsq` squashes the hood (wide and short on anticipation and impact, tall on the smear; a squash also widens it `HSQ_WIDE` (0.6) past volume, since height barely reads from 54 degrees up), `hs` swells the hand and with it the claw or weapon on smears and reaches, `claw` -1..1 splays or clenches all six claws about each bone's own curl axis (towards the claw's middle line), `clawph` ripples them.

The script checks each `HERO_MOVES` clip's contact with the game's rule before exporting and prints `CONTACT MISMATCH` if one moved. Every step after the contact must move the hand less than 40% of the swing's biggest step, so recoveries are split into several keys.

Rebuild (from the repo root, Blender 5.2, absolute Windows paths; the baked blend is the one `heretic_bake.py` saves beside its GLB):

```
blender -b vendor_src/meshy/chibi/out_1.5/heretic_chibi_baked.blend -P tools/meshy_rig/chibi_keys.py -- vendor_src/meshy/chibi/out_keys/heretic_chibi.glb
python tools/comic_glb.py vendor_src/meshy/chibi/out_keys heretic_chibi
godot --headless --import --path .
godot --headless --path . -s tests/contact_frames.gd   # both models must print "ok"
godot --path . -s tests/heretic_shots.gd -- --clips --clips-tag=after [--clips-only=Ab_L1] [--clips-near=0.35]
```

`--clips` films every clip the game plays on him at 12 drawings a second of play time from the game camera, cropped round him, to `user://heretic_shots_chibi/clips_<tag>/` with an `INDEX.txt` (clip time, hit frame). `--clips-near` moves the camera in along the same angle to check a pose.

Game side (`heretic_rig.gd`): `keyed` is true when the clips key the claws (`CLAW_TRACK` in `Idle`). Then the sway adds on top of the clip's claw pose instead of the rest, `GRIP_MOVES` (the procedural grip) is skipped, clips in `KEYED_ARM` keep their arm off attacks instead of easing to the rest spread, and the loose claws stay out round a weapon at `KEYED_COLLAPSED` (0.8) instead of pulling in to 0.04, curled by the clip. `heretic_shots` measures the keyed grip from the clip's tracks (claw spread in hand space: GR's reach 0.40 m and VS's slam 0.40 m against 0.27 m at rest; GR's catch and VS's lift 0.10 m).

What the game camera showed (before/after strips, anticipation / contact / follow-through): L1's axe now cuts across the front instead of pointing at the camera mid-swing; L2's spear is fully out ahead at contact; L3's hammer lands on the floor ahead (before, it stood upright behind him at the hit; at first keyed through the floor and vanished, fixed at -16 degrees); GR reads as a reach and a snap; VS's claw shows over the hood on the lift and splays wide on the slam. Vertical motion (the hood squash, the run's bounce) barely shows from 54 degrees up; what reads is the weapon's direction, the claw's size and the torso's twist. Seen in windowed stills only, not played.

## Readability (round 35 c)

From the game camera (13 m, 54 degrees down, the hero ~140 px) the attacks read by width and size, not height, and the first films showed the anticipation, strike and contact drawings nearly the same silhouette. `chibi_keys.py` `PUNCH` gives each attack clip's key drawings a role, and `punch()` layers on top of the poses:

| Role | `bsq` (whole body, root bone scaled about the floor: + short and wide) | Also |
|---|---|---|
| `a` the wind-up | +0.06 | |
| `U` the top of an overhead rise (L3, VS, the plant) | -0.08 (tall) | |
| `A` anticipation, 2-4 frames before contact | +0.16 | hood squashed at least 0.24 |
| `S` the smear (the strike drawing) | -0.16 (tall and thin) | hood stretched at least -0.2, claw / weapon swollen x1.3 (`PUNCH_HS_SMEAR`, up to `PUNCH_HS_MAX` 1.6: a bigger claw over the hood hides him) |
| `H` contact | +0.13 | hood squashed at least 0.18 |
| `O` follow-through | +0.08 (sinking on) | |
| `T` the overshoot past rest | -0.05 (springing up past rest) | hood -0.06, the swell x0.93 of the hit's |

Clips: Ab_L1, Ab_AL1, Ab_L2, Ab_L3, Ab_DL, Ab_GR, Ab_VS (also the breaker dive), Ab_LH, Ab_H, Ab_LLH, Ab_AF and Jump_Start (the breaker leap: crouch squashed, spring stretched). Every key of those clips carries `bsq` so it eases between drawings. **No contact moved** (L1 11/31, L2 12/33, L3 24/56, DL 12/61, AL1 11/30, GR 7, VS 17, LH 14, H 15, LLH 20, AF 50): the root's squash moves the hand (6-10 cm at hand height), so the script's contact check now counts it (`squashed()`, as `tests/contact_frames.gd` does) and checks Ab_VS too (`CLIP_CONTACT`); feet of drawn clips are unsquashed like the runs'. Each `[keys]` line prints `recovery`: the biggest step after the contact against the 40% line (under 1.0 or the contact moves later); Ab_LH (0.96) and Ab_VS (0.93) sit closest, both from their return to the guard, as before (0.99, 0.91).

Films: `heretic_shots -- --clips --clips-step=0.0333 --clips-max=40 --clips-only=Ab_L1,Ab_L3,...` before / after (`--clips-only` takes a list and `--clips-max` the shot count since round 35 c), and `string_film` before / after. In the clip films the anticipation reads as a wide low lump, the smear as a tall stroke with a bigger claw, the contact as a flat wide hit; in the string film's busy frames it reads mostly on L3's and VS's impacts, the effects covering the rest.

## Chibi pass 2 (round 40)

Zak confirmed the chibi as the art direction and asked for it fine-tuned, not replaced. Four passes over the baked blend, each a script, all keeping the rig, bone names, rest pose and every clip (the GLB is `chibi_keys.py` over the last blend, so contacts print the same; `hero_stride_check`, `comic_check`, `lean_spike_check`, `heretic_shots` pass):

| | Before | After |
|---|---|---|
| Body tris | 21,999 | 21,999 (same mesh, UVs and weights) |
| Weapon tris | 1,224 | 1,224 |
| Texture | 2048 JPEG, 511 KB | 2048 JPEG, 377 KB (flat regions compress better) |
| GLB | 3.26 MB | 3.12 MB |
| Height | 1.85 m | 1.85 m |

- **Texture** (`chibi_repaint.py`): each triangle gets the median colour of its texels, a colour class (white, beige, crimson, teal, green, magenta, dark, black, cyan) and then a region from the class and its bones: claw (hand.r / tent.* / wrist.r over 0.5, or anything past the right wrist or 0.2 m ahead of him at rest), hood / lining / face / eye (head and neck), scarf, sash, tunic, sleeve, boot, glove, trousers, skirt. Regions under 25 triangles take their neighbours' (`MIN_ISLAND`; adjacency through welded positions, since the mesh is split at UV seams). Then each texel is painted flat from its triangle's region plus a band read from fields interpolated across the triangle (height, the weight on a claw's last bones, distance from the wrist): `TONES` holds the palette. Hood bone white with a crimson lining; scarf crimson (its hanging ends darker), so the head separates from the body from above; sash a darker crimson; tunic teal with a darker hem and sleeves; skirt plum with a darker hem; trousers dark plum; boots, glove and arm wrap bone grey with dark soles and cuffs; face (0.045, 0.035, 0.085) with cyan eyes; the claw fx_palette's void (body violet, light tips, a deep band round the wrist). A brim band round the face opening was tried and dropped: the hood is a thin shell over its lining, so "near the face" was half the hood. Unpainted texels are filled by growing the painted ones 24 px. `--debug` paints each region a loud colour.
- **Silhouette** (`chibi_shape.py`): above 45% of the hood's height over the brow, each 2 cm slice narrows about its own middle (to 0.6 at the tip) and shears back by 0.2 m x t^2, so the tip keeps its height and leans away from the camera; from 54 degrees up it now pokes out past the top of the hood (it read as an egg). A rotation instead of the shear lowered the tip, and stretching it back up blunted it. Each claw's vertices (by their strongest chain) move out from the nearest point on that chain's bones by x1.35, fading in 4-12 cm from its root, so tips stay sharp and the gaps keep their ink.
- **Face** (`heretic_rig.gd`): `GRIN` is a camera-facing inked crescent with two rows of paper teeth meeting in a zigzag, tilted 7 degrees into a smirk, on its own `BoneAttachment3D` (`grin`) under the eyes, in their material and hidden with them. `_step_face` drives `squint` (0..1): `SQUINT_ATTACK` 0.5 in ATTACK / SWING / LEAP / CHARGE, `SQUINT_HURT` 0.9 in HURT / DEAD, a blink every `BLINK_EVERY` 3.4 s otherwise; each eye scales to `SQUINT_MIN` of its height at 1, and the grin to `GRIN_BARE` on attacks and `GRIN_GRIT` when hit. From the game camera the grin shows when he faces it; it reads strongest in the close views.
- **Weapons** (`chibi_weapons.py`): hafts x1.3-1.55 round their bones, the spear head 1.6x wider (collar 1.3x), the hammer x1.18 about the hand (reach 1.34 -> 1.62 m) with head, lava and rock 1.15x about their middle. Scaling about the hand or a part's middle keeps the haft along its bone (`haft_alignment` 1.000) and `chibi_keys.py`'s weapon facing. Tones: `KIND_TONES["heretic"]` `P_Tendril` (hafts, the claw's violet), `P_VoidHard` (blades, heads, collar: void deep and ink), `P_Rock` (the hammer's studs, violet); the accents stay the element's (axe edge `P_StormGreen`, spear `P_Ice`, hammer `P_Lava`). `heretic_rig.RIM_SKIP_FORMS` keeps the paper rim off every weapon part, so they have only the 1.6 px ink like the sleek effects.

Rebuild (from the repo root, Blender 5.2, absolute Windows paths; `vendor_src/meshy/chibi/out_1.5/heretic_chibi_baked.blend` is the baked blend):

```
blender -b vendor_src/meshy/chibi/out_1.5/heretic_chibi_baked.blend -P tools/meshy_rig/chibi_repaint.py -- vendor_src/meshy/chibi/p2/paint.png vendor_src/meshy/chibi/p2/paint.blend
blender -b vendor_src/meshy/chibi/p2/paint.blend -P tools/meshy_rig/chibi_shape.py -- vendor_src/meshy/chibi/p2/shape.blend 0.2 0.4
blender -b vendor_src/meshy/chibi/p2/shape.blend -P tools/meshy_rig/chibi_weapons.py -- vendor_src/meshy/chibi/p2/weapons.blend
blender -b vendor_src/meshy/chibi/p2/weapons.blend -P tools/meshy_rig/chibi_keys.py -- vendor_src/meshy/chibi/p2/out/heretic_chibi.glb
python tools/comic_glb.py vendor_src/meshy/chibi/p2/out heretic_chibi
# the extracted texture is never overwritten: copy the GLB's embedded JPEG bytes over heretic_chibi_Material_0_baseColor.jpg
godot --headless --import --path .
godot --headless --path . -s tests/contact_frames.gd
```

`chibi_keys.py` over the round-29 baked blend reproduces the committed GLB byte for byte, which is how this pass was checked before any edit. Later clip work keys over `p2/weapons.blend`, not `out_1.5`.

Before / after: windowed `heretic_shots` (game and close crops of the ten poses), `foe_shots -- --tag=` (the lineup) and `string_film` (four strings).

## Hero pass 2 (round 40, second lane)

The lineup read after chibi pass 2: the nine foes popped and the hero was the weakest figure on screen, small, pale and low-contrast. He is the player's avatar, so he must be the boldest silhouette in a crowd. Four more scripts over the same blend, rig and clips kept (contact_frames prints the same 22 frames, `hero_stride_check` 1.00):

| | Pass 2 | Hero pass 2 |
|---|---|---|
| Height (hood tip) | 1.85 m | 2.05 m (Armature node x0.987 after the head and hood grew) |
| Game camera, Idle (one at a time on his spot, 1600x900) | 146 px tall, 12.3k px | 183 px tall, 17.7k px (warrior 209 px, 28.4k; dummy 165 px) |
| Front ortho | 413 px | 460 px |
| Body tris / bones | 21,999 / 89 | 22,197 / 93 (scarf ribbon, scarf.01-04) |
| GLB | 3.12 MB | 3.10 MB |

- **Presence** (`chibi_presence.py ... 1.25 0.06 1.5 2.05 1.2 1.1`): head and hood x1.2 about the neck joint by head weight, the hood x1.25 wider from 1.1 m up (each 2 cm slice about its own middle near the tip, so the lean-back stays) and its peak 6 cm taller, the claw x1.5 about the wrist with its `tent.*` bones moved through the same map (hand.r's head, the weapon bones and the weapons untouched), then the Armature object scaled so the tip stands at 2.05 m. The glTF Armature node carries the scale: skeleton space is unchanged, so `EYES` / `GRIN` stay in rest space and only move through `HEAD_GROW`. `chibi_keys.py` reads the scale (`WORLD_K`) and divides the run's ground speed by it (`RUN_GROUND`, `floor_d`), and widens every keyed stance by `STANCE_W` 5 cm a foot. comic_check's facing check now takes the turn of each node, not its scale.
- **Contrast** (`chibi_repaint.TONES`): a three-value figure. Bone-white hood; a cool blue-black body (tunic, sleeves, trousers, skirt, boots, glove); the violet claw and cyan eyes as the bright accents. The crimson scarf and sash are the only colour on the body, and the boot cuffs and forearm wrap take the sash's crimson. The paper rim (`hero_rim`) carries the dark body's edge on the floor.
- **Scarf tail** (`chibi_scarf.py`): a 0.89 m crimson ribbon (0.24 m wide at the root, 0.17 at the swallowtail end), leaving the back of the scarf under the hood's hem and trailing out over his left hip, on four new bones off `chest`. It is joined into the body mesh, its UVs on flat scarf texels, and the body's custom split normals are carried over (joined faces without them shaded black and lost the ink hull). `heretic_rig.gd` gives it its own `SpringBoneSimulator3D` (`ScarfSprings`, `SCARF_*`, a spine capsule) and waves it first (`_flutter_scarf`: faster and lifted back `SCARF_LIFT_DEG` with his speed), so it streams behind a run and the spring carries the overshoot. Models without `scarf.01` skip it.
- **Face**: `chibi_repaint.FACE_OVAL` paints every head texel inside a front oval round the eye and grin spots as face (the low brim and texture eyes included), and `heretic_rig.gd`'s `FaceShade` is a depth-tested, camera-facing dark oval behind the decals on the grin's attachment. Meshy's mask was a dark V with the white cowl round it; from 13-54 degrees up the grin sat on that white. The texture oval alone changed nothing visible there (the white behind the grin was the hood's under-chin cowl seen past the brim), the shade oval fixed it from every yaw.

Rebuild after the pass-2 chain (`p2/weapons.blend`):

```
blender -b vendor_src/meshy/chibi/p2/weapons.blend -P tools/meshy_rig/chibi_presence.py -- vendor_src/meshy/chibi/p2/presence.blend 1.25 0.06 1.5 2.05 1.2 1.1
blender -b vendor_src/meshy/chibi/p2/presence.blend -P tools/meshy_rig/chibi_scarf.py -- vendor_src/meshy/chibi/p2/chibi_scarf.blend
blender -b vendor_src/meshy/chibi/p2/chibi_scarf.blend -P tools/meshy_rig/chibi_keys.py -- vendor_src/meshy/chibi/p2/out/heretic_chibi.glb
```

then `comic_glb.py`, the JPEG bytes, `--import` and `contact_frames.gd` as above. Later clip work keys over `p2/chibi_scarf.blend`.

## Hero pass 3 (round 40, third lane): face and attitude from the game camera

The lineup after hero pass 2: every foe shows a face to the 54-degree camera (eyes tipped up, big sockets, a scowl) and pops; the hero showed the top of a hood, a pale egg with a purple blob. Same rig, bones, weights and clips (contact_frames prints the same 22 frames, `hero_stride_check` 1.00).

- **Face to camera** (`chibi_faceup.py ... 28 0.05 0.12 0.3`, vertices only): every vertex turns back 28 degrees about a point 0.3 m over the neck joint by its head weight (chin up, the peak further back), in the bind pose, so every clip shows the face tipped up; the custom split normals turn with it. The hood's front rim round the face opening is pushed 5 cm out and back (the cut). `heretic_rig.gd` `FACE_TIP` moves every face spot through the same turn after `HEAD_GROW`, and the facing test (`face_dot()`) uses the tipped face: in Idle facing the camera the face points 39 degrees off it (cos 0.78; untipped 0.40). Pivoting at the neck joint itself slid the face 17 cm back behind the chest and dropped the hood tip 0.3 m; 40 degrees still showed only the brim in a Workbench game view, so most of the read comes from the decals:
- **Bigger face**: eyes `EYE_SIZE` 0.15 x 0.085 m (was 0.095 x 0.04), a rounder lid (`EYE_LID` 0.7), spread x1.35 (`EYE_SPREAD`); grin 0.2 x 0.068, 1.5 cm lower and one render priority under the eyes (its ink corners covered the eyes' lower half); the `FaceShade` oval 0.22 x 0.17 drawn `FACE_PULL` 0.22 m nearer the camera than it sits (a small spatial shader moves it in view space, depth test kept), so the brim no longer hides it but a claw further in front does, and it hides with the mouth when the claw covers it. Game camera, Idle facing it (1600x900): face 1,375 px dark + 247 px glowing eyes = 7.9% of his silhouette (pass 2: 331 + 8, 1.7%).
- **Check**: `heretic_shots` headless asserts `face_dot` > `FACE_DOT_MIN` 0.7 in Idle; windowed, the Idle game shot must hold `FACE_PX` 250 px of the shade's colour round FaceShade and `EYE_PX` 25 px of glow round each eye (1,220 / 139 / 139 at `TURN`). Shots reset the blink first: a deterministic run blinked on exactly the frame a scratch measure grabbed, and the eyes read as 2 px slits.

- **Hooked point** (`chibi_hook.py ... 0.12 0.15 0.22 0.08 0.5`, vertices and normals, on `p2/faceup.blend`): from half the hood's height up it shears back 0.12 m and up 0.15 m (x t^2), and from 62% of that its last part bends over to his left 0.22 m *linearly* (`KINK` 1), so it leaves the dome at an angle: one hard corner in the outline, where a u^2 bend was a smooth horn. A band at the bend on the side it bends to is pulled in 8 cm (the notch; on its own, 4-10 cm of notch on a 2 cm-sliced mesh never showed at the game camera, the kink did). Hood tip 1.76 -> 1.83 m; Idle at the game camera 211 -> 229 px tall (the tip reaches back, which is up the screen).

Rebuild after the pass-2 chain:

```
blender -b vendor_src/meshy/chibi/p2/chibi_scarf.blend -P tools/meshy_rig/chibi_faceup.py -- vendor_src/meshy/chibi/p2/faceup.blend 28 0.05 0.12 0.3
blender -b vendor_src/meshy/chibi/p2/faceup.blend -P tools/meshy_rig/chibi_hook.py -- vendor_src/meshy/chibi/p2/hook.blend 0.12 0.15 0.22 0.08 0.5
blender -b vendor_src/meshy/chibi/p2/hook.blend -P tools/meshy_rig/chibi_keys.py -- vendor_src/meshy/chibi/p2/out/heretic_chibi.glb
```

then `comic_glb.py`, the JPEG bytes, `--import` and `contact_frames.gd` as above. Later clip work keys over `p2/hook.blend`.

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
- `void_arm.rest_form` is `"hand"`: a free tentacle at rest, weapons only form to strike. `void_arm_check` expects it.
- `ComicLook.HERO_FORMS` lists only meshes in his GLB (the old arm's `void_surge`, `void_seep` and `void_frost` went in round 28).
- `ComicLook.HERO_MOVES` `frames` / `hit` are his own clips' 30 fps counts (`HERO_CLIP_FPS`; `heretic_bake.py` resampled the shaman's 24 fps keys and put one hold frame first, so every pose is 1/30 s later than the shaman's). `hit` is the contact frame, where the weapon hand's swing arrives: L1 11/31, L2 12/33, L3 24/56, DL 12/61, AL1 11/30 (round 30; the shaman's counts had each hit 27-54 ms of clip time early). Both models (heretic and chibi) measure the same. After re-keying or re-baking a clip run `godot --headless --path . -s tests/contact_frames.gd`: it measures every model's contact frames off the GLB tracks (`HERO_CONTACT_SPEED`) and prints the `hit` / `frames` each `HERO_MOVES` line should have; `comic_check` fails until the table matches every model in `HERETIC_MODELS` (if two models stop agreeing, the table has to become per model).

## Locomotion (round 35)

Zak, round 35: "the movement animation is awful". The old run was 21 frames played at 1.1 with its feet sweeping 0.6 m: they covered 2.36 m/s of floor while he moved at 7.5 m/s (3.2x skating; the strafes 7.7-9.7x), and on held 3-frame drawings a planted foot also rode forward with him for 3 frames and snapped back. The four runs, the idle and the dash are re-keyed in `chibi_keys.py` (Locomotion block); no game code changed.

- **Feet locked to the floor.** `RUN_GROUND = MOVE_SPEED / LOOP_SPEED / 30` (0.227 m a clip frame): a planted foot slides back exactly that far each frame, so at `player.move_speed` 7.5 and the loop speed 1.1 it stays put on the floor. A foot is down `RUN_PLANT` 3 frames (0.68 m from 0.30 m ahead of the hip joint to 0.38 m behind, the ankle rising 9 cm onto the toes at the end, `RUN_TOE`), then in the air 11 frames: it kicks up and through on a Hermite curve, reaches the landing mark a frame early and drops straight onto it (`RUN_PAW` 0). The plant is a whole number of frames because Godot samples between keys: a 2.5-frame plant blurred the push-off into a slow frame. Sideways the legs reach less: `STRAFE_PLANT` 2 frames (0.45 m).
- **On ones and twos.** Legs, hips and the body squash are written every frame (a held foot skates); arms, head, hood and claw are held 2 frames for the comic snap. Runs and the idle are written from frame 0 (`LOOP0`, `write(..., start=0)`), so the last frame is the first again and the loop has no held seam (frame 1 used to be held for 1/30 s at every wrap).
- **Poses per step** (`RUN_HIPS`, m from his stance): contact -0.075 (heel down, toes up 10 degrees), down -0.125 at 20% of the step (lowest, `RUN_SQUASH` 6%: the whole body short and wide about the floor, `root` bone scale, feet corrected by `unsquash` so they stay locked), push-off -0.08 at 43%, the top of the leap -0.02 at 70% (stretched tall, both feet off the floor). The hood (`hsq`) runs from +0.2 (squashed) to -0.12 (stretched) a little after the body. Hips pitch `RUN_LEAN` 26 degrees in, turn 10 degrees with the leading leg, the chest twists 22 back; the hips sway 5 cm and roll 10 degrees over the planted foot.
- **Arms.** The fist pumps hard against the left leg (az -20 to -150, elbow bent, `pump()` holds the ends so it reads as two poses); the claw trails splayed out behind his right (az 122-158), counter-pumping, swollen 1.18x, its claws rippling.
- **Cycle.** 14 frames = 0.424 s at 1.1, 4.7 steps a second, 1.6 m a step: a bounding chibi run with long leaps rather than a jog.
- **Measured** by `tests/hero_stride_check.gd` (in `agent.sh check`): the foe check's measure on the hero (feet below half their height range, moving against the travel faster than 0.1 m/s). Before: Run_F / Run_B 2.14 m/s at 1x (ground/feet 3.2), Strafe_L 0.70 (9.7), Strafe_R 0.88 (7.7). After: all four 6.82 m/s at 1x = 7.50 at 1.1 against 7.5 (1.00). Awakened (1.2x speed, same clip speed) they skate 1.2x.

Rebuild as above (`chibi_keys.py` over the baked blend, `comic_glb.py`, `--import`), then `godot --headless --path . -s tests/hero_stride_check.gd [-- --trace]`. Film one clip frame by frame from the game camera with `tests/heretic_shots.gd -- --clips --clips-only=Run_F --clips-step=0.0333 [--clips-near=0.75]`. Change `MOVE_SPEED` or `LOOP_SPEED` in the script if `player.move_speed` or the loop speed in `player._play` change: the check fails until they agree.

### Round 35 b: start, stop, turns, Awakened, guard

- **Run_Start** (6 frames, 0.18 s at 1.1) and **Run_Stop** (8, 0.24 s), keyed a frame at a time like the runs (`chibi_keys.py`, after Jump). `floor_d` integrates `player.accel` (70 m/s^2: 0 to 7.5 m/s in 0.107 s, 3.5 clip frames) so a planted foot gives back exactly the floor he covers while speeding up or braking. The lunge: a crouch pitched in with the hips left behind (2 frames, claw drawn back low, the right foot planted and rising onto its toes), launched stretched tall with the fist thrown ahead and the left knee driven up, landing on Run_F frame 0's left contact (`RUN0`, `run_feet0`), so Run_F carries on from 0 with nothing to blend. The skid: the left foot braced `SKID_FRONT` 0.32 m ahead of the hip joint toes up, the back one dragged on its toes, both sliding (giving back `SKID_GIVE` 0.1 m of his 0.4 m braking travel), body squashed and leaning back with the claw flung behind; frames 3-5 the chest, head and hood pitch forward past upright (hood stretched), the claw swings through in front, and frames 6-8 settle into Idle frame 0 (`IDLE0`). The skirt springs overshoot on their own as the body stops.
- **Game side** (`player._play_locomotion`): Run_Start when he sets off towards his facing from below `RUN_START_BELOW` (0.3) of move speed and no run is playing; it plays out unless he turns off Run_F. Run_Stop when the stick lets go during Run_F above `RUN_STOP_ABOVE` (0.6); it plays out, then the stand (`_comic_stand`). Both play at the loop speed (`RUN_ONESHOTS`, `_loop_speed`); a model without the clips (round 28's heretic) skips them (`has_animation`). Both are in `heretic_rig.KEYED_ARM`.
- **Awakened**: `AWAKENED_RUN_CLIP` (= `HERO_AWAKEN.SPEED_MULT`) scales the runs and one-shots while Awakened (1.32); `_play_locomotion` sets it every frame of a run, since `_play` returns early on the same clip. `hero_stride_check` reads `LOOP_SPEED` and `AWAKENED_RUN_CLIP` off player.gd and fails if either case skates more than 15% (with the constant at 1.0: FAIL 4, Awakened 1.20).
- **Turn lean** (`heretic_rig._lean_into_turns`, procedural, no clip): in State.MOVE the root bone (on the floor) tilts towards `velocity - lagged velocity` (`LEAN_LAG` 0.12 s), `LEAN_DEG` 3 degrees per m/s across his facing and `LEAN_ALONG` 0.45 of that along it, capped `LEAN_MAX` 15, on a spring (`LEAN_STIFF` 600, `LEAN_DAMP` 34: one small overshoot); `lean` is public for probes. Headless numbers: 90 degree turn 12 degrees peak, reversal 8, start 2.5 forward, stop 2.5 back, held run 0. Out of MOVE (attacks, dash) it springs back to 0. The spring is stiff enough that an explicit step longer than ~0.06 s diverges (windowed frame spikes threw "axis must be normalized" every frame and the hero vanished), so a frame counts at most `LEAN_MAX_DELTA` 0.05 s, stepped in `LEAN_SUBSTEP` 1/120 s pieces, a non-finite lean resets to zero and a zero axis skips the tilt. Check: `tests/lean_spike_check.gd` (0.5 s deltas, flipping and zero velocity, a NaN lean; in `agent.sh check`).
- Film: `tests/heretic_shots.gd -- --clips --clips-only=Run_Start --clips-step=0.0333` (both one-shots are in `CLIP_SET`). The lean needs velocity, so it shows only in play.

### Round 35 c: strafe and back starts / stops, the guard skid

- **One start and one stop per run** (`Run_Start`, `Run_Start_B`, `_L`, `_R`; `Run_Stop`, `Run_Stop_B`, `_L`, `_R`), all from one generator in `chibi_keys.py` (`RS_POSES` / `SK_POSES` per way, `run_start_feet(way)`, `run_stop_feet(way, end)`, `TRAVEL` in (his right, his front)). Each start ends on its own run's frame 0 (`run_feet(way, 0)`), the push-off (right) foot sliding against the travel at the `player.accel` ramp. Backing: hunched over the push with the hips left ahead, sprung back leaning away, claw up in guard; stop braced on a foot behind him on its ball, hunched forward, then the top of him rocks back past upright. Sideways: dropped and tipped into the travel with the hips left behind, thrown along it banked 18 degrees; stop braced on the leading foot `SKID_WIDE` 0.2 m out on its edge, banked away, then tipping over towards the travel with the claw swinging through. Forward clips unchanged.
- **The guard skid:** every stop again ending on Idle_Ready's frame 0 (`Run_Stop_Ready`, `Run_Stop_B_Ready`, ...), its settle pose half way to the guard. Played while `_ready_t > 0` (he attacked or was hit in the last `ComicLook.READY_HOLD` 3 s), which is also when the stand after it is Idle_Ready, so the skid settles straight into the guard instead of into Idle and blending back up.
- **Game side** (`player._play_locomotion`, the only code change): the clip is `"Run_Start" + RUN_SUFFIX[run clip]` and `"Run_Stop" + RUN_SUFFIX[playing] + ("_Ready" if _ready_t > 0)`, from any run clip (was Run_F only); a model without the clip skips it (`has_animation`). All 12 are in `RUN_ONESHOTS` (loop speed, Awakened) and `heretic_rig.KEYED_ARM`. GLB +136 KB (3.09 -> 3.23 MB).
- Seen in Blender side / front sheets (scratchpad), not played.

## Not done

- The round-28 heretic's clips are still the old hero's, with nothing keyed for the tentacles. The chibi's played clips are keyed (Animation, above) except the fidgets and 2H_Melee_Idle, still the shaman's with keyed claws. None of the keyed clips has been played by hand, only filmed.
- The change has no sound of its own.
- The orbiting motes are still the old soft cyan dots (`elements.Orbit`).
- Weapons are the old hero's size: axe 2.75 m and spear 2.68 m on a 2.2 m hero.
- Still a realistic body with a grown head: the chibi direction needs a new base (art-direction.md).
- The main tentacle's last bone assumes `Vector3.UP` as its direction, because nothing follows it to measure from.
- `mid` and `low` bulge when coiled hard, where they're fused to the limb.
- High knees can stretch the skirt where it meets the thigh.
- Element effects on the tentacle are missing.
- The KayKit-era clip names and the Ab_ clips he can't reach yet are baked but unchecked by eye.

## Checks

`godot --headless --path . -s tests/heretic_shots.gd` (PASS/FAIL). Windowed, it also saves `user://heretic_shots/`, including `strip_<close|game>_<form>_<i>.png`: the change in 20 ms steps from a close camera and the game's, with the weights printed as `[strip]`. Playing: `godot --path .`.

Anything testing the change steps the skeleton by hand: set `MODIFIER_CALLBACK_MODE_PROCESS_MANUAL`, call `advance(delta)`, then await `skeleton_updated`, since `advance` only queues the time. Timers don't work, even at a low `Engine.time_scale`: one slow frame covers the whole change.
