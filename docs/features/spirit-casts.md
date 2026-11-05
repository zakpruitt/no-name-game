# Spirit casts

## What it does

A few of the heretic's weapon moves summon a giant spectral copy of an axe that finishes
the swing for him. They're the "spirit" element: shaped ghosts of a real axe mesh, not
light flashes, and they swell with the chain.

| Move | Kind | What it does |
|---|---|---|
| L1, L2 | echo (`scripts/spirit_echo.gd`) | A giant axe laid flat sweeps the swing's arc a beat after the real hit (L2 wider), each foe once, leaving a swoosh |
| DL (Dash Stab) | lash (`scripts/claw_lash.gd`) | Not a spirit: the claw whips the tentacle's inked ribbon (`void_tendril.gd`) straight out to `range` and snaps it back, the tip cutting each foe once per leg. It replaced the shaman's spinning spirit tomahawk (round 30, second pass) with the same damage (6 out, 4 back), reach (8 m), cut size (2.6 m) and timing (0.3 s out, 0.32 s back) |
| air dash | echo (`hero_moves.AIR_DASH_CUT`, `air_dash_cut()`) | An echo parented to him at his height, sweeping round the dash direction |

`AL1` and `L3` have no cast (`VOID_ELEMENT.NO_CAST`): their axes stood in front of the
tentacle move that follows. The element moves (`void_element.gd`) are not spirit casts.

## Files

- `scripts/elements.gd` `CASTS`: the per-move tuning (kind, damage, sizes, timing). `LOOK.spirit` is the palette.
- `scripts/hero_fx.gd`: `cast(hero, fwd)` (once per move, on its first hit), `spirit()` (the common
  setup: axe mesh, colour, element, damage), `cast_grow()` / `cast_power()`, `axe_mesh()`, `AXE_SOURCE`.
- `scripts/spirit_echo.gd`: the echo, plus the shared `ghost(mesh, color)` / `ghost_mat(color)` (round 33
  sleek: a ~0.3 alpha halftone fill in the palette nearest the colour, teal spirit or gold Awakened, inside a
  thin ink line with a light edge; `shaders/ghost_halftone.gdshader` + `ghost_ink.gdshader`, `set_alpha()`;
  see comic-style.md "Sleek effects") and `strike()` (hit, register, element debris, `on_hit`).
- `scripts/claw_lash.gd`: Dash Stab's lash (draws one `void_tendril` from his claw, `void_grab._hand_pos()`, to the tip; hits through `spirit_echo.strike()`).

## How it works

1. `player._do_hit` calls `hero_fx.cast(self, fwd)` once per move (`_hits_done == 1`).
2. `cast` reads `CASTS[_move_id]`, computes `g = cast_grow()`, and builds the cast node
   through `spirit()`; size/reach fields are multiplied by `g`, damage by `cast_power()`.
3. Each cast node orients itself to `fwd` in `_ready`, builds its ghost meshes, and drives
   everything with one tween: appear, move, hit, fade, `queue_free`.
4. Hits go through `take_hit`, `Game.register_hit("cast")`, `Fx.element_hit` and `on_hit`.

## Invariants

- **Face the camera.** The camera sits behind the hero looking down at ~55 degrees. A blade
  whose flat side faces sideways is edge-on and vanishes. The echo lies flat; the lash is the tentacle's camera-facing ribbon.
- **Ghost materials are per cast** (fades tween them).
- The axe is the KayKit `1H_Axe` (`hero_fx.AXE_SOURCE`, `assets/kaykit/characters/Barbarian.glb`,
  loaded once on the first cast). The heretic's own weapons are skinned into his rig, so they
  can't be ghosted. Axe-local geometry: handle +Y (butt -0.27, top 0.97), blade toward -X
  (edge ~-0.59), head centre (-0.3, 0.62).

## Tuning

- `elements.CASTS`: per move `damage`, `radius` / `arc` / `delay` / `time` (echo),
  `range` / `size` / `back_damage` (lash).
- `player.CAST_GROW` (0.15) / `CAST_POWER` (0.12): size and damage per `Fx.CHAIN_TIERS` tier.
- `player.AIR_DASH_CUT`; per script constants: `spirit_echo.FADE_IN` / `FADE_OUT` / `HEIGHT`,
  `claw_lash.HEIGHT` / `WAVE` / `SNAP_WAVE`.

## Extending

New cast kind: write `scripts/spirit_<kind>.gd` (vars `axe_mesh`, `color`, `el`, `damage`,
`on_hit` so `hero_fx.spirit()` can fill them; use `SPIRIT_ECHO.ghost(axe_mesh, color)`), add a
`match` branch in `hero_fx.cast` with `const SPIRIT_<KIND>`, point a `CASTS` entry at it, and
look at it windowed from the game camera before tuning.

## Testing

- `godot --headless --path . -- --autotest`: no errors; the `casts=` count.
- `tests/rhythm_check.gd` `_dash_stab_lash()`: the lash cuts a foe 8 m ahead out and back for 6 + 4.
- Windowed look: `godot --path . -- --autotest` saves `autotest_cast.png`; `tests/fx_preview.gd`
  for the shared effects.

## Gotchas / open questions

- The ghosts' opacity (0.5 to 0.65) and timing were tuned for the old hero; they need a pass
  against the heretic's comic look (they are the last soft, glowing pieces on his moves).
