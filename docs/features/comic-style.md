# Comic style

## What it does

A default-off art style behind `Game.comic_style`, ported from the Blender kit in
`vendor_src/shaman_redesign/comic_poc`: comic enemy models, cut-tone shading with
halftone and hatching, thick ink, dark indigo hard-shadow lighting, onomatopoeia on
hits and a panel cut-in naming each combo. With the flag off nothing changes.

**None of the rendering has ever been seen.** It was built with `--headless` only, and
headless Godot neither compiles shaders nor draws. Run `tests/comic_shots.gd` first.

On with `--comic` (never saved), or Settings → Comic style (next run), saved as
`video/comic_style` only when on.

## Files

| File | Role |
|---|---|
| `shaders/comic_toon.gdshader` | `light()`: ink / hatched shadow / halftoned mid / light / hi; inner ink and hard rim in `fragment()` |
| `shaders/comic_emit.gdshader` | Unshaded three cut tones along `g`, for glowing materials and `C.flat` |
| `shaders/outline.gdshader` | The existing hull; new `wobble` uniform, 0 unless flagged |
| `scripts/comic_look.gd` | `ComicLook`: `TONES`/`EMITS`/`KIND_TONES`, `apply()`, `scene()`, `clip()` + `CLIPS`, `fit()` + `RIG_SCALE`, `build_environment()` |
| `scripts/comic_fx.gd` | `ComicFx` CanvasLayer: `hit()`, `combo()`, added by `main._ready` only when flagged |
| `scripts/game.gd` | `comic_style`, `comic_setting`, `sync_comic()`, `toggle_comic()` |
| `scripts/enemy.gd` | `comic_kind`, the mapping in `_play`, `_hold_clip`, `_clip_speed`, `_attach_comic_spark` |
| `scripts/boss.gd` | `COMIC_ATTACKS`, `_windup_anim` |
| `scripts/main.gd` | `_set_model`, the `_build_environment` branch, `_place` via `ComicLook.piece`, no torch `OmniLight3D` when flagged |
| `scripts/shrine_prop.gd`, `vault_prop.gd`, `spike_trap.gd` | Their pieces via `ComicLook.piece` / `comic_piece` |
| `scripts/player.gd` | `_comic_callout`, one line from `_combo_callout` |
| `tools/comic_glb.py` | Copies GLBs into `assets/comic`, moving `g` to `COLOR_0` |
| `assets/fonts/` | Bangers + `OFL.txt` (see `CREDITS.md`) |

## How it works

1. `main._ready` calls `Game.sync_comic()`, so one run never mixes the looks.
2. `main._set_model` asks `ComicLook.scene(kind)`: the GLB if flagged and present, else
   null and the KayKit model, per kind. A comic model sets `enemy.comic_kind`.
3. `enemy._ready`, for a comic model: `fit`, `apply`, and no KayKit shield, crossbow,
   bomb or tints, since the GLBs carry their own. Then `Fx.outline` as always.
4. `_play` runs each clip name through `ComicLook.clip`: the model's own clip if it has
   one, else `CLIPS`, where `""` means keep what's playing. The Warden's `Attack_Slam`
   contains the leap and landing, so `Jump_Idle` and `Jump_Land` map to `""`.
5. `_windup_anim` picks the Warden's clip per attack and sets its speed so the hit frame
   lands on the windup's end. `Block_Hit`, `Enrage` and `Bomb_Windup` use `_hold_clip`,
   since chase would otherwise replace them with run or idle next frame.

Dungeon pieces (`assets/comic/dungeon/`, built by `env_kit.py` to KayKit's names, sizes and
pivots) load through `ComicLook.piece`: comic if flagged and present, else KayKit, per piece.
`comic_*` materials set `tone_by_g`, so each stone's `g` multiplies its tone, and those in
`PIECE_INK_PX` carry a thin hull as `next_pass`. Floors and seams have none: their ink is geometry.

The toon shader's `light()` turns each light into a tone and keeps the brightest with
`DIFFUSE_LIGHT = max(...)`. `ALBEDO` is white, so that is the final colour; inner ink
sets `ALBEDO` to black. `EMISSION` carries the spot black and the rim, and
`ambient_light_disabled` keeps the palette exact. Dots and hatch use
`FRAGCOORD / VIEWPORT_SIZE.y`, a fixed number of cells per screen height.

## Invariants

- Flag off: `comic_kind == ""`, `ComicFx` has no instance, `outline.wobble` is 0, and
  `settings.cfg` gains no key.
- `--comic` is never saved: `_save_settings` writes `comic_setting` only.
- `enemy.model_scale` stays as tuned, because it sizes collision. Resize art in `RIG_SCALE`.
- Every GLB goes through `tools/comic_glb.py`. Godot only reads `COLOR_0`, and the exports
  keep `g` in `COLOR_1`, so a plain copy pins every glow to its top tone. `comic_check`
  fails on this.
- `comic_*` material names are what `env_kit._export_mat` writes; the tones come from its
  `E_*` originals. `tone_by_g` must stay 0 on enemies, whose `g` isn't a tone.
- A material with no tones renders in `FALLBACK_TONE` with a warning, and fails `comic_check`.

## Tuning

- `ComicLook.TONES`, `EMITS`: palette, copied by hand from `comic_lib.py` and `enemy_*.py`.
- `ComicLook.KEY_*`, `FILL_*`, `AMBIENT*`: lights. The shader's bands are on the POC's scale,
  so changing `KEY_ENERGY` moves every band. `AMBIENT` isn't from the POC; it only lights KayKit.
- `comic_toon`: `DOTS`, `HATCH`, `rim_width`, band constants. `Fx.COMIC_INK_PX`, `COMIC_INK_WOBBLE`.
- `ComicFx`: `WORDS`, `WORD_SCALE`, `WORD_GAP_MS`, `PANEL_FRAMES`, `CAPTION_*`.

## Extending

New dungeon piece: `python tools/comic_glb.py --env <src> <name>`, then as below. New enemy GLB: `python tools/comic_glb.py <src> <name>`, `godot --headless --import --path .`,
add any new materials to `TONES`/`EMITS`, run `comic_check`. It's picked up by kind name;
the boss is `warden`. New clip asked for in `enemy.gd`/`boss.gd`: add it to `comic_check`'s
role lists (its source scan fails until you do), then to `CLIPS` for models lacking it.

## Testing

- `godot --headless --path . -s tests/comic_check.gd`: every clip each type asks for resolves
  after mapping, tones, `g` imported, jaw ahead of head (+Z facing), fallback, and the text
  layer's logic. Part of `agent.sh check`. Proves no pixels.
- `godot --headless --path . -- --autotest --comic [--start-room=8 --boss-attack=slam]`: runs the
  comic code paths in play, without the materials or outline (both skip headless).
- `godot --path . -s tests/comic_shots.gd`: **the one windowed run that checks the look, never yet
  run.** Saves `user://comic_shots/NN_*.png` and `INDEX.txt`, saying what each should show. Under
  `--headless` its stages run without saving, which only proves they don't error.
- `tests/comic_preview.gd`: the short version of the same, enemies and text only.

## Gotchas / open questions

Assumptions only a windowed run can confirm:

- The shaders compile, including writing a varying in `fragment()` and reading it in `light()`.
- `DIFFUSE_LIGHT` accumulates across lights, so `max` works, and `LIGHT_COLOR / PI` gives the
  energy on the POC's scale. If not, every tone band shifts.
- Inner ink and rim widths. The POC's rim is thinner than its inner ink so barely shows;
  `rim_width` puts a band outside the ink, guessed at 0.05.
- The brush streaks use skinned `VERTEX`, so they may crawl on moving limbs.
- The hull is a next pass; under a hard sun it may self-shadow into blotches (the POC hit this).
- First-use shader hitch: comic materials are not in `elements.prewarm` yet.

Lights and floor effects under the flag (read from the code, none of it seen):

- Torch `OmniLight3D`s are off when flagged. Toon tones take only a light's brightness, so a torch
  could only step the wall's tone, not warm it, and six lights cost every wall and floor pixel.
  Dropped rather than judged. `env_room.py`'s drawn warm shapes round each torch are not ported.
- Kept, can't judge headless: coloured lights from shrine, vault, elites, projectiles, Awakening
  and casts. On toon they become a stepped brighter pool with no tint; on KayKit they still tint.
- The game has no `Decal` nodes. Scorch, telegraphs, rings and dust are unshaded alpha meshes, so
  they ignore the lights. Pieces match KayKit's floor height (y 0.05), so their offsets still clear
  it. Scorch's soot may vanish on the dark floor, and effects tuned for glow lose their bloom.
- `main._fade_occluders` sets `transparency` on pillars and rubble. Whether the hull fades with
  the toon pass is `29_pillar_faded.png`'s question.
- `env_room.py`'s shadow-only roof, which pools the light over the fight, is not ported.

Known gaps:

- `Bomb_Windup` has planted feet but the bomber keeps chasing while lit, so it may skate.
- Not ported: the POC's 8% element-light tint, the inked line weights from the `inkw` group
  (the `wobble` sine stands in), `iron_extra` crack veins, spot-black from fill-only areas.
