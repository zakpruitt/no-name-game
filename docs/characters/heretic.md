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
| Hood | bone white `#E8E2CF`, lilac-grey shade | The lightest thing on him: the floor is dark indigo. |
| Horns | blue-black `#1E2A33`, crimson tips optional | Round 44 film: crimson tips beat violet ones (violet merged into the arm). |
| Face | pitch black `#05050A` | A void, not a shadowed face. See section 6. |
| Eyes | cyan `#3FF2F2`, emissive | The only cyan on him. |
| Scarf, belt sash accent | crimson `#A8282E` | Separates head from body; one tail. |
| Tunic, skirt, sleeves | blue-black `#22303F` | Dark body; relies on `hero_rim` for its edge on the indigo floor. |
| Glove, boots | slate `#4A5A70` | One step lighter than the tunic so hands and feet read. |
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

- Total height about 2.4 heads (head is about 42% of his height, as the round 44 build).
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

## 10. Port plan (stage 2)

To be filled after the 3D generation.
