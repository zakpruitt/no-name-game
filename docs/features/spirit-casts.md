# Spirit casts

## What it does

Every attack that has an entry in `elements.CASTS` summons a cast alongside the
swing. The shaman's casts are **spirit weapons**: big translucent copies of his
own axes (or of the shaman himself) that sweep, chop, erupt, spin, fly or fall
a beat after the real hit. They replace the old light bolts, which read as
shapeless flashes. Shaped silhouettes read from the top-down camera.

| Move | Kind | What appears |
|---|---|---|
| L1, L2 | `echo` | a giant axe sweeping the swing's arc a beat later (L2 wider) |
| L3 Triple Chop | `cleave` | two colossal axes rise either side of the target and slam inward into a V |
| LH Launcher | `crown` | three axes burst blade-up from the floor round the target, launching it |
| LHH Spike | `guillotine` | one huge axe drops blade-first from the sky onto the target |
| LLH Ground Breaker | (none) | its finisher is the Meteor combo breaker, see [combo-breakers.md](combo-breakers.md); `rift` now only raises Spirit Stampede's wake |
| H, DH Cyclone | `wheel` | 4 / 6 axes laid flat like a sawblade, whirling round the hero |
| DL, LPL Flurry | `tomahawk` | a spinning axe flung out that boomerangs back (Flurry fans two) |
| CH Charged Slam | `avatar` | a 3x spectral copy of the shaman brings the great axe down ahead |

The ultimates add visual-only spirit pieces on top of their own effects:
Ancestor's Fall summons a 5x ancestor whose axe lands with the hero, Spirit
Stampede's wake raises a rift down the charge line, Cataclysm slams six axes in
a ring and the Trinity drops an axe on every foe it strikes.

Casts **grow with the chain** (each `Fx.CHAIN_TIERS` tier: bigger, wider, more
damage) and, after an Ascendancy, each axe takes its **element's form**
(earth molten spikes, water ice, wind wing blades).

## Files

- `scripts/elements.gd` — `CASTS`: per-move kind and tuning; `prewarm()` draws a ghost once.
- `scripts/player.gd` — `_cast()` (on the move's first active frame) builds the node per kind;
  `_spirit()` is the common setup (axe mesh, colour, element, damage, `_cast_hit`);
  `_cast_grow()` / `_cast_power()` scale by chain tier; `_sky_ancestor()`, `_rush_blades()`,
  `_axe_fall()` are the ultimates' pieces.
- `scripts/spirit_echo.gd` — the `echo` cast, and the shared `ghost(mesh, color, el)` builder
  (translucent unshaded body + `Fx.rim_material()` overlay + the element's `FORMS` blades).
- `scripts/spirit_cleave.gd`, `spirit_crown.gd`, `spirit_rift.gd`, `spirit_wheel.gd`,
  `spirit_tomahawk.gd`, `spirit_guillotine.gd` — one cast each.
- `scripts/spirit_avatar.gd` — the `avatar` cast (Barbarian model with ghost materials playing
  `2H_Melee_Attack_Chop`) and `slam_fx()`, the shared floor-cracking impact.
- `tests/cast_dump.gd` — windowless renders of any cast frozen at a pose.

## How it works

1. `player._do_hit` calls `_cast(fwd)` once per move (`_hits_done == 1`).
2. `_cast` reads `CASTS[_move_id]`, computes `g = _cast_grow()`, and builds the cast node
   through `_spirit()`; size/reach fields are multiplied by `g`, damage by `_cast_power()`.
3. Each cast node orients itself to `fwd` in `_ready`, builds its ghost meshes, and drives
   everything with one tween: appear → move → impact (hits + effects) → fade → `queue_free`.
4. Hits go through `take_hit`, `Game.register_hit("cast")`, `Fx.element_hit` and `on_hit`
   (`player._cast_hit`, which applies the Awakened path passive).
5. Visual-only pieces (ultimates) pass `damage = 0`; the cast skips its hits, and
   guillotines with `heavy = false` skip hitstop and camera so volleys don't stack them.

## Invariants

- **Face the camera.** The camera sits behind the hero looking down at ~55°. A blade whose
  flat side faces sideways is edge-on and vanishes (the first straight-ahead cleave did).
  Each cast turns its blades' flat sides toward -fwd or up: echo/wheel/tomahawk lie flat,
  cleave swings in from the sides, crown/rift/guillotine turn their blades square.
- **Ghost materials are per cast** (fades tween them); `FORMS` extra blades share the body's
  material and overlay so they fade with it.
- Axe-local geometry (`1H_Axe`): handle +Y (butt -0.27, top 0.97), blade toward -X (edge
  ~-0.59), head centre (-0.3, 0.62), `hero_look.BLADE_CENTER` / `BLADE_EDGE`.
- The avatar's axe lands at 53% of `2H_Melee_Attack_Chop` (`IMPACT`), at model-space `LAND`
  (-0.6, 0, 1.4); the model is offset by `-LAND.x` so it lands on the hero's centre line.
  Re-measure both if the animation or model changes.
- Every hit callback must be `_cast_hit` (or route through it) so Ascendancy passives apply.

## Tuning

- `elements.CASTS` — per move: `damage`, sizes (`size`, `radius`, `blast`, `length`, `steps`,
  `count`, `turns`, `range`, `fan`/`spread`), targeting (`reach`, `ahead`), `launch`.
- `player.CAST_GROW` (0.15) / `CAST_POWER` (0.12) — per chain tier.
- `player.SKY_ANCESTOR` (5x), `CATACLYSM_AXES` (6), `CATACLYSM_AXE_RING` (3.8 m).
- Per script constants: timing (`rise`, `hang`, `time`, `RISE`/`HOLD`/`SINK`, `fall`),
  poses (`RAISED`, `SWEEP`, `FLARE`, `LEAN`, `TILT`), `spirit_wheel.TICK`, `spirit_tomahawk.SPIN`.
- `spirit_echo.FORMS` — per element: [radius, length, sides, axe-local base, z rotation].

## Extending

New cast kind: write `scripts/spirit_<kind>.gd` (vars `axe_mesh`, `color`, `el`, `damage`,
`on_hit` so `_spirit()` can fill them; use `SPIRIT_ECHO.ghost(axe_mesh, color, el)`), add a
`match` branch in `player._cast` with `const SPIRIT_<KIND>`, point a `CASTS` entry at it, add
it to `tests/cast_dump.gd` and render it from `top` (the game camera) before tuning.

## Testing

- `godot --headless --path . -s tests/cast_dump.gd -- --cast=<kind> --t=0..1 [--el=earth] [--size=N]`
  then `python tools/render_hero.py "%APPDATA%/Godot/app_userdata/Awaken/cast_dump.json" out.png front,top`
  (`top` = the game camera's angle; `--cast=cataclysm` = the landed ring). Skinned meshes are
  skinned on the CPU (headless can't bake them), flat decal quads are skipped.
- `godot --headless --path . -- --autotest [--start-awakened] [--ascend=X]` — no errors, `casts=`.
- `tests/ult_check.gd`, `tests/ascend_check.gd`, `tests/guide_check.gd` — PASS.

## Gotchas / open questions

- Only checked headless so far: sizes, opacity (0.5–0.65) and timing need an in-game look.
- The avatar instantiates `Barbarian.glb` per Charged Slam / Ancestor's Fall; watch for a
  hitch in a real window (pool one if so).
- A 5x ancestor may fill much of the view for ~1 s.
- Spirit/wind `ELEMENTS.spikes()` are light columns, so the rift skips them for those elements.
- One headless autotest showed `Condition "slot >= slot_max" is true` once; not reproduced
  in nine reruns.
