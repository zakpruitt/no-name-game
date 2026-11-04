# Meshy models into the game

## What it is

A way to make characters: generate the model in Meshy, rebuild its rig with scripts, and bring it in behind a flag. One model has been through it so far, the heretic hero ([heretic-hero.md](heretic-hero.md)). Treat what follows as what that model taught us, not a proven process.

The split is simple. Meshy supplies the mesh and the texture. Its auto-rig assumes a human, so non-human parts get bound to the nearest human bone, and we rebuild the rig.

## Making a model in Meshy

Seen on the first model:

- About 16k triangles and one 2048 texture ran as fast as the 42k hero.
- The paint and silhouette hold up through the comic lighting.
- Everything comes out fused into one shell: skirt to thighs, tentacles to each other. This is the main cost later.
- If a hand is replaced, there's no grip. Decide where weapons come from first.

Worth trying, not yet tested:

- T or A pose, with limbs and appendages well away from the body.
- Gaps between tips, and between clothing panels and legs.
- Weapons left out, as separate meshes.
- Judging the concept from above and at about 130 px tall, which is how the game shows him.

Export the rigged FBX as well as the plain one. The geometry is the same, and the rigged skeleton gives usable body joint positions.

## The steps

1. **Back up.** Copy the export outside the repo and record checksums.
2. **Store it.** Sources go in `vendor_src/meshy/source`. Make sure `vendor_src/.gdignore` exists, or Godot imports them.
3. **Audit.** Weld at seams, find parts by texture colour, map dominant bones, test bones in isolation, slice the mesh.
4. **Rig.** Set the per-character values at the top of `tools/meshy_rig/heretic_rig.py`, then build.
5. **Stress test.** `heretic_stress.py`. Compare the same vertices before and after, and look at the renders.
6. **Bake.** `heretic_bake.py` carries clips and weapons over and exports the GLB.
7. **Bring it in.** `python tools/comic_glb.py`, then `godot --headless --import --path .`, behind a flag. Commit the texture Godot extracts beside the GLB.
8. **Look and play.** Headless runs prove it doesn't error, and nothing about how it looks or feels.

Commands are in [heretic-hero.md](heretic-hero.md). The agent skill `meshy-asset-pipeline` has the full reasoning.

## How the first rig was fixed

| Problem found | Cause | Fix |
|---|---|---|
| Tentacle moved as a stiff rod | Tips bound to arm and thumb bones; its own chain ran backwards and was never keyed | Chains traced from each tip back along the surface |
| Coiling made a web between tentacles | Chain started where the tip was still fused to the limb | Start at the physical split (`TRIM`) |
| A tip pulled its neighbour | Weights by straight-line distance would cross gaps | Weights by distance along the surface |
| Skirt lifted flat with the knee | About 92% weighted to the two thighs, split down the centre | 12 spring chains blended into the hips |
| Wrist moved the hair, head moved a tentacle | Stray bones and weights | Stray bones dropped, weights renormalized |
| Tilted feet | Aligning foot bones that point different ways | Feet copy rotation only |
| Tentacles clumped at idle | Clips keyed for a man holding an axe | Limb returns to its own spread off attacks |
| Effects floating | Shaped to wrap the old arm | Left out of the GLB |

## Invariants

- The originals are never edited. The rig blend, stress renders and GLB can all be rebuilt from them.
- With the flag off the game doesn't change.
- Use the game's bone names. Extra bones are fine.

## Gotchas

- A rigged FBX looks broken because it's split at UV seams. Weld by position before judging it.
- Stretch percentages favour a rigid skirt. Check gap size in centimetres and the render.
- Automatic tip detection also finds bumps and shawls. Check tips by eye.
- Cross-section slicing doesn't work for building limb chains on a mesh this light.
- Cloth simulation doesn't suit a thick, fused shell.
- `heretic_bake.py` has the old hero's bone and weapon names written in, so a character with other clips needs those changed.

## Refining without a new model

A model that is nearly right can be refined on its rig blend without rebuilding the rig: `heretic_refine.py` swaps the texture pixels and moves vertices (thicken a limb along its normals, grow the head or a hand about a joint by skin weight). Bones and weights stay, so the bake runs as before. Commands: [heretic-hero.md](heretic-hero.md).

Flatten a Meshy texture before it goes under the cut tones (`flatten_texture.py`): its baked light and speckle fight the shader. The atlas is hundreds of small islands, so filter inside islands found from the UVs and pad each one for mipmaps.

## Generating, round 29

- `generate_3d` with a text prompt runs a preview (20 credits) and a refine (10): 30 credits per textured model. The balance is at `GET https://api.meshy.ai/openapi/v1/balance` with the key from the Blender add-on preferences; check it before and after each call.
- Meshy 7.1 returns 0.9-1.2 M triangles. Decimate before rigging.
- `pose_mode="a-pose"` dropped the tentacle arm completely. Without it, and "arms held out away from the sides" in the text, the tentacles came through.
- The chibi prompt gave the right proportions but a patchwork texture (wrong-coloured blotches on the hood and clothes). Look at the texture before paying for anything else on a model.
- A generated model has no rig. `heretic_rig.py` needs Meshy's auto-rigged FBX for body joints and weights, so budget its rigging too (not tried yet), or a new joint-placement step.

## Open questions

- Whether prompting can stop Meshy fusing parts.
- How a painted model sits beside the flat comic-style enemies. Only the hero has been tried.
- How well this works for an enemy, which has its own clip set.
