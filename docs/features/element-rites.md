# Ascended heavies (element rites)

## What it does

Once the shaman has an Ascendancy, every heavy move lays down his element
and the **next** heavy sets it off. This turns heavy-into-heavy strings into
element combos, and it works whether or not he's Awakened.

| Ascendancy | A heavy lays down | The next heavy sets off |
|---|---|---|
| Earth (Magma) | **Lava wells** well up through the floor and burn whatever stands in them. A spin wells them under the foes it hits (and round him where there are none), Ground Breaker wells a line down the thrust, and other heavies well one on the target. | **MAGMA BURST**: every well near him erupts in a lava geyser that launches what stands in it. The geysers ripple outward from him. |
| Wind (Tempest) | **Static charge**: each foe the heavy hits gets a crackling ring over its head. | **THUNDERCLAP**: lightning arcs from his axes into the nearest charged foe, then jumps foe to foe, and a thunderbolt drops on each. Every bolt hits harder the more foes are in the chain. |
| Water (Tide) | **Soaked**: each foe the heavy hits drips, gets a ring of water at its feet and is slowed. | **FLASH FREEZE**: a frost wave rolls out from him and encases every soaked foe in ice, with ice spikes bursting under them. The heavy's own following blows then shatter the ice for the shatter bonus (`enemy.freeze`). The boss is chilled instead. |

A combo breaker's landing also sets everything off, with the breaker's
PERFECT multiplier. When something answers, its name (with `xN` for more
than one) shows over his head, unless a combo name is already showing. A
small hitstop and shake go with it. Awakened, set-offs deal
`AWAKENED_MULT` damage, wells are bigger, and a spin wells four.

## Files

- `scripts/element_rite.gd`: everything element-side.
  - `well()` makes a lava well.
  - `prime_foe()` charges or soaks a foe.
  - `set_off()` sets off every prime of an element near a point.
  - `_thunder` / `_zap` / `arc()` handle the lightning chain.
  - `_freeze` / `_encase` handle the frost wave and ice.
  - `geyser()` is the lava column.
  - `Well` is the pool node, in group `lava_wells`, with `armed()`, `drain()` and `erupt()`.
  - `Mark` is the per-foe charge or soak, a child of the enemy named `RiteMark`.
- `scripts/player.gd`:
  - `_do_hit()`: on a heavy's first hit it calls `_rite_set_off()` before the hit loop. Every foe each hit of the heavy strikes gets `RITE.prime_foe()`. On the first hit, earth gets `_rite_wells()` (after the set-off, so a heavy never erupts its own wells).
  - `_breaker_impact()` also calls `_rite_set_off()`.
  - `_rite_callout()` shows the name.
  - `rites` counts set-offs.
- `scripts/ascendancy.gd`: the path descriptions (`desc`) say what the heavies do. The old Awakened-only earth magma pools on heavies are replaced by the wells. `MagmaPool` is still used by the Volcano's bombs and `sky_impact`.

## How it works

1. A heavy (`RITE.HEAVIES`: H, LH, LHH, LLH, CH, DH, AH) reaches its first active frame.
2. `_rite_set_off()`:
   - Earth erupts every `armed()` well within `REACH` of him, nearest first, `ERUPT_STEP` apart.
   - Wind and water collect the marked foes within `REACH`, chained nearest-next from him, and remove their marks.
3. The hit loop runs, and every foe hit is primed again (wind / water). A foe hit by the setting-off heavy is therefore ready for the next one. Alternating heavies keep the chain going.
4. Earth wells its new lava. `Well.armed()` needs 0.15 s of age, so the next heavy's set-off can't catch wells from the same frame.
5. Primes expire after `PRIME_TIME` (4 s): wells drain, marks free themselves.

## Invariants

- The set-off runs **before** the heavy primes anything. Swapping the order would make every heavy set off its own primes.
- Marks are children of the enemy, so they die with it. `_marked()` skips marks that are queued for deletion.
- `set_off()` deals damage only through `take_hit` and `ELEMENTS.hit_area`, and passes `player._cast_hit` so the Awakened passives (wind lightning, water chill) still apply.
- Wells cap at `WELL_MAX`; the oldest drains first.

## Tuning

These constants are at the top of `element_rite.gd`:

- `PRIME_TIME` and `REACH`: how long and how far a prime waits.
- `WELL_RADIUS`, `WELL_DAMAGE`, `WELL_TICK`: the burn while standing in lava.
- `ERUPT_DAMAGE`, `ERUPT_LAUNCH`: the geyser hit.
- `THUNDER_DAMAGE`, `THUNDER_CHAIN` (extra per foe in the chain, capped at `CHAIN_MAX`), `ARC_STEP`.
- `FREEZE_DAMAGE`, `FREEZE_TIME`, `SOAK_SLOW`.
- `AWAKENED_MULT`.

Set-off damage also scales with `_dmg_mult` and `_cast_power()` (chain tier).

## Extending

- **A new heavy:** add its id to `RITE.HEAVIES`. If it shouldn't get the single target well, give it a placement in `_rite_wells()`.
- **A new element:** give it a `match` arm in `set_off()`, a `Mark` look (or a placed node like `Well`), and a name in `NAMES`.

## Testing

- `godot --headless --path . -s tests/rite_check.gd` checks each element on three real minions (PASS/FAIL). It covers:
  - the first spin primes and sets nothing off;
  - the second spin sets off and hits every foe beyond the spin's own damage;
  - water freezes the soaked;
  - earth's second spin wells its own lava, which waits;
  - spirit (no Ascendancy) does nothing.
  It is in `tools/agent.sh check`.
- The autotest prints `[autotest] rite <NAME> xN`. Run it with `--ascend=earth|wind|water`.
- Look: `tests/cast_dump.gd -- --cast=rite --el=earth|wind|water --t=0.5` shows the primes. `--t=-0.12` shows -t s after the set-off. Then run `python tools/render_hero.py`. The geysers' lava swirl renders white headless, and particles (bubbles, sparks, drips) don't render.

## Gotchas / open questions

- Wind's thunder and the Awakened every-3rd-hit lightning both strike. Watch for too much flashing; `Fx` already halves flares under Reduce flashing.
- Earth wells burn at `WELL_DAMAGE` without Awakening. Earth used to get pools only while Awakened, so earth is somewhat stronger than before. Wind and water gain set-offs too.
- The geysers, arcs and ice haven't been tuned in a real window yet.
