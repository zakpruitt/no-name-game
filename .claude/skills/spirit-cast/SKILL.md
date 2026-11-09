---
name: spirit-cast
description: Design or redesign an Awaken spirit cast as SHAPED spectral gear (the drawn axe-head echo, the claw lash) rather than light flashes, so it reads from the top-down camera and feels huge. Use for new casts, making an attack's spectral axe more impressive, or reworking the echo.
---

# Spirit casts: shaped, not flashes

**Zak's taste:** he loved the giant spectral axe echo. He wants spells built from recognisable shapes, huge and translucent,
that read from the top-down camera. Light bursts and particles are seasoning, never the main event. The game is now in the
comic style (chibi but badass, `docs/features/art-direction.md`): flat inked shapes on twos beat soft glows.

Read `docs/features/spirit-casts.md`: the cast table, invariants and tuning.

## Building one
1. **Shape.** The echo is a designed sprite head (`designed_finish.echo_axe`, the `echo_axe` sheet) on a thin ink line
   (`echo_line`), both on real time. Draw a new cast the same way: a designed sheet through `designed_fx.spawn` /
   `designed_finish`, or `spirit_echo.ghost(mesh, color)` (halftone fill + ink line) for a see-through mesh. There is no
   stock weapon mesh to ghost (the KayKit axe went 2026-11-08; the heretic's weapons are skinned into his rig). Lay shapes
   flat or turn their flat sides to the camera: edge-on shapes vanish.
2. **Script.** `scripts/spirit_<kind>.gd` with vars `color`, `el`, `damage`, `on_hit` so `hero_fx.spirit()` fills them;
   one tween drives delay, move, hit, fade, `queue_free`. Hits go through `spirit_echo.strike()`.
3. **Wire it.** A `match` branch in `hero_fx.cast` with `const SPIRIT_<KIND>`, and a `CASTS` entry in `scripts/elements.gd`.
   Sizes multiply by `hero_fx.cast_grow()` and damage by `cast_power()`; both grow with the chain tiers. `VOID_ELEMENT.NO_CAST`
   keeps a move's cast off when it would stand in front of the tentacle move that follows.
4. **Prewarm** any new material in `elements.prewarm()` at real size.

## Checking it
- **Look first**, windowed when Zak allows it (`film-and-judge` skill): `godot --path . -- --autotest` (saves `autotest_cast.png`) or
  `tests/string_film.gd -- --dir=<lane>`. `user://` is shared by every worktree: copy screenshots out right away.
- **Verify:** `bash tools/agent.sh check`; the autotest's `casts=` count goes up and prints no errors.
