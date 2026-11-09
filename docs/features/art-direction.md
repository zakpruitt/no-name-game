# Art direction

## The pillar: chibi but badass

Zak, round 29: "chibi-esque, cartoony, not taking itself too seriously, but still able to make badass models". Every character, enemy and prop follows this. When a choice is unclear, pick the version that reads better at game distance and looks more fun.

- **Not** more detailed. **Not** serious, realistic or grim. Realistic anatomy, fine armour filigree, painted micro-detail and moody desaturation are all wrong for Awaken.
- **Yes** to menace through shape: a hood, a tentacle arm, glowing eyes, a huge weapon, a hunch. Badass comes from the silhouette, not from detail.

## Proportions

- Head about a third of the body height (the current heretic is a compromise: head grown 1.22x on a realistic body).
- Short stocky body, big hands and feet. One signature part oversized: the tentacle arm, the weapon, the shield.
- Weapons oversized: about the hero's height or more.
- Game scale: the hero is 2.2 m in his GLB, KayKit characters about 2.18 m. He is about 130 px tall at the game camera, which looks down from 13 m up and 9.5 m back. Judge everything there, not in a Blender viewport.

## Foes

- Foes follow the hero's proportions: big head (1.5x a realistic skull), big hands and whatever
  they hold, short thick legs, squat torso. A foe built at normal proportions goes through
  `tools/comic_art/chibi_pass.py` (see [comic-style.md](comic-style.md)) before it ships.
- Shadows step like the hero's: cool and lilac, not deep brown (`ComicLook.FOE_SHADE_MATCH` 0.8).
- A few thick inked masses, not many thin parts: a skeleton's bones are merged per limb group
  (`tools/comic_art/chunk_pass.py`), so the outline runs round the silhouette like the hero's. Keep a
  hint of ribs in the torso's shading; never a hull on every rib or finger again.
- Props already huge (shield, the archer's floor-length bow) are not grown again.
- The training dummy is a character, not a prop: a cartoon punching bag with a face, which squeezes
  its eyes shut on a hit and spins its pupils when dazed.

## Shapes and colour

- Bold simple shapes and large flat colour regions. Three or four colours per character plus one accent (the heretic's accent is the magenta limb).
- No small ornaments, patterns, text, buckles, stitching or freckles: under the cut-tone shading they turn into speckle.
- Light values against the indigo floor: pale hoods and hair read, dark brown and charcoal sink into the floor unless outlined.
- From above you mostly see the head, shoulders and the signature limb. Make those the most readable parts.

## Shading rules (Godot)

- Everything is lit through `shaders/comic_toon.gdshader`: cut tones (shadow / mid / light), ink outline (`Fx.COMIC_INK_PX` about 2), no soft gradients. Keep it.
- A painted (Meshy) texture is multiplied by the tones (`ComicLook.PAINTED`). Its own baked light fights the cut tones, so flatten it first: `tools/meshy_rig/flatten_texture.py` (k-means into about 14 flat regions, speckle removed). Keep `brush` low (0.12) on painted models.
- Baked highlights, ambient occlusion and PBR look are removed, never added.
- Full rules for the comic look: [comic-style.md](comic-style.md).

## Meshy prompt template

Prompts are capped at 800 characters. What worked and what didn't (round 29, two generations):

```
Chibi cartoon game hero, a menacing <hooded heretic>, full body, standing straight with both
arms held out away from the sides. Huge head about a third of his height inside a big
<pointed bone-white hood>, face in deep shadow with two glowing <cyan> eyes. Short stocky
body, oversized hands and feet. <Signature limb, with clear gaps between its parts>. <Other
arm>. <Clothing: 2-3 big pieces, panels hanging apart from the legs>. Bold simple shapes,
large flat colour regions, only <4 colours>. Cartoony and playful but badass. No small
ornaments, no patterns, no text, no weapon.
```

- That prompt (no `pose_mode`) gave a real chibi: big pointed hood, short body, a magenta tentacle hand. But the face came out cute and fully lit, not shadowed, the tentacles were a hand at the end of a normal arm, and the texture was a patchwork of wrong-coloured blotches. It needs a retexture before use.
- The same idea in a realistic wording with `pose_mode="a-pose"` dropped the tentacle arm entirely and gave a long cape to the floor: the A-pose mode seems to force a human template. Ask for "arms held out away from the sides" in the text instead.
- Say "chibi" and "cartoon" first; Meshy weights the start of the prompt.
- Meshy 7.1 returns 0.9-1.2 M triangles with no target count. Plan a decimate to 20-30k before rigging.
- Cost: 30 credits per textured model (20 preview + 10 refine).

## Retexturing in Meshy (round 29, the chibi)

`POST /openapi/v1/retexture` (10 credits) on our decimated 22k-tri GLB sent as a data URI, `enable_original_uv: false`, default model (Meshy 7), with:

```
Chibi cartoon game hero, cel-shaded hand-painted look: large flat colour regions, no gradients,
no baked shading, no noise. Big pointed hood in clean bone-white. Inside the hood is pitch black:
the face is hidden in deep shadow, only two glowing cyan eyes show, menacing, no skin, no nose,
no mouth. Right arm and its tentacle claw hand solid bright magenta with darker magenta tips.
Scarf round the neck bone-white. Tunic and sleeves bold teal blue, sash and belt bright crimson
red, ragged skirt teal blue, boots light grey, left glove light grey. Bold simple colours that
stand out on a dark indigo floor. No dark brown, no patterns, no text, no small details.
```

What came back: clean flat regions with no patchwork, a bone-white hood and scarf, teal tunic, crimson sash, light boots, near-black skirt (not teal). The face became a black mask with angry cyan eyes over a still-visible pale chin and nose: menacing rather than cute, but not fully shadowed, because the sculpted face is in the geometry. "Bright magenta" came out a dark wine (hue 0.90, value 0.43), so `chibi_paint.py` repaints the claw texels to the heretic's magenta. Geometry was kept exactly (21,999 tris), but Meshy rescaled it to 2 m and moved it to the origin. The output is already flat enough: `flatten_texture.py` merged the cyan eyes into the dark mask, so it isn't used on this model.

## The chibi, second pass (round 29)

What the game camera taught on the chibi: the signature limb needs to be bigger than feels right in a close-up (the claw went 1.5x before it read at rest from 13 m up), a face under a big hood can't be seen from above at all, so menace there has to come from something drawn over the hood (glowing eyes) rather than from the texture, and the pale skin left under the hood read as a chin, not shadow. The default hero is the chibi from round 29 (Zak can veto: `Game.HERO_DEFAULT`).

## Foes, chibi pass 2 (round 39)

What the game camera taught on the nine foes (`tools/comic_art/refine_pass.py`, comic-style.md "Foe models,
chibi pass 2"):

- **Faces read only if they face the camera.** From 54 degrees up a hunched skull shows its cranium: eyes 1.65x
  tipped back 30 degrees, plus a slanted black brow over each, turned blank skulls into angry faces at 70 px.
  A big open grin (the bomber; the bomber model was removed 2026-11-08, the lesson stands) needs no scowl; a
  bent-down teeth line reads only from the front.
- **One prop per foe, in its family's accent where it is the read:** the archer's bow went from thin bone to
  thick orange and now reads at a glance; the shield read as a wall only after its clutter (skulls, arrows,
  bones pinned to it) was deleted, not when it grew.
- **Families by element colour** (fx_palette.gd): legion earth orange, cult void violet, grave wind green.
  Eyes are the accent everywhere, so a crowd sorts itself by family at a glance.
- **A prop can grow too far:** the minion's cleaver at 1.6 x 1.8 across became an orange slab hiding the
  whole minion from the game camera; 1.45 x 1.25 in the body's rust reads as a weapon.
- **Heavier ink on the outer silhouette** (`ComicLook.silhouette`, 4 px pushed 0.3 m back) separates a dark
  prop (the bomber's bomb; the bomber model was removed 2026-11-08, the lesson stands) from the indigo floor
  without thickening the lines inside the body.

## The hero, chibi pass 2 (round 40)

Zak: "we can redesign him and fine tune it... chibi-esque, cartoony, not taking itself too seriously, but still badass." What the game camera taught:
- **A signature shape must break the outline from above.** The hood's point stood straight up and hid inside its own egg from 54 degrees; shearing the tip 0.2 m back (same height) made it read as a pointed hood. Judge a silhouette change by whether it pokes past the outline at the game angle.
- **Flat regions by design tones, not shading:** each part gets a body tone and at most two bands that mean something (a lining, a cuff, a sole, a hem, claw tips). The repaint is `tools/meshy_rig/chibi_repaint.py`.
- **Colour separates head from body:** a crimson scarf under the bone-white hood gives a ring of colour that the old white-on-white lost.
- **The hero's signature colour is the fx palette's void** (violet body, light tips, deep cuff), on the claw and on the weapons that grow out of it, so his body and his effects read as one set. Weapons keep only the thin ink and one element accent.
- **Attitude lives over the hood:** the grin and the squinting slits are drawn over it (`heretic_rig.gd` `GRIN`, `squint`); a face texture can't be seen from the game camera.

## The hero, presence pass (round 40, second lane)

- **The avatar must out-read the crowd.** A grown head and hood (x1.2 about the neck), a claw x1.5 and a body to
  2.05 m took him from 146 to 183 px at the game camera; the warrior is still 209 px. Area, not height, is
  what reads from 54 degrees up: the hood's girth and the claw's spread count, the peak hardly does.
- **Three values:** bone-white hood, blue-black body, violet claw with cyan eyes. A dark body on the indigo floor
  only works because the paper rim carries its edge; keep `hero_rim` on him whenever the body is dark.
- **A face under a hood is drawn, not painted:** from above the grin lands on whatever lies behind it, here the
  hood's under-chin cowl. A depth-tested dark oval behind the decals reads as the hood's shadow from every yaw.

## Checking

Look at the windowed `tests/heretic_shots.gd` (or `tests/comic_shots.gd`) game-camera shots before calling a model better. A Blender render is only for spotting problems.
