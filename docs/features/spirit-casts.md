# Spirit casts

## What it does

A few of the heretic's weapon moves summon a spectral axe that finishes the swing for him.
They're the "spirit" element: shaped, drawn things, not light flashes, and they swell with
the chain. Since 2026-11-08 the echo is drawn entirely by the designed sheets (the KayKit
Barbarian ghost-axe mesh, `hero_fx.axe_mesh()` and `AXE_SOURCE` are gone).

| Move | Kind | What it does |
|---|---|---|
| L1, L2 | echo (`scripts/spirit_echo.gd`) | A drawn axe head (`designed_finish.echo_axe`, a 1.4 m `echo_axe` sprite sheet in the palette nearest his colour) flies the swing's arc a beat after the real hit (L2 wider) over a thin ink line on the arc (`echo_line`), both in real time (`ECHO_REAL` 0.2 s) so they are gone before the next hit; the sweep hits each foe in reach once |
| DL (Dash Stab) | lash (`scripts/claw_lash.gd`) | Not a spirit: the claw whips the tentacle's inked ribbon (`void_tendril.gd`) straight out to `range` and snaps it back, the tip cutting each foe once per leg. It replaced the shaman's spinning spirit tomahawk (round 30, second pass) with the same damage (6 out, 4 back), reach (8 m), cut size (2.6 m) and timing (0.3 s out, 0.32 s back) |
| air dash | echo (`hero_moves.AIR_DASH_CUT`, `air_dash_cut()`) | An echo parented to him at his height, sweeping round the dash direction |

`AL1` and `L3` have no cast (`VOID_ELEMENT.NO_CAST`): their axes stood in front of the
tentacle move that follows. The element moves (`void_element.gd`) are not spirit casts.

## Files

- `scripts/elements.gd` `CASTS`: the per-move tuning (kind, damage, sizes, timing). `LOOK.spirit` is the palette.
- `scripts/hero_fx.gd`: `cast(hero, fwd)` (once per move, on its first hit), `spirit()` (the common
  setup: colour, element, damage), `cast_grow()` / `cast_power()`.
- `scripts/spirit_echo.gd`: the echo (the hit sweep on game time; `_start()` spawns the drawn head and
  line and poses the head along the drawn arc on real time), plus the shared `ghost(mesh, color)` /
  `ghost_mat(color)` (round 33 sleek: a ~0.3 alpha halftone fill in the palette nearest the colour, teal
  spirit or gold Awakened, inside a thin ink line with a light edge; `shaders/ghost_halftone.gdshader` +
  `ghost_ink.gdshader`, `set_alpha()`; see comic-style.md "Sleek effects"; used by the ice cube,
  `comic_column` and the Awakening column, no longer by the echo itself) and `strike()` (hit, register,
  the cast's own small hitstop, `on_hit`).
- `scripts/designed_finish.gd`: `echo_axe()` / `echo_line()` / `echo_pose()`, `ECHO_SIZE`, `ECHO_REACH`,
  `ECHO_DRAW` (the line and head sit at 0.62 of the hit reach), `ECHO_REAL`, `ECHO_ELEMENT`.
- `scripts/claw_lash.gd`: Dash Stab's lash (draws one `void_tendril` from his claw, `void_grab._hand_pos()`, to the tip; hits through `spirit_echo.strike()`).

## How it works

1. `player._do_hit` calls `hero_fx.cast(self, fwd)` once per move (`_hits_done == 1`).
2. `cast` reads `CASTS[_move_id]`, computes `g = cast_grow()`, and builds the cast node
   through `spirit()`; size/reach fields are multiplied by `g`, damage by `cast_power()`.
3. Each cast node orients itself to `fwd` in `_ready`, spawns its drawn pieces, and drives
   everything with one tween: delay, sweep (hitting as it goes), fade, `queue_free`.
4. Hits go through `take_hit`, `Game.register_hit("cast")`, a small `CAST_STOP` hitstop when no
   other stop is live, and `on_hit`.

## Invariants

- **Face the camera.** The camera sits behind the hero looking down at ~55 degrees. A blade
  whose flat side faces sideways is edge-on and vanishes. The echo lies flat; the lash is the tentacle's camera-facing ribbon.
- **Ghost materials are shared per palette** (`ghost_mat` caches one chain per palette; the fade is
  an instance parameter, `set_alpha`).
- The echo draws no mesh of a weapon: the heretic's own weapons are skinned into his rig, so they
  can't be ghosted, and the stand-in KayKit axe was removed 2026-11-08. The head is the `echo_axe`
  sheet; its hit reach is unchanged by what is drawn (`ECHO_DRAW` only moves the picture).

## Tuning

- `elements.CASTS`: per move `damage`, `radius` / `arc` / `delay` / `time` (echo),
  `range` / `size` / `back_damage` (lash).
- `player.CAST_GROW` (0.15) / `CAST_POWER` (0.12): size and damage per `Fx.CHAIN_TIERS` tier.
- `player.AIR_DASH_CUT`; per script constants: `spirit_echo.FADE_OUT` / `HEIGHT` / `CAST_STOP`,
  `designed_finish.ECHO_*`, `claw_lash.HEIGHT` / `WAVE` / `SNAP_WAVE`.

## Extending

New cast kind: write `scripts/spirit_<kind>.gd` (vars `color`, `el`, `damage`, `on_hit` so
`hero_fx.spirit()` can fill them; draw it with designed sheets through `designed_finish` /
`designed_fx.spawn`, or `SPIRIT_ECHO.ghost(mesh, color)` for a see-through mesh), add a
`match` branch in `hero_fx.cast` with `const SPIRIT_<KIND>`, point a `CASTS` entry at it, and
look at it windowed from the game camera before tuning.

## Testing

- `godot --headless --path . -- --autotest`: no errors; the `casts=` count.
- `tests/rhythm_check.gd` `_dash_stab_lash()`: the lash cuts a foe 8 m ahead out and back for 6 + 4.
- Windowed look: `godot --path . -- --autotest` saves `autotest_cast.png`.

## Gotchas / open questions

- The echo's size and timing have been through several passes (feel audit 3: half the head size;
  the real-time sweep so it is gone before the next hit); judge any change from `string_film`.
