# Feature docs

Technical notes on the features built so far: how each one works, where its
code lives, what it depends on, and how to change it without breaking it.
They're written for whoever (person or agent) works on the feature next.

`CLAUDE.md` is the map of the repo, and `ROADMAP.md` records what was done
and when. These docs cover what neither has room for: the design, the
invariants and the gotchas.

## Index

| Feature | Doc | Main code |
|---|---|---|
| Art direction: chibi but badass, proportions, shading rules, Meshy prompt template | [art-direction.md](art-direction.md) | |
| The heretic hero (the Meshy model): rebuilt rig, tentacle chains, skirt springs, weapon changes | [heretic-hero.md](heretic-hero.md) | `scripts/heretic_rig.gd`, `scripts/heretic_form_fx.gd`, `tools/meshy_rig/` |
| Meshy models into the game: how to generate them, rebuild the rig, bring them in | [meshy-pipeline.md](meshy-pipeline.md) | `tools/meshy_rig/` |
| The void arm: weapon shapes, grab, R swing, slam | [void-arm.md](void-arm.md) | `scripts/void_grab.gd`, `scripts/void_arm.gd`, `scripts/void_tendril.gd`, `scripts/hero_moves.gd` (`void_route()`) |
| Right click: the tentacle, the elements (storm, ice, magma, dark) and their breakers | [void-element.md](void-element.md) | `scripts/void_element.gd`, `scripts/hero_moves.gd` (`void_route()`) |
| Element matrix: every crossover state x every element, the improvised payoffs | [element-matrix.md](element-matrix.md) | `void_element.IMPROV`, `improvise()`, `scripts/floor_bind.gd` (`holds()`) |
| Combo breakers: the shared leap / window / dive, and strings that move (hops, air, air dash, plunge) | [combo-breakers.md](combo-breakers.md) | `scripts/hero_leap.gd`, `scripts/hero_moves.gd` (`hop()`), `scripts/breaker_cue.gd`, `scripts/breaker_prompt.gd`, `scripts/breaker_quake.gd` |
| Combo guide (next-input hints beside the hero) and the pause MOVES list | [combo-guide.md](combo-guide.md) | `scripts/combo_guide.gd`, `scripts/move_list.gd`, `hero_moves.combo_options()`, `hero_input.combo_window()` |
| Spirit casts (giant spectral axes on L1, L2, air dash; Dash Stab's claw lash) | [spirit-casts.md](spirit-casts.md) | `scripts/spirit_echo.gd`, `scripts/claw_lash.gd`, `hero_fx.cast()`, `elements.CASTS` |
| Training room and dummies (the game boots into it) | [training.md](training.md) | `scripts/training_dummy.gd`, `main._start_training()`, `scripts/pause_menu.gd` |
| Comic art style (shaders, enemy GLBs, lighting, combat text) | [comic-style.md](comic-style.md) | `scripts/comic_look.gd`, `scripts/comic_fx.gd`, `shaders/comic_toon.gdshader` |
| Impact feedback: hitstop shape, camera hit feel, impact frame, trail swell | [impact-feedback.md](impact-feedback.md) | `game.hitstop()`, `scripts/camera_rig.gd`, `scripts/impact_frame.gd`, `scripts/weapon_trail.gd` |
| Camera: distance, aim, fight framing, `--cam-*=` flags | [camera.md](camera.md) | `scripts/camera_rig.gd` |
| Enemy hit reactions (squash, lean, tinted flash, juggle hang/tumble/bounce/skid, crowd wave) | [enemy-hit-reactions.md](enemy-hit-reactions.md) | `enemy._hit_reaction()`, `enemy._gravity()`, `enemy._land_from_air()`, `Fx.flash_tint()` |
| Second hero, design draft (ideation only, no code): the dragon prince spellblade, thrown sword, dragon magic, Majesty | [../characters/dragon-prince.md](../characters/dragon-prince.md) | |

## Writing one

Add a doc when a feature spans several files, has rules that aren't obvious
from the code, or has a test of its own. Name it `<feature>.md` and add a row
to the index above. Use these sections, and skip any that don't apply:

1. **What it does**: the player-facing behaviour, in a few lines.
2. **Files**: each file and function involved, and its role.
3. **How it works**: the data flow, in the order things happen.
4. **Invariants**: what must stay true, and what breaks if it doesn't.
5. **Tuning**: the constants and tables, and what each one changes.
6. **Extending**: the steps for the likely next changes.
7. **Testing**: the commands, and what each one checks.
8. **Gotchas / open questions**

Name functions and constants rather than citing line numbers, because line
numbers go stale. Update the doc in the same commit as the code it describes.
