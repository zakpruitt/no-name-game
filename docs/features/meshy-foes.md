# Meshy foes

## What it is

The cheap way to add a character: Meshy makes the model and the rig, `tools/meshy/meshy.py` puts the shared
clips on it and exports the game's GLB. A new foe is about fifteen minutes and 26 Meshy credits, with no
Blender handwork and no animation cost. The brute and the cultist were made this way (2026-11-10).

It only fits a standard body: two arms, two legs, no long cloth, no weapon in the model. Anything else (the
heretic's tentacle arm) still needs the hand-built route in [meshy-pipeline.md](meshy-pipeline.md).

The steps an agent follows are in the `meshy-foe` skill.

## How it works

- **Every Meshy auto-rig has the same 24 bones.** So a clip bought on one character fits all of them.
- **The clip library** (`tools/meshy/library/*.json`, 16 clips, 1.5 MB) stores each clip as rotations away from
  the rest pose, in armature space, plus the hips' travel in hip heights. That form does not depend on the
  character's proportions.
- **`tools/meshy/clips.json`** maps the clip names `enemy.gd` plays (the KayKit names) to library clips, with a
  trim and a target length each.
- **`meshy.py build <kind>`** runs headless Blender (`blend_meshy.py`): loads `foes/<kind>/rigged.glb`, scales
  it to `foe.json`'s `height`, renames Meshy's bones to the game's (`hips`, `hand.r`, `foot.l`, ...), turns each
  limb's rest direction onto the clip's so a low-armed model still swings where the clip swings, writes the
  clips, names the material `P_MeshyPaint` and exports `assets/comic/<kind>.glb`. It also renders stills of
  every clip and prints `bar_height` and `attack_hit`.
- **In the game** a foe is one row in `enemy_types.TYPES`. `ComicLook.PAINTED.P_MeshyPaint` draws the texture
  through the cut tones. `spar.kinds()` and `spar.ranged()` read the table, so the row is also the `--spar=` kind.

## Files

| Path | What |
|---|---|
| `tools/meshy/meshy.py` | `build <kind>`, `library <glb>...`, `clips` |
| `tools/meshy/blend_meshy.py` | the Blender side |
| `tools/meshy/clips.json` | game clip -> library clip, trims, lengths |
| `tools/meshy/library/` | the shared clips |
| `tools/meshy/foes/<kind>/` | `rigged.glb` (Meshy's download, never edited), `concept.png`, `foe.json` |
| `tools/meshy/out/` | stills and reports (not committed) |
| `assets/comic/<kind>.glb`, `<kind>_paint.png` | what the game loads |

## Numbers

| | Credits |
|---|---|
| Concept image (nano-banana-2) | 6 |
| Model (meshy-t2.5, 12k triangles, meshy-n1 texture) | 15 |
| Auto-rig (walk and run included) | 5 |
| **A new foe** | **26** |
| A new library clip, once | 3 |

The library cost 42 credits once. Both foes are about 12.6k triangles with one 2048 texture; the GLBs are
2.5 and 3.2 MB.

## Invariants

- `rigged.glb` is never edited. The GLB is rebuilt from it, `foe.json`, `clips.json` and the library.
- A Meshy foe carries the clip names the KayKit foes carry, so `enemy.gd` has no Meshy branch.
- Adding a foe touches one table row (plus `SILHOUETTE_KINDS` for the heavy line).

## Not built

- **Held weapons.** The rig has no fingers and the models have no weapon. A weapon would be a separate mesh on
  `hand.r`, and the clips were not chosen for one.
- **A playable hero by this route.** The hero plays about fifty clips with contact frames; the library has foe
  clips only.
- **Props and room pieces.** They use the comic `g` palette materials, not a painted texture.
- **Feel.** The clips are Meshy's stock motion, retimed. Nobody has tuned them by eye in play.
