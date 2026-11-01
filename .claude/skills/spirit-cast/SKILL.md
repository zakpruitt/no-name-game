---
name: spirit-cast
description: Design or redesign an Awaken shaman spell / cast / ultimate effect as SHAPED spectral gear (giant ghost copies of the hero's own axes or body: echo, cleave, avatar, crown, rift, wheel, tomahawk, guillotine) rather than light flashes, so it feels like "no way that isn't an ultimate". Use for new casts, making an attack's spell more impressive, element forms, or ultimate set pieces.
---

# Spirit casts: shaped, not flashes

**Zak's taste:** he loved the giant spectral axe echo. He wants spells built from recognisable shapes (the hero's own axe, or the hero himself, huge and translucent) that read from the top-down camera. Light bursts and particles are seasoning, never the main event.

Read `docs/features/spirit-casts.md`: the cast table, invariants, tuning and axe-local geometry.

## Recipe
1. **Choose the shape and motion.** What does the gear do? Sweep, chop, erupt, spin, fly and return, or drop from the sky. Make it big (2–5× the hero) and a beat after the real hit.
2. **Write the script.** Create `scripts/spirit_<kind>.gd`.
   - Give it the vars `axe_mesh`, `color`, `el`, `damage` and `on_hit`, so `player._spirit()` fills them.
   - Build its meshes with `SPIRIT_ECHO.ghost(axe_mesh, color, el)`. That gives the translucent body, the rim overlay and the element form from `spirit_echo.FORMS`: earth molten spikes, water icicles, wind wing blades.
   - For the whole body, use `spirit_avatar.gd`: the Barbarian with ghost materials, timed by `speed_for(seconds)` and placed by `land_point()`.
3. **Drive it with one tween.** appear → move → impact (hits + effects) → fade → `queue_free`.
   - Hits go through `take_hit`, `Game.register_hit("cast")`, `Fx.element_hit` and `on_hit`. The callback must be `player._cast_hit`, so Ascendancy passives apply.
   - Pieces of a volley share one hit record, so a foe isn't hit by every piece. See `spirit_tomahawk.shared`.
   - `damage <= 0` means visual only, which is how ultimates layer them.
4. **Hook it up.**
   - Add a `const SPIRIT_<KIND>` and a `match` branch in `player._cast`.
   - Point an `elements.CASTS[move]` entry at it.
   - Sizes multiply by `_cast_grow()` and damage by `_cast_power()`; both grow with the chain tiers.
5. **Prewarm it.** Every new material must be drawn once at real size in `elements.prewarm`, or the first use hitches.

## Readability rules (learned the hard way)
- **Face the camera.** The camera sits behind the hero, about 55° down. A blade whose flat side faces sideways is edge-on and invisible. Lay blades flat, or turn their flats toward -fwd or up.
- **Spirit and wind spikes.** For spirit and wind, `elements.spikes()` makes light columns that hide the shapes. Skip them there.
- **Additive glow.** Use additive only for small hot cores. Big additive shapes wash out on the light floor.
- **Colour.** Pale flares need saturation to read.
- **Scale.** Huge set pieces (a 4–5× ancestor) are great once per ultimate. Don't stack them per hit.

## Verify
- **Look first.** Use the `headless-render` skill: `cast_dump --cast=<kind> --t=…`, from `top` (the game camera), plus a side view for height. Check:
  - the silhouette reads,
  - its size against the hero,
  - it lands where the hit is.
- **Element sheets.** Windowed only, when allowed: `tests/element_preview.gd` gives all elements.
- **Headless checks.**
  - `--autotest` prints `casts=` with no errors; also run it with `--start-awakened` and with `--ascend=earth|water|wind`.
  - `tests/ult_check.gd` and `tests/ascend_check.gd` PASS.
- **Docs.** Update `docs/features/spirit-casts.md` (cast table, tuning) and the CLAUDE.md elements line.
