# Enemy hit reactions

Added in Round 27 (combat feel loop). Hero-agnostic: everything here is on the
enemy's side of a hit and reads only the hero's `_fx_color()`.

## What it does

Every landed hit on a skeleton shows from its side: it snaps into a squash
that fits the hit (a tap, a big hit, a launch, a hit while juggled, a kill),
tips over along the knockback and springs back upright, and flashes in the
hero's current colour (the move's element, or gold when Awakened). A kill holds
the corpse's last pose a beat longer before it flies.

Launched foes hang at the top of their arc, tumble over backwards along the
blow, bounce once off the floor when they come down hard, skate on along the
launch and slide to a stop in a puff of dust before getting up.

When one swing hits a crowd, the foes react one after another a few
milliseconds apart (a wave sweeping across them), not all on the same frame.

Round 2: hits read their direction. A hit from below on a juggled foe
re-launches it with the launch stretch; a downward hit (a slam) drives an
airborne foe into the floor, or a grounded one flat, into a crater: it
pancakes, a dark dent pops out round it, and it lies longer and skids further.
A launch across the foe rolls it sideways instead of flipping it. Big hits
swell the foe's own ink outline for a beat. Killed in the air, the corpse
spins all the way down; a crowd killed by one blow pops one after another.

Round 3: the element slams that come down on a foe crater it: ice Deep Freeze
(before the cube closes), magma Meteor Fall (the foe it lands on) and dark Maw
(the jaws shutting). The Bone Warden gets a reduced set: a flash in the hero's
colour on every hit, and on big hits its outline swells and it squashes a
little; it never leans, tumbles or leaves the floor.

## Files

- `scripts/enemy.gd`:
  - `take_hit` calls `_hit_reaction(damage, knockback, launch, big)` **once**,
    right after the `Fx.hit_spark` / `Fx.impact` / `chain_spark` block. That
    function is the only place a hit's visual reaction lives (freeze, flash,
    squash, lean, wave delay), so a quiet hit (damage-over-time ticks on a
    crowd) can skip the whole block in one `if`.
  - `_reaction_kind()` picks the `SQUASH` key: `kill` (hp already down),
    `juggle` (hit while `AIRBORNE`), `launch`, `none` (poise held mid-windup:
    still flashes, no squash or lean), `big`, `tap`.
  - `_react()` does the flash (`Fx.flash_tint`), the squash and the lean, or a
    `_kick_tumble` for launches. `_wave_slot()` counts hits per physics frame;
    `_hit_reaction` delays `_react` by `slot * WAVE_STEP` on a tween and
    extends `_freeze_t` by the same, so the knockback starts late too.
  - `_lean()` tips `model.rotation.x/z` (the top goes with the blow, in the
    model's local frame), holds, eases back. `_face` keeps owning `rotation.y`.
  - `_gravity()` is the airborne gravity profile (`HANG_GRAVITY` near the
    apex); `launch_speed_for(height)` is its inverse (static).
  - `_tumble()` spins the model while `AIRBORNE`; `_land_from_air()` bounces
    or flops it flat and rights it; `_skid()` is the knockdown slide (`HURT`
    with `_state_t < 0`).
  - `last_squash` is the last `_squash()` amount, for the tests.
- `scripts/fx.gd`: `flash_tint(root, color, duration)`: `flash()` in a colour,
  one shared overlay material per colour (`_tint_mats`, cleared in `release`).
- `scripts/training_dummy.gd`: caps its rise with `launch_speed_for` so the cap
  stays exact under the hang profile.
- `scripts/boss.gd` overrides `take_hit` without calling super and keeps its
  own plain `Fx.flash`: the Warden does not lean, squash per kind or tumble.

- Round 2 in `enemy.gd`: `_is_spike(knockback, launch)` (static: `launch < 0`
  or `knockback.y < 0`); `_reaction_kind` adds `spike` / `crater` /
  `air_kill`, and an airborne hit with `launch >= RELAUNCH_MIN` is `launch`;
  `take_hit`'s spike branch sets the motion (down at `SPIKE_SPEED`, or
  `_knock_down(SPIKE_LIE)` on the floor); `_crater()` is the pancake + mark +
  dust + shake; `_knock_down(lie)` is the shared get-up (both axes settle);
  `_kick_tumble` picks flip or roll (`_tumble_roll`); `_ink_pulse(mult)`
  tweens this foe's own outline (`_ink_mat` from `Fx.outline_own`,
  `last_ink`); `_corpse_tumble` spins an air kill down; `_die` waits
  `_wave_delay` before `Fx.death`.
- `scripts/fx.gd`: `crater()` (hard disc + scorch splat + dust ring),
  `outline_own()` (per-character outline material and surface copies),
  `daze()` + `_star()` (the dummy's inked dizzy stars).
- `scripts/training_dummy.gd` (punching bag): `_lean` / `_squash` /
  `_knock_down` overrides, the `_bag_step` spring, `_shake_off`.

- Round 3: `scripts/void_element.gd` passes `Vector3.DOWN * DEEP_FREEZE_DOWN`
  (`_deep_freeze`), `* METEOR_DOWN` (`_tear`, the seized foe only; the splash
  stays flat) and `* MAW_DOWN` (`_maw`, through `dark_fx.quiet_hit(e, damage,
  big, knockback)`) as the knockback. Avalanche, timings, damage and routing are
  untouched. `enemy.burn_hit(damage, big, knockback)`: a quiet hit that spikes
  still runs `_hit_reaction` (the crater), with no sparks or word. A kill from
  a slam calls `_die` with `knockback.y` clamped to 0, so the death pop goes up.
- `scripts/boss.gd`: `_boss_reaction(big)` replaces its plain `Fx.flash`:
  `Fx.flash_tint` in `_hit_color()` (FLASH_TAP / FLASH_BIG), and on big hits
  `_ink_pulse(BOSS_INK)` + `_squash(BOSS_SQUASH)`. Its `take_hit` still never
  calls super, so no lean, tumble, launch or crater.

## How it works

1. `take_hit` applies damage, spawns the hit sparks, then `_hit_reaction`.
2. `_hit_reaction` sets `_freeze_t` (the per-enemy pose hold; `KILL_FREEZE`
   on a kill, else `hit_freeze` / `hit_freeze_big`) plus the wave delay, and
   runs `_react` now (slot 0) or after the delay.
3. The rest of `take_hit` sets the state and velocity as before (`AIRBORNE`
   with the launch, `HURT` with the knockback). The freeze holds everything
   in `_physics_process` until it runs out, so a delayed foe's knockback also
   starts `WAVE_STEP` later than its neighbour's.
4. In the air, `_gravity()` drops to `HANG_GRAVITY` of `AIR_GRAVITY` while
   `|velocity.y| < HANG_SPEED`; `_tumble` turns the model at `_tumble_v`,
   slowing by `TUMBLE_DRAG`. `_fall_vy` remembers the last in-air vertical
   speed, because the landing frame has already zeroed `velocity.y`.
5. On touchdown (`is_on_floor()` after 0.15 s up): a fall of at least
   `BOUNCE_MIN_FALL` and no bounce yet → `velocity.y = fall * BOUNCE_KEEP`,
   horizontal speed `fall * LAND_SLIDE` along the launch direction
   (`_air_dir`), and it stays `AIRBORNE`. Otherwise `Lie_StandUp`, dust,
   `SQUASH.land`, the tumble is tweened to the nearest full turn and zeroed,
   and `HURT` starts at `_state_t = -0.35` (lying there), during which
   `_skid` applies `SKID_FRICTION` and puffs dust every `SKID_DUST_EVERY` s
   while faster than `SKID_MIN_SPEED`.

6. Direction: a spike hit's `_react` is `spike` (kick a big tumble) or
   `crater`; `_land_from_air` checks `fall >= SPIKE_FALL` before the bounce,
   so Spike (`player._spike` sets `velocity.y = -SPIKE_DOWN` after its hit)
   craters with no flag. Craters set `_spiked` after `_knock_down` (every
   `_set_state` clears it), and `_skid` uses `SPIKE_SKID_FRICTION` then.

## Invariants

- One call to `_hit_reaction` per landed hit, beside the hit sparks. New
  reactions go inside it (or `_react`), never loose in `take_hit`.
- The lean and tumble touch only `model.rotation.x` and `.z`; yaw stays with
  `_face`. Both end at exactly 0 (the tumble settles to a multiple of TAU then
  snaps to 0), so nothing is left tilted when the state machine moves on.
- `_squash` restores `Vector3.ONE * model_scale`; split minions that change
  `model_scale` after spawning rely on that.
- `launch_speed_for` must stay the exact inverse of `_gravity()`'s profile
  (the training dummy's `MAX_HEIGHT` cap, `training_check`, depends on it).
- The wave delay rides on a tween, so it waits out hitstop like the squash.

- A spike's crater must come after `_knock_down` in the same frame: its
  `_set_state(HURT)` clears `_spiked`.
- `Fx.outline_own` is a no-op headless (like `outline`): `_ink_mat` is null
  there and `_ink_pulse` only records `last_ink`.
- A move that should crater passes a negative `knockback.y` (or `launch < 0`)
  and nothing else: the reaction, motion and crater all follow from
  `_is_spike`. Keep the flat part zero when the move pins the foe (cubes, jaws).

## Tuning (top of `enemy.gd`)

- `SQUASH` per kind, `LEAN` / `LEAN_BIG` (rad), `LEAN_HOLD`, `LEAN_TIME`.
- `FLASH_TAP` / `FLASH_BIG` (s), `FLASH_TINT` (0 = white, 1 = the hero's colour).
- `KILL_FREEZE`, `WAVE_STEP`, `WAVE_MAX`.
- `AIR_GRAVITY`, `GROUND_GRAVITY`, `HANG_SPEED`, `HANG_GRAVITY`: a 9 m/s
  launch spends 34 frames within 0.3 m of its apex (25 under plain gravity)
  and peaks at 2.91 m.
- `TUMBLE_SPEED` / `TUMBLE_BIG` / `TUMBLE_DRAG` / `TUMBLE_SETTLE`: a big
  launch turns about 5.2 rad over its flight.
- `BOUNCE_MIN_FALL`, `BOUNCE_KEEP` (a 9 m/s launch bounces 0.48 m),
  `LAND_SLIDE`, `AIR_DRAG`, `SKID_FRICTION`, `SKID_DUST_EVERY`, `SKID_MIN_SPEED`.

- Round 2: `RELAUNCH_MIN`, `SPIKE_SPEED`, `SPIKE_FALL`, `SPIKE_SLIDE`,
  `SPIKE_GROUND_SLIDE`, `SPIKE_SKID_FRICTION`, `SPIKE_LIE`, `CRATER_HOLD`,
  `CRATER_TIME`, `CRATER_RADIUS`, `CRATER_SHAKE`, `ROLL_BIAS`, `LIE_TIME`,
  `SQUASH_TIME`, `INK` per kind, `INK_TIME`, `AIR_KILL_SPIN`. Measured: a
  spiked skid 2.61 m against 0.25 m for a plain landing; a side launch rolls
  5.2 rad; an air kill spins 3.5 rad before it lands.
- Round 3: `void_element.DEEP_FREEZE_DOWN` / `METEOR_DOWN` / `MAW_DOWN` (6 m/s:
  only the sign matters to `_is_spike`; the size points the comic speed
  strokes down), `boss.BOSS_SQUASH` (1.08, 0.9, 1.08), `boss.BOSS_INK` 1.6.

## Testing

- `godot --headless --path . -s tests/enemy_feel_check.gd`: PASS/FAIL on real
  minions in the arena: squash per kind, lean direction and size, flash on,
  poise held, kill hold; the juggle's apex against `launch_speed_for`, hang
  frames, tumble, bounce, flat landing, skid, righting; four foes hit in one
  frame react `WAVE_STEP` apart. Prints the measured juggle and wave numbers.
- `godot --path . -s tests/enemy_feel_preview.gd` (windowed): a tap, a big
  hit, a launch near its apex and a knockdown in a row → `user://enemy_feel.png`.
- `tests/training_check.gd` still caps the dummy at `MAX_HEIGHT`.
- Round 2 adds to `enemy_feel_check`: re-launch stretch, side roll and its
  righting, spike from the air / Spike's fall / on the floor (crater, no
  bounce, lie, longer skid), the dummy's spring (tip, overshoot, settle),
  boing, shake-off, the ink multiplier, air-kill spin, multi-kill pop wave.
  The preview row is six foes (adds a roll and a crater); `-- --bag` shows
  three dummies (tipped, swinging back, dazed) → `user://enemy_feel_bag.png`.
- Round 3 adds to `enemy_feel_check`: Deep Freeze, Meteor Fall and Maw each run
  for real on a minion and crater it; the Warden's tap only flashes, its big
  hit squashes 0.90 and inks 1.6x with zero tilt; the bag's flags, a shake-off
  cut by a hit, the last-string tag; `--spar`. Preview `-- --slams`: each slam
  on its own minion, then the Warden → `user://enemy_feel_slams_<move>.png`;
  `-- --bag` adds a fourth dummy with its `LAST n` tag.

## Gotchas

- The flash overlay replaces `material_overlay`; `set_glow` rims are put back
  by `_physics_process` once the overlay clears, as before.
- The elastic squash and the lean run on idle-frame tweens, so a headless test
  sampling `model.scale` one frame later sees the spring mid-flight: assert
  `last_squash` instead.
- The wave tween starts on the next idle frame, so the first step lands a
  frame or two late headless; the check allows ±2 frames.
- At 0.1 s Maw's jaws cover the foe's crater in a still; the crater is there
  (`last_squash`), the jaws own that beat.
- Freeing a foe right after hitting it (mid flash / squash) floods headless
  runs with `Parameter "material" is null` (10 lines); tests wait ~1 s first.
