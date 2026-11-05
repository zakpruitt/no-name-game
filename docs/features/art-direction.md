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
- Props already huge (shield, Warden cleaver, the archer's floor-length bow) are not grown again.
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

## Checking

Look at the windowed `tests/heretic_shots.gd` (or `tests/comic_shots.gd`) game-camera shots before calling a model better. A Blender render is only for spotting problems.
