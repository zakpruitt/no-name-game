---
name: meshy-foe
description: Make a new foe (or any standard two-armed, two-legged character) for Awaken with Meshy and get it into the game, animated, in about fifteen minutes and 26 credits. Use this whenever the user asks for a new enemy, foe, mob, boss body or NPC, wants "another character like the brute", asks what a new character costs, or wants a new animation clip for the Meshy foes, even if they never say Meshy.
---

# A new foe with Meshy

One route, proven on the brute and the cultist (2026-11-10). Meshy makes the model and the rig. The clips
come from a shared library in the repo, so a new character costs no animation credits. Feature doc:
`docs/features/meshy-foes.md`.

**Cost per foe: 26 credits** (concept 6, model 15, rig 5). Ask Zak before spending; say the number. Log every
task in `docs/meshy-spend.md` with its id.

## The body rules (they are what makes this cheap)

A foe that breaks one of these needs the old hand-built route (`meshy-asset-pipeline` skill, days not minutes).

- Two arms, two legs, one head. No tails, wings, tentacles or extra limbs.
- No cloth below the hips: no robe, skirt, cape or long coat. Meshy fuses cloth to the legs and it tears on the first step.
- No weapon in the model. Big fists, claws or gloves instead. (A held weapon is a separate mesh on `hand.r`; not built yet.)
- T-pose, arms straight out, legs apart.
- Art direction (`docs/features/art-direction.md`): chibi, head a third of the height, three or four flat colours,
  light values that read on the indigo floor, one oversized feature.

## Steps

1. **Concept** (6 credits, 30 s). `meshy_text_to_image`, `ai_model: nano-banana-2`, `pose_mode: t-pose`. Prompt
   template below. Save the image, look at it, and show Zak if the design is his call. Redo here, not later:
   this is the cheap step.
2. **Model** (15 credits, 1 to 3 min). `meshy_image_to_3d` with `input_task_id` = the concept task,
   `model_type: smart-topology`, `ai_model: meshy-t2.5`, `target_polycount: 12000`, `texture_model: meshy-n1`,
   `pose_mode: t-pose`, `target_formats: ["glb"]`. Look at the `thumbnail_url` before rigging.
3. **Rig** (5 credits, 15 s). `meshy_rig` with `input_task_id` = the model task, `height_meters` = the game height.
4. **Download** `rigged_character_glb_url` to `tools/meshy/foes/<kind>/rigged.glb` (curl; the URL is signed, no
   key). Put the concept beside it as `concept.png`. Write `foe.json`: `{"height": 2.0}` (metres, in game).
5. **Build**: `python tools/meshy/meshy.py build <kind>`. It writes `assets/comic/<kind>.glb`, prints each clip
   and the row values, and saves stills to `tools/meshy/out/<kind>_sheet.png`. **Read the sheet**: every row
   should show the character doing that clip with no limb through the body.
6. **Row**: add the kind to `scripts/enemy_types.gd` `TYPES` with the printed `bar_height` and `attack_hit`
   (melee only), `run_foot_speed: 0.0`, and its stats (copy the nearest existing foe). Add the kind to
   `ComicLook.SILHOUETTE_KINDS` for the heavy outer line. Nothing else: `--spar=<kind>` and the checks read the table.
7. **Import and stride**: `timeout 300 godot --headless --import --path .`, then
   `timeout 120 godot --headless --path . -s tests/foe_stride_check.gd`. Copy the printed `foot N m/s` into
   `run_foot_speed`. If its `clip x` is pinned at 1.60, the foe is too fast for the clip: lower `move_speed`.
8. **Check**: `bash tools/agent.sh check`. Commit the GLB, `<kind>_paint.png`, both `.import` files, the `foes/<kind>/` folder and the row.
9. **Look** (windowed, with Zak's OK): `godot --path . -- --spar=<kind>`. Headless proves it runs, not how it looks.

## Concept prompt template

```
Chibi cartoon game enemy, a <menacing one-line idea>, full body front view, standing straight in a T-pose with
both arms held straight out to the sides, legs apart. Huge head about a third of his height <head and face,
glowing eyes>. Short stocky body, <the one oversized feature>, short thick legs with big boots. <2 or 3 big
clothing pieces, nothing below the hips>. Bold simple shapes, large flat colour regions, only four colours:
<a, b, c, d>. Flat cel-shaded comic style, thick outlines, no gradients. Cartoony and playful but badass.
No cape, no robe, no skirt, no long cloth below the hips, no small ornaments, no patterns, no text, no weapon.
Plain white background.
```

## Changing what a foe does

- **A different clip for one foe**: in its `foe.json`, `"clips": {"1H_Melee_Attack_Chop": {"from": "Attack"}}`.
  Any key of a `tools/meshy/clips.json` entry can be overridden. `"skip": ["Block_Hit"]` leaves a clip out.
- **Trim or retime**: `start` / `end` are seconds into the library clip, `seconds` is the length it is
  resampled to, `hit` the blow's time in the built clip (else `hit_scan` finds the furthest reach).
  `python tools/meshy/meshy.py build <kind> --raw --stills=12` renders the whole untrimmed clips: still k of 12
  is at `k / 11` of the clip's length.
- **A clip the library lacks** (3 credits, once, for every foe after): `meshy_list_animations` (free) for the
  id, `meshy_animate` on any foe's rig task with `action_ids`, download `animation_glb_url`, then
  `python tools/meshy/meshy.py library <file.glb>` and add a row to `clips.json`. `meshy.py clips` lists both.
  Rig tasks expire on Meshy's side; if none is live, rig any foe again (5).
- **Size**: `height` in `foe.json`, rebuild. Do not use `model_scale` in the row for a Meshy foe.

## What goes wrong

- **Meshy clips are slow and long** (2 to 10 s). Always set `seconds` near the KayKit length the game expects:
  attack 1.5, hit 0.67, death 2.0, stand up 1.3, spawn 1.5, dodge 0.83.
- **Root motion**: clips are locked in place by default (the game moves the body). `"root": "keep"` keeps the
  travel; only `Death_A` uses it.
- **Hands**: the rig has no finger bones. A hand is one lump; design mitts, fists or claws.
- **Left and right in a front concept are mirrored**: "his right" in a prompt lands on the viewer's right.
- **The stride check fails with `stored 0.00`** until you copy the number in. That is step 7, not a bug.
- **Do not edit `rigged.glb`.** Everything is rebuilt from it; fixes go in `foe.json` or `clips.json`.
