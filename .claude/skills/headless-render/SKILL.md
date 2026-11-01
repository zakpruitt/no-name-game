---
name: headless-render
description: Check how an Awaken effect, cast, breaker, hero form or pose looks WITHOUT opening a Godot window — dump the scene's triangles headless (tests/cast_dump.gd, tests/hero_dump.gd) and rasterize them with tools/render_hero.py, then Read the PNG. Use whenever a visual change needs a look and the user is busy (gaming, "don't open anything"), on loops, or before tuning sizes/poses of shaped VFX.
---

# Look at it without a window

Godot `--headless` can't render. Instead:
1. A test script builds the thing, freezes it, and writes its triangles to `user://*.json`.
2. `tools/render_hero.py` rasterizes those triangles flat-shaded with numpy and PIL.
3. You Read the PNG.

The render is rough, but it shows silhouettes, sizes, placement and colour, which is what tuning needs.

`user://` is `%APPDATA%/Godot/app_userdata/Awaken`. In bash, use `$APPDATA/Godot/app_userdata/Awaken`.

## Never open a window when asked not to
If Zak is playing ("don't open anything", "don't pull anything up"), run everything with `--headless`: no windowed Godot, no browser. Windowed-only checks are:
- `tests/fx_preview.gd`
- `tests/breaker_prompt_preview.gd`
- `menu_check`
- the windowed autotest

Write them anyway, and say they still need a windowed run.

## Casts, breakers, ultimates: `tests/cast_dump.gd`
```
timeout 60 godot --headless --path . -s tests/cast_dump.gd -- --cast=<kind> --t=<0..1> [--el=earth] [--size=N]
python tools/render_hero.py "$APPDATA/Godot/app_userdata/Awaken/cast_dump.json" <scratchpad>/out.png top,side
```
- **Cast kinds:** `echo | cleave | avatar | crown | rift | wheel | tomahawk | guillotine | cataclysm` (the landed ring).
- **`--t`** is progress through the cast. For cleave, negative values mean rising.
- **Combo breakers:** `--cast=breaker --breaker=LLH|CH|LPL|DH --t=<s after take-off>`.
  - `--t=-X` means X s after a perfect landing; the bot presses at the sweet spot.
  - `--el=X` ascends the hero, so the breaker takes that element.
  - `--awakened` shows the Awakened version.
- **Views:**
  - `top` is the game camera's angle. Always check it: it's what the player sees.
  - `side`, `back`, `front` and `3/4` help with heights and leans.
- **Run time:** about 1–2 min per view. Ask for only the views you need.
- **Red posts** in the dump are the dump's own dummy enemies.

## Hero look: `tests/hero_dump.gd`
```
timeout 120 godot --headless --path . -s tests/hero_dump.gd [-- --ascend=earth --awakened]
python tools/render_hero.py   # defaults: hero_dump.json -> hero_render.png
```
Skinned meshes appear in T-pose here. `cast_dump` skins them on the CPU, so the avatar shows its real pose.

## Gotchas
- **Wrap every Godot call in `timeout`.** A script error can hang it.
- **Hitstop slows the dump.** Effects tween in game time, and a landing's hitstop drops `Engine.time_scale`. A frozen dump taken "0.08 s after impact" may show almost nothing. Sample later (0.3–0.4 s) before concluding something is missing.
- **Skipped geometry:**
  - Flat decal quads (PlaneMesh/QuadMesh: scorch, rings) are skipped.
  - Particles aren't drawn.
  - Additive glow reads as flat colour.
- **2D UI** (Control `_draw`) can't be dumped. Cover its logic with a headless test, and add a windowed preview script that saves a PNG for later.
- **Extending the dump:** to dump something new, add a case to `cast_dump.gd`:
  1. Build the node.
  2. Advance physics frames until the pose you want.
  3. Set `world.process_mode = Node.PROCESS_MODE_DISABLED`.
  4. Let the shared exporter walk the tree.
- **Test scripts** that load scripts using the `Game` autoload must `load()` them inside `_initialize()`, not `preload`. A preload compiles before autoloads exist and fails with "Identifier not found: Game".

## Report
Read the PNG and say plainly what you see, especially what's wrong. For example:
- "overshot the zone by 2 m"
- "edge-on from the camera"
- "only 2 of 8 axes visible"

Then fix it and re-render. When the result is notable, send Zak the PNG with SendUserFile.
