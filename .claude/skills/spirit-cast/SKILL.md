---
name: spirit-cast
description: Design or redesign an Awaken spirit cast as SHAPED spectral gear (giant ghost copies of an axe: echo, tomahawk) rather than light flashes, so it reads from the top-down camera and feels huge. Use for new casts, making an attack's spectral axe more impressive, or reworking the echo / tomahawk.
---

# Spirit casts: shaped, not flashes

**Zak's taste:** he loved the giant spectral axe echo. He wants spells built from recognisable shapes, huge and translucent,
that read from the top-down camera. Light bursts and particles are seasoning, never the main event. The game is now in the
comic style (chibi but badass, `docs/features/art-direction.md`): flat inked shapes on twos beat soft glows.

Read `docs/features/spirit-casts.md`: the cast table, invariants, tuning and axe-local geometry.

## Building one
1. **Shape.** Start from `spirit_echo.ghost(mesh, color)` (translucent unshaded body + rim) on the axe mesh `player._axe_mesh()` gives.
   Lay blades flat or turn their flat sides to the camera: edge-on blades vanish.
2. **Script.** `scripts/spirit_<kind>.gd` with vars `axe_mesh`, `color`, `el`, `damage`, `on_hit` so `player._spirit()` fills them;
   one tween drives appear, move, hit, fade, `queue_free`. Hits go through `spirit_echo.strike()`.
3. **Wire it.** A `match` branch in `player._cast` with `const SPIRIT_<KIND>`, and a `CASTS` entry in `scripts/elements.gd`.
   Sizes multiply by `_cast_grow()` and damage by `_cast_power()`; both grow with the chain tiers. `VOID_ELEMENT.NO_CAST`
   keeps a move's cast off when it would stand in front of the tentacle move that follows.
4. **Prewarm** any new material in `elements.prewarm()` at real size.

## Checking it
- **Look first**, windowed: `godot --path . -- --autotest` (saves `autotest_cast.png`) or a preview of your own in `tests/`.
  `user://` is shared by every worktree: copy screenshots out right away.
- **Verify:** `bash tools/agent.sh check`; the autotest's `casts=` count goes up and prints no errors.
