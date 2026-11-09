# The heretic: character design (v3)

Zak, 2026-11-07: "The character of the Heretic also needs designing. ... We really need to get this right." The
current model (round 44, `tools/hero_build/hero_v2.py` on the Meshy rig) has the right idea and a messy build. This
page fixes the design on paper first, then the model is made from it. It is the source of truth for how he looks;
`docs/features/heretic-hero.md` stays the source for how the current model is built and rigged.

Concept sheets: `awaken-combo-clips/66 heretic concepts.png` (directions A-D, each also shrunk to 90 px on the
indigo floor) and `awaken-combo-clips/67 heretic chosen turnaround.png` (front, side, back). Sources and Meshy task
ids: `vendor_src/meshy/heretic_concepts/` and [../meshy-spend.md](../meshy-spend.md).

## 1. Who he is

A novice of the church that built the dungeon, he broke into its vaults and took the four powers it kept locked
away (storm, ice, magma and the dark that held them), and the dark took his arm as its price. The church could not
burn what he had become, so it chained him in the prison it had built for those powers (see
[../design/environment-lore.md](../design/environment-lore.md)). He broke the shackle, kept the hood they put on
him, and now walks the prison that was built against him while every grate, keg and pillar remembers the power in
his arm. He is not grim about it: he is a small, cocky, horned problem the church made for itself.

## 2. Three pillars

1. **The arm is the character.** A bundle of void tentacles where his right arm should be, the brightest and
   most saturated thing on him, and the only thing that changes. Every weapon grows out of it and goes back into
   it. Remove it and he is a generic hooded kid; that is the test for anything else we add.
2. **Menace from shape, not detail.** Big pale horned hood, a black hole where the face should be, two cyan eyes.
   He is chibi (huge head, stubby body, big hands and feet) and still the scariest thing in the room because the
   silhouette says so, never because of texture.
3. **Reads from above, in a crowd, at 90 px.** The game camera sits at (0, 10, 7.5) looking down, FOV 36, so he
   is about 90-130 px tall and seen mostly from the top and back. Hood top, horns, scarf ring and arm are the
   design; everything below the belt is supporting cast.

## 3. Silhouette rules (90 px from the game camera)

What must read, in order:

1. **The horns.** Two thick ram-like horns curling forward and out of the hood's sides, wider than the hood. They
   are what breaks the outline from above (round 40 lesson: a shape that stays inside the egg does not exist from
   54 degrees up). They also give a facing read: horns curl forward, so you see which way he looks.
2. **The arm's mass on one side.** The tentacle bundle makes him asymmetric: one side is a glove, the other a
   magenta splay as wide as his head. At rest the tips hang apart with gaps between them (gaps read as "many"; a
   fused clump reads as a mitten).
3. **The pale hood dome**, with a soft back point (no tall peak: a peak hides inside the dome from above).
4. **The crimson scarf ring** between hood and body, so head and body are two shapes, not one pale blob.
5. **Big boots** wide apart, so he stands planted, not floating.

Rules: no part thinner than about 4 cm at 2.2 m height (it vanishes at 90 px); every signature shape has a gap of
sky round it in the T/A pose; nothing hangs to the floor (no capes: they hide the feet and the stance).

## 4. Colour script

Three values plus one accent, flat regions, two tones per part at most (body + one band that means something).

| Part | Colour | Notes |
|---|---|---|
| Hood | cool bone white `#E9E8F0`, lilac-grey shade | The lightest thing on him: the floor is dark indigo. Cooler than the training dummies' cream (audit item 11: a cream hood merges with them in a crowd). |
| Horns | blue-black `#1E2A33` with crimson tips `#A8282E` on the last third | Void-dark horns vanish on the indigo floor (audit item 6); the tips carry them. Round 44 film: crimson tips beat violet ones (violet merged into the arm). Clean tip edge: paint by texel, not per face. |
| Face | pitch black `#05050A` | A void, not a shadowed face. See section 6. |
| Eyes | cyan `#3FF2F2`, emissive | The only cyan on him. |
| Scarf, belt sash accent | crimson `#A8282E` | Separates head from body; one tail. |
| Tunic, skirt, sleeves | blue-black `#22303F` | Dark body; relies on `hero_rim` for its edge on the indigo floor. |
| Glove, boots | light slate `#7F8FB0` | The body's light value (audit item 9: an all blue-black body vanishes). v3's texture already has them light. |
| Shackle | iron grey `#6B6660` | Left wrist only; a chunky band, two links. |
| Tentacles | void magenta `#C83CE6`, tips light pink `#F2A0F5`, deep cuff `#6A1E8A` at the shoulder | The fx palette's void, so arm and effects are one set. |
| Skin | none visible | He shows no skin anywhere. |

Element weapons against him (the weapon is the element's colour, the haft is the arm's magenta):

- **Axe / storm**: lime-green crescent edge (`P_StormGreen`) on a dark head. Green is the complement of magenta,
  so the axe pops off the arm without fighting the eyes.
- **Spear / ice**: pale cyan leaf head. Shares the eyes' cyan on purpose: ice reads as "his eyes' cold", but keep
  the head lighter and less saturated than the eyes so the face stays the brightest cyan when he is not attacking.
- **Hammer / magma**: near-black block with orange lava bands. Orange is the only warm accent apart from the
  scarf, so the hammer must stay orange, never red, or it merges with the scarf.
- **Dark (bare tentacle)**: the arm itself, no weapon colour; dark effects are violet-black with magenta rims.

## 5. The tentacle arm as a design object

Five tentacles that start as one thick trunk at the shoulder (as wide as his head across, deep purple cuff where
it leaves the sleeve) and split about a third of the way down. Tips taper to rounded points, lighter pink.
No suckers, no veins, a single specular gloss band at most.

- **Rest**: the trunk hangs at his side, slightly forward; the five tips splay apart with gaps, curling up at the
  ends, and sway on their own (`heretic_rig.gd`). The arm reaches below his knee: it is longer than his real arm.
- **Grip**: when a weapon forms, four tips coil tight round the haft just under the head and the fifth wraps the
  trunk like a wrist band. The trunk straightens into the haft line.
- **Weapon forms**: the weapon grows out of the bundle, never appears in a hand. The haft is the tentacle itself,
  stretched and stiffened (magenta), and only the head is the element (axe crescent, spear leaf, hammer block).
  Weapons are oversized: the axe about his height, the spear 1.5x, the hammer head as big as his hood.
- **Dark / signature moves**: the tips stretch into whips and grabs (Reap, Tow Line, the floor tendrils). The arm
  is the only part allowed to stretch past its rest length.

## 6. Face rules

- The hood opening is a black void. No nose, no chin, no skin, no sculpted face: the face geometry is a recessed
  flat black cavity.
- Two cyan eyes, angled slits slanting down to the centre (angry), big: each about a fifth of the opening's width.
  They glow and are the only emissive part of the body.
- **Mouth: no mouth at rest.** A jagged white grin (direction C's) appears only as an expression, drawn over the
  void on big hits, breakers and Awakening (the existing `heretic_rig` grin node). Not modelled, not textured.
- From above the face is barely visible, so menace there comes from the eyes and horns, not from the expression.

## 7. Proportions (in head-heights, head = hood without horns)

- Total height about 2.7 heads: the head (neck joint to hood crown) at most 37% of his crown height, the limit the
  hero-fix audit measured at the game camera ([../history/hero-audit-2026-11-07.md](../history/hero-audit-2026-11-07.md) section 4).
  The concept sheet and the v3 mesh are at about 41%; the port scales the head group down about the neck to fit.
- No hood point or tail more than 0.55 m behind the head (the audit's cone limit). v3's hood has a short soft back.
- Hood: 1 head tall, 1.1 heads wide; horns add 0.35 heads per side.
- Torso (scarf to belt): 0.6 heads. Skirt and legs to the boot top: 0.45 heads. Boots: 0.35 heads, 0.45 heads long.
- Shoulders: 1 head wide. Left glove: 0.35 heads across (big). Tentacle trunk: 0.45 heads across at the shoulder,
  bundle reaching 1.3 heads from the shoulder at rest.
- Game height 2.2 m in the GLB (matches KayKit); the camera numbers the hero-fix lane's audit gives win over these.

## 8. What is deliberately NOT in the design

- No visible skin, mouth, nose or hair.
- No cape or floor-length robe (direction B's): hides feet and stance, and it fuses in Meshy.
- No witch-hat peak (B), no mask (D): both made him another character (a wizard, a ghost).
- No small ornaments: no buckles, stitching, runes, belts with pouches, patterns, text, jewellery.
- No sucker detail, veins or eyes on the tentacles.
- No second accent colour on the body beyond crimson; no gold (gold is Awakening's).
- No weapon in the model; weapons are separate meshes grown from the arm.
- No left-arm tentacles or a second signature limb: the asymmetry is the point.

## 9. Directions tried and the pick

Four directions (all nano-banana-2, 6 credits each), then one refinement:

| | Direction | Verdict |
|---|---|---|
| A | Horned hood: bone hood, ram horns, void face, crimson scarf, blue-black tunic, magenta arm | **Chosen.** Best read at 90 px: the horns break the outline, the scarf separates head and body, the arm is the only saturated colour. It is also the round 44 design idea done cleanly, so Zak's "design is OK" holds and the game's colours, weapon tones and face nodes carry over. |
| B | Crooked monk: floppy witch hood, indigo robe, giant arm | Arm mass is great (taken into the refinement), but the hat reads as a wizard and the robe hides the stance. |
| C | Escaped prisoner: torn hood, jagged grin, shackles, torn stole | Best lore and attitude; tentacles too thin. Its grin (as an expression) and the broken shackle are folded into A. |
| D | Porcelain mask: violet hood, mask, high collar | Strong close up, but the dark hood sinks into the floor and the mask reads as a ghost or skull. |

Refinement (image-to-image on A, multi-view): kept A, made the whole right arm one bundle from the shoulder (B's
mass), added C's broken shackle on the left wrist. Result: `67 heretic chosen turnaround.png`. Known gaps in the
sheet: the trunk is still narrower than asked (about 0.35 heads, not 0.45), and the side view shows the left
side only. The front view (`vendor_src/meshy/heretic_concepts/front_for_3d.png`) is the Image-to-3D input.

## 10. The v3 model (stage 2)

One generation, used: Image-to-3D from `front_for_3d.png`, Meshy T2.5 smart topology, `target_polycount` 12000,
texture model meshy-n1, no `pose_mode` (task `01a1ba0d-c56b-7116-a878-241a595054cf`, 15 credits). File:
`vendor_src/meshy/heretic_v3/t25/model_01a1ba0d.glb` (heretic-design worktree, gitignored). Renders:
`awaken-combo-clips/68 heretic v3 renders.png` (front, side, back, top and the game-ish camera, toon cut + ink hull,
headless Blender; not the game renderer).

Audit (headless Blender, `heretic_audit.py` style; script kept in the lane's scratchpad):

| | v3 | Note |
|---|---|---|
| Tris | 12,644, one mesh, one material | Inside the 16-22k the current hero runs at; room for the weapons. |
| Texture | one 2048 base colour, flat colour regions, 900-odd small UV islands | n1 painted from the concept: already flat and on-model, eyes cyan, arm magenta. No retexture needed. |
| Parts | 1 body shell (5,837 welded verts) + 5 chain links | Horns, scarf, arm and tentacles are fused into the body shell; 8 non-manifold edges after a weld, otherwise closed. |
| Size | 0.84 x 0.38 x 0.95 (Meshy units) | Rescaled to 2.2 m for the renders. |
| Symmetry | x-mirror median 7 cm, p90 19 cm | Symmetric body; the asymmetry is the arm and the shackle, as designed. |
| Tentacle arm | a distinct mass: trunk from the shoulder, five tips with clear gaps | The best tentacle result so far (round 28 lost the arm, round 29 made it a hand on an arm). |
| Head | about 41% of his height | Over the audit's 37%: scale in the port. |
| **Side** | **the arm is on his LEFT** | The concept puts it on the viewer's right, i.e. his left. Mirror the mesh in x before rigging (the game's limb is `hand.r`). |

Verdict: **portable.** Geometry, texture and silhouette match the design; the problems are a mirror, a head scale
and two texture tweaks, none needing a new generation. No second generation was spent (the T2.5 tentacles held).

From the game-ish camera the horns, scarf ring and arm read; the horns are dark on the floor (paint the tips) and the
hood is warm cream (cool it), both texture edits.

## 11. Port plan (for the next lane; nothing rigged here)

Not done in this lane. The rig contract is the hero-fix audit's section 4 (`heretic_chibi.glb`: one skinned mesh +
eleven weapon meshes on 93 joints, bind = rest, the checks listed there must stay green).

**Chosen chain: put the v3 mesh on the existing rig (the round-44 `glb_swap.py` route), not a new Meshy auto-rig.**
Reasons: the clips are hand-keyed and cannot be rebuilt (the baked blend is gone, audit section 4), so the only way
to keep all 62 clips, contact frames and checks is to keep the skeleton and skin a new mesh to it; `glb_swap.py`
already writes a GLB that changes only the `heretic` mesh, the weapons and the palette. A Meshy auto-rig (5 credits)
would give a 24-bone human rig with no tentacle, skirt or weapon bones and no clips, i.e. the round-29 rebuild again.

Steps:
1. **Mirror** in x (`chibi_decimate.py` already mirrors), weld 0.1 mm, recentre, face +Z.
2. **Fit to the rig's rest pose**, by region, in headless Blender: scale to the skeleton (crown at the audit's
   head-group height, 1.55 m rest; feet on the floor; hips at 0.69 m), then move per-region so joints land inside the
   mesh: head group (hood, horns, face) scaled about the neck to 37%; the left arm (glove + shackle) and boots onto
   `upperarm.l`..`hand.l` and the leg chains; the tentacle trunk onto `upperarm.r`/`lowerarm.r`/`hand.r` and its five
   tips onto `tent.main`, `tent.up`, `tent.out`, `tent.mid`, `tent.low` (five tips, five chains: trace each tip back
   along the surface as `heretic_rig.py` does, `TIPS` by eye). The v3 arm hangs down-and-out; the rig's rest arm may
   not, so bend the trunk vertices to the rest pose with a temporary armature deform before weighting (Blender: pose
   the old rig to v3's arm, apply the inverse as a mesh deform).
3. **Weights**: `hero_v2.py`'s scheme (inverse distance to allowed bones per part, top 4, smoothed), with parts found
   by texture colour (magenta = arm, crimson = scarf on `scarf.*`, cream = head, dark skirt hem on `skirt.*`,
   slate = boots and glove), and surface distance on the tentacles (`heretic_rig.py`, so tips never take a
   neighbour's weight across a gap). Chain links rigid on `hand.l`.
4. **Face**: v3's face is painted black with cyan eyes, not a cavity. Either keep the painted eyes (no blink/grin) or,
   better, cut a shallow face plate as `hero_v2.py` does and lay the existing eye and grin nodes on it (`face.txt` ->
   `heretic_rig.FACE["chibi"]`), so blink, squint and the grin still work.
5. **Texture**: keep n1's texture as the `paint` texture (`ComicLook.PAINTED`, `brush` 0.12). Two texel edits: horn
   tips crimson, hood cooler (section 4). Do not run `flatten_texture.py` (it is already flat and would eat the eyes).
6. **Weapons**: keep the round-44 weapon meshes; they grow from `hand.r`, which will now sit in the trunk.
7. `glb_swap.py` into `heretic_chibi.glb` behind a model flag first (`ComicLook.HERETIC_MODELS`, e.g. `--hero=v3`),
   then the audit's checks (`contact_frames`, `comic_check`, `hero_stride_check`, `hero_head_check`, `heretic_shots`,
   `void_arm_check`, `lean_spike_check`) and a windowed look before making it the default.

Risks: the arm's rest pose differs from the clips' (the clips may cross the trunk through the body; `heretic_rig.gd`
`ARM_FREE_TIME` blends it back at idle); one fused shell means the scarf and skirt flex with the body rather than
swing free (the skirt chains will stretch it, as on every Meshy model); the face, painted, does not blink until step 4.
