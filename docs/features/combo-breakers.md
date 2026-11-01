# Combo breakers

## What it does

A combo breaker is a powerful finishing move that asks for a timed press.
The first one hangs off **L L H (Ground Breaker)**:

1. The axe thrust lands, then the shaman **leaps** up and back (about 3 m
   high), out of reach.
2. He **hurls spectral axes** down onto a zone ahead: ghost copies of his
   own axe in the element's form (molten spikes for earth, icicles for
   water, wing blades for wind). Each one spins end over end, buries its
   head in the floor leaning back toward him, chips any foe there, and
   waits.
3. A **timing cue** rings the zone: a closing ring shrinks onto a fixed
   target ring, which glows gold while the window is open.
4. If the player presses **heavy** in the window, he **dives** onto the zone
   like a meteor. The landing detonates every spike, blasts the zone, drops
   a spectral axe and names the breaker ("Meteor Breaker", "Thunderfall",
   "Comet Breaker", "Ancestor Meteor"). A press when the rings meet is a
   **PERFECT**: more damage, more Awakening, a gold callout.
5. Pressing too early **locks it out** (the cue greys), and with no press he
   floats back down. Either way the spikes fade and nothing more happens.

He is untouchable while airborne.

The fourth one hangs off **Cyclone (Dash > H)**. At the end of the spin
he rises 1.2 m inside a six-axe sawblade, and the whirlwind drags foes
within 6 m in toward him. The cue rings close in on the hero himself. The
press drops him and flings six spectral tomahawks out in a ring, which
boomerang back, with a small blast round him ("Spirit Maelstrom", "Eye of
the Storm", "Shrapnel Storm", "Hailstorm").

**Awakened, they get bigger.** As the window opens, the dive breakers
(L L H, Charged Slam) summon a `BREAKER_ANCESTOR` (4x) spectral ancestor
behind the zone. It's timed with `spirit_avatar.speed_for()` so its axe
comes down with the hero's dive at the sweet spot. It's visual only, and if
he doesn't dive it vanishes. Flurry's wake axes grow by
`BREAKER_AWAKENED_WAKE` instead, and Cyclone throws nine tomahawks, 30%
bigger. The damage already rises with Awakening's
damage multiplier.

**The window plays in slow motion.** When it opens, the game drops to
`BREAKER_FOCUS` speed (0.6), the camera pushes in and a heartbeat plays.
The window is 0.3 s of game time, so about 0.5 s in real time. A press ends
the slow motion at once (`Game.end_slowmo()`), so the dive is full speed. A
perfect press first freezes the frame for `BREAKER_PERFECT_STOP` (0.07 s)
with the perfect-dodge chime. A too-early lockout happens before the window,
so it never slows down.

The second one hangs off **hold H (Charged Slam)**. The slam launches the
foes, then the shaman **leaps forward after them** and spins up among them
inside a spectral sawblade of five axes (the juggle). The sawblade grinds
them every 0.2 s, and because they're already airborne each grind keeps
them up. The same cue and press then slam him down onto them ("Ancestor
Skyfall", "Cyclone Drop", "Landslide", "Whirlpool Drop"). It throws no
spikes.

The third one hangs off **Flurry (L L, pause, L)**, and it stays on the
ground. After the cuts he hops back into a ready stance, and the cue rings a
spot about 6.5 m ahead. The press **dashes him through** everything along
the line, cutting each foe he passes. He turns out of the dash with a
slash, and the line behind him erupts in a wave of growing spectral axes (a
`spirit_rift`) that hits everything along it ("Spirit Step", "Lightning
Step", "Fault Rush", "Riptide Rush").

### Movement in the strings

The regular strings leave the ground too (`MOVES` `hop`: `[start, end,
height]` as fractions of the move, applied by `player._hop()`):

- **Triple Chop (L L L)** leaps onto its hit (0.9 m).
- **Launcher (L H)** rises with the foe it launches (1.5 m).
- **Spike (L H H)**, started from the Launcher's rise, comes down from that
  height onto its hit. Any move started in the air lands by its first hit,
  or by `land` if set.
- **Charged Slam** leaps into the slam (1.1 m).

Only the model moves; the body stays on the floor, so hit areas don't
change. Outside attacks, leaps and ultimates, the model settles back down
(`_physics_process`), so a dash out of a hop doesn't snap. A landing from
above 0.4 m kicks up dust.

## Files

- `scripts/player.gd`
  - `BREAKERS`: the tuning, keyed by move id.
  - `State.LEAP`. `_state_attack()` hands off to `_start_leap()` once the
    move has landed a hit and reached `leap`.
  - `_state_leap()` runs the phases: 0 rise/hang/throw/cue/press, 1 dive,
    2 fall.
  - `_juggle()` / `_drop_wheel()`: the Charged Slam's spin and its
    sawblade, a `spirit_wheel` parented to the model so it rides up with him.
    It's freed on the dive and in `_end_leap`.
  - `_breaker_ancestor()`: the Awakened ancestor. It's placed by its
    `land_point()`, so its axe head lands on the zone.
  - `_fan_release()`: Cyclone's ring of tomahawks (`fan` key). They share
    one hit record (`spirit_tomahawk.shared`), so each foe takes one hit
    per leg from the whole ring. The pull (`pull`, `pull_radius`) lives in
    `_juggle()` and skips bosses.
  - `_dash_cut()` / `_dash_wake()`: Flurry's dash breaker (`dash` key).
    The cut hits each foe within `width` once (`_brk_passed`). The wake
    raises the rift from the dash start to the hero and hits the strip
    (`_in_strip`). A `radius` of 0 skips the round blast.
  - `_breaker_pressed()`, `_throw_spike()`, `_start_dive()`,
    `_breaker_impact()`, `_breaker_callout()`, `_end_leap()`.
  - Counters `breakers_landed` and `breaker_perfects`.
- `scripts/breaker_spike.gd`: one thrown spectral axe
  (`spirit_echo.ghost()`, `size` 1.5 times `_cast_grow()`). It flies in
  spinning (`SPINS`), buries itself (`LEAN`, `TOP`) and hits on landing.
  `detonate()` blows it up out of the floor with the element's spikes, or
  it sinks away after `life`.
  `blasted` is shared by one breaker's spikes, so each foe takes the
  detonation once.
- `scripts/breaker_cue.gd`: the floor rings. `lock()` greys them out (too
  early); `hit(perfect)` flashes them.
- Combo guide: while airborne and before the press, `combo_options()`
  returns `_breaker_options()`, a single heavy row named by `breaker_name()`
  at tier 3. `combo_window()` fills `progress` toward `open` and sets `ready`
  inside `open..close`. `combo_guide.gd` itself is unchanged.
- `scripts/elements.gd`: LLH no longer has a `CASTS` entry. The breaker is
  its finisher.

## How it works

Times in `BREAKERS` are seconds after take-off (`_state_t` in `LEAP`),
except `leap`, which is a fraction of the move's animation.

- **Take-off.** `_start_leap` picks the dive zone: `zone` m ahead, clipped
  by `_clear_ahead`. It clears the input buffer and enters `LEAP`.
- **Rise and throw.** The model rises (`model.position.y`, not the body) over
  `rise` while the body hops `back` m. From `throw`, one spike leaves every
  0.03 s: a centre one, then a golden-angle spiral out to `spread`.
- **Cue.** The cue spawns at `cue`, with its times shifted by `cue`.
- **Press.** Heavy before `open` locks out. Heavy in `open..close` calls
  `_start_dive`. After `close`, phase 2 floats him down.
- **Dive.** The body moves onto the zone over `dive` while the model drops,
  leaving afterimages. On arrival, `_breaker_impact` runs:
  - `sky_impact`, `slam_fx` and `_axe_fall` for the look,
  - every spike's `detonate()`,
  - `hit_area` for `damage`, times `perfect_mult` on a perfect,
  - hitstop, shake, camera punch, Awakening gain and the callout.

## Invariants

- `_end_leap` must run on every exit (impact or fall). It resets
  `model.position.y` and `_chain_i`, and returns to `MOVE`.
- The press is read only in phase 0 and only until it has been used or
  locked out. One leap is one chance.
- A breaker's cast (if any) must finish its work on the move's hit. The
  leap replaces the rest of the move's animation.
- The slow motion is a `Game.hitstop` at `BREAKER_FOCUS` scale, so every
  timing inside the leap (`_state_t`, the cue's rings) slows with it and the
  window stays in sync. A press must call `Game.end_slowmo()`: hitstop only
  extends, so a later freeze would otherwise inherit the window's end time.
- `_end_leap` zeroes `velocity`: without that, the dash's ~45 m/s carries
  him past the zone.
- `_brk_wheel` must not outlive the leap: it's a child of the model and
  would keep grinding round him on the ground.
- Dash still cancels the move before `leap`, so a perfect-dodge dash can
  skip the breaker. That is by design: dash cancels out of anything.

## Tuning

Each `BREAKERS` entry holds all of its numbers. A negative `back` leaps
forward, `spikes: 0` throws none, and the `juggle*` keys add the sawblade
(`juggle_damage` per tick, `juggle_radius`, `juggle_axes`). `dash` makes the
press a ground dash (`pass_damage`, `width`), and `hang_anim` sets the stance
while he waits.

| Group | Keys |
|---|---|
| Height and spacing | `height`, `back`, `zone`, `spread` |
| Window (seconds) | `open`, `sweet`, `close`, `perfect` |
| Damage | `spike_damage` (landing), `detonate` (once per foe), `damage` + `radius` (the dive), `perfect_mult` |
| Awakening gain | `awaken`, `awaken_perfect` |

On one dummy in the check:

| Breaker | Perfect | Late | Miss |
|---|---|---|---|
| L L H | ~51 | 40 | 12 (spike chips) |
| Charged Slam | ~49 | 41 | 12 (juggle grinds) |
| Flurry | ~43 | 32 | 0 |
| Cyclone | ~52 + return leg | 39 + return leg | 11 (juggle grinds) |

All of these are on top of the move's own hit.

## Extending

To add a breaker to another move:

1. Add a `BREAKERS` entry under its move id.
2. Decide about its `CASTS` entry. The cast fires on the move's hit,
   before the leap: L L H dropped its cast, but the Charged Slam keeps its
   avatar chop.
3. Add a case to `tests/breaker_check.gd`.

The leap, throw and dive are generic. For a different shape of finisher,
such as a ground dash instead of a leap, branch in `_state_leap` on a
`kind` key.

## Testing

- `godot --headless --path . -s tests/breaker_check.gd`: four cases (perfect,
  late, early lockout, no press) for every `BREAKERS` entry against a dummy,
  PASS/FAIL. It also checks that the guide row names the
  breaker and is ready inside the window, that the window plays in slow
  motion, and that full speed returns afterwards. A fifth case per breaker
  is a perfect press while Awakened (via `_set_awakened()`): the dive
  breakers must summon the ancestor, and the dash one must not.
- The autotest bot presses at `sweet` and prints
  `[autotest] combo_breaker #N <id> perfect=true` when it gets through the
  leap without dash-cancelling.
- To check the look: `godot --headless --path . -s tests/cast_dump.gd --
  --cast=breaker --t=0.45 [--breaker=CH] [--el=water]` (`--el` ascends
  the hero, so the breaker takes that element; `--awakened` shows the
  ancestor, e.g. `--t=0.48` rising, `--t=-0.01` at the landing) (`--t=-0.4` = 0.4 s
  after a perfect landing; the landing's hitstop slows the effects' tweens,
  so wakes need about 0.3 s or more), then `python tools/render_hero.py
  <user://cast_dump.json> out.png side,back`.

- `godot --headless --path . -s tests/hop_check.gd`: L3 and CH hop and land
  on their hit, L H's height carries into L H H, which lands on its hit, and
  the model settles afterwards (PASS/FAIL).

## Gotchas / open questions

- The HUD has no breaker prompt (it belongs to another workstream). The
  rings and the combo guide row are the prompts.
- The window size and dive speed haven't been played by hand yet.
