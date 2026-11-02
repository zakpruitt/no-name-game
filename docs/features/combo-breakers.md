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
   Two presses are forgiven: one in the first `BREAKER_SPILL` (0.12 s) after
   take-off is the ender's own mashed heavy spilling over and is ignored,
   and one within `BREAKER_EARLY` (0.08 s) before `open` is held and dives
   the moment the window opens (a normal hit, not a perfect). Only a press
   between the two locks out.
6. Dash cancels anything, the hang included: a dash before the press calls
   the breaker off (`_leap_dash_out`: hovering axes cancelled, ancestor,
   cue and sawblade removed, slow motion ended; the prompt shows a miss)
   and he dashes away. Once the dive starts it's committed. The autotest
   bot is exempt (`bot_enabled`), so its dodges don't cancel the breakers
   it's there to exercise.

He is untouchable while airborne.

The fourth one hangs off **Cyclone (Dash > H)**. At the end of the spin
he rises 1.2 m inside a six-axe sawblade, and the whirlwind drags foes
within 6 m in toward him. The cue rings close in on the hero himself. The
press drops him and flings six spectral tomahawks out in a ring, which
boomerang back, with a small blast round him ("Spirit Maelstrom",
"Tempest Ring", "Shrapnel Storm", "Hailstorm").

The fifth one hangs off **Spike (L H H)**. After the slam he bounces
straight up, and a giant spectral axe appears hovering point-down over each
foe near the zone (up to six), following them as they move. The press dives
him in and every axe drops with him, a guillotine volley ("Spirit Verdict",
"Storm Verdict", "Mountain Verdict", "Frost Verdict"). With no press, the
axes fade away.

**Awakened, they get bigger.** As the window opens, the dive breakers
(L L H, Charged Slam) summon a `BREAKER_ANCESTOR` (4x) spectral ancestor
behind the zone. It's timed with `spirit_avatar.speed_for()` so its axe
comes down with the hero's dive at the sweet spot. It's visual only, and if
he doesn't dive it vanishes. Flurry's wake axes grow by
`BREAKER_AWAKENED_WAKE` instead, and Cyclone throws nine tomahawks, 30%
bigger. The damage already rises with Awakening's
damage multiplier.

**It's barbaric.** As the window opens he roars a **war cry** in the slowed
hang (`war_cry.wav` and a shockwave shell off his chest: `breaker_quake.war_cry`),
so the window has a sound cue as well as the circle. He kicks off hard
enough to crack the floor (a small `crater` without a rim), and every
landing except the dash breaker's **breaks the floor**: glowing cracks in
the element's colour split out and cool to soot, slabs heave up round the
rim tilted outward (floor stone, magma rock for earth, ice for water),
rubble flies and a `quake.wav` rumbles. On a **PERFECT** the element
answers the blow: `ERUPT` (8) strikes sweep round a ring 1.35 times the
crater (lightning, magma spikes, ice, spirit beams: `elements.storm_strike`),
and Flurry's perfect marches them down the dash line instead. These are
visual only.

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

- **L2** hops onto its hit (0.6 m): L L H reads as axe, slam, leap.
- **Triple Chop (L L L)** leaps onto its hit (0.9 m).
- **Launcher (L H)** rises with the foe it launches (1.5 m).
- **Spike (L H H)**, started from the Launcher's rise, comes down from that
  height onto its hit. Any move started in the air lands by its first hit,
  or by `land` if set.
- **Charged Slam** leaps into the slam (1.1 m).
- **Spin (neutral H)** is a leaping whirl: up 0.8 m through all three hits,
  landing by its cancel with a slam.
- **Dash Stab (Dash > L)** pounces: a low leap (0.6 m) landing on the stab.
- **Flurry (L L, pause, L)** weaves: `MOVES` `weave` (0.45 m) sways the
  model side to side, crossing over on each of its five cuts (`_weave`),
  and it eases back to centre after. Only the model moves; the swoosh
  follows it (`_swoosh` uses `global_position + model.position`). Each
  cut leaves a spectral afterimage of him (`Fx.afterimage`, the dash's
  ghost copies), so the dance reads as a blur of shamans. Afterimages are
  skipped headless, so check this one windowed.

**The air string.** Light after the Launcher goes into the air instead of
back to L1:

- **Air Slash (`AL1`)**, then **`AL2`** (the named combo "Sky Rend", L H L
  L). Both are `air` moves: `_hop` holds the height they started at, plus a
  small bob, so he stays up with the launched foe. Each cut re-juggles it
  and climbs (`climb`: AL1 +0.4 m, AL2 +0.5 m by the hit), so the string
  ends about 2.4 m up and the follow-up falls from there.
- Landing from a hop is a slam (`_land_slam`): dust, ring and shake scale
  with the highest point of the fall, from x1 at 0.4 m to `SLAM_SCALE` (x2)
  at `SLAM_FULL_HEIGHT` (2.4 m). Triple Chop out of Sky Rend lands hardest.
- Plunge: a non-air move started in the air (L H H off the launcher, Triple
  Chop off Sky Rend) deals +`PLUNGE_PER_M` (15%) damage per metre it
  started above 0.4 m, on its first hit (`player.plunge_mult()`). L H H off
  L H is about x1.17; Triple Chop off Sky Rend about x1.34.
- A plunge from `PLUNGE_AXES_FROM` (2 m: only off Sky Rend) also slams a
  fan of three giant spectral axes into the floor ahead of him
  (`_plunge_axes`: visual `_axe_fall` guillotines, `PLUNGE_AXES_SPREAD`
  32 degrees apart, the middle one first, sized by `_cast_grow()`). Look:
  `tests/cast_dump.gd -- --cast=plunge`.
- That Triple Chop lands as its own named combo, **Skyfall** (L H L L L,
  tier 2: callout, combo sound, ender hitstop and camera push). `COMBOS`
  has a `SKYFALL` entry that isn't a move, and `player.named_id()` maps L3
  from `PLUNGE_AXES_FROM` or higher onto it. The pause menu lists it, and
  the combo guide names the light row Skyfall while he's up there.
- Juggle tracking: any move started in the air turns to the nearest
  airborne foe within `AIR_HOME_RANGE` (5.5 m) and raises its lunge so it
  reaches the foe by the first hit (`_air_home`, capped at `AIR_HOME_MAX`).
  A launched foe that drifts off doesn't make the air string whiff.
- Air dash: a dash out of L H / AL1 / AL2 while at least `AIR_DASH_MIN`
  (0.6 m) up keeps his height through the dash and its follow-up window
  (`_air_dash`). The next press goes on in the air: `route()` sees `from`
  "AD" (`_route_from()`), so light is Air Slash and heavy is Spike
  (Awakened: Ancestor's Fall), not Dash Stab / Cyclone. The guide's dash
  row shows it (`dash_light()`). With juggle tracking, that lets him dash
  from one launched foe to another and keep the string going.
- Limits: one air dash per trip up (`AIR_DASHES`, `_air_dashes`, reset
  when the model is back on the floor), and `climb` stops at
  `AIR_MAX_HEIGHT` (2.8 m, plus the 0.15 m bob), so a dash-and-slash loop
  can't keep him up or lift him forever.
- The air dash leaves no floor smear. A giant spectral axe (`spirit_echo`,
  `AIR_DASH_CUT`) rides with him at his height instead, sweeping 150
  degrees round the dash direction and nicking what it passes (3 damage,
  grows with the chain: `_air_dash_cut`).
- After them, Light is Triple Chop slamming down from the air, and Heavy is
  Spike from the air, which can go on into Spike's breaker. Awakened, Heavy
  is Ancestor's Fall.
- Routing lives in `player.route()`, so the combo guide shows it, and the
  air slashes get small echo casts (`elements.CASTS`).
- Their swooshes (`player._swoosh`) and echo casts spawn at the model's
  height, so the arcs and spectral axes cut through the air with him, not
  along the floor under him.

Only the model moves; the body stays on the floor, so hit areas don't
change. Outside attacks, leaps and ultimates, the model settles back down
(`_physics_process`), so a dash out of a hop doesn't snap. A landing from
above 0.4 m is a slam: dust, a small ring in the hero's colour ahead of
him, and a light shake.

## Files

- `scripts/player.gd`
  - `BREAKERS`: the tuning, keyed by move id.
  - `State.LEAP`. `_state_attack()` hands off to `_start_leap()` once the
    move has reached `leap`, but only if it connected (`_connected`, set
    by `_do_hit()` when it hits something). A whiff plays out normally, so
    swinging at nothing never launches him into the air.
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
  - `_volley_raise()`: Spike's hovering axes (`volley` key). These are
    `spirit_guillotine`s in `wait` mode, which track their `target` until
    `drop(delay)`, or `cancel()` on a miss. `_start_dive` drops them so
    they land with him, and they share one hit record (`shared`).
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
- `scripts/breaker_quake.gd`: the barbaric look. `war_cry()` (window opens),
  `crater()` (take-off without the rim, every non-dash landing with it),
  `eruption()` / `eruption_line()` (perfects). Visual only; `stone()` is
  the slab material for spirit and wind, freed in `release()` from
  `Game._exit_tree`. Sounds: `war_cry`, `quake` in `tools/gen_sfx.py`.
- `scripts/breaker_cue.gd`: the floor rings. `lock()` greys them out (too
  early); `hit(perfect)` flashes them.
- `scripts/breaker_prompt.gd`: the timing prompt. It's a circle affixed to
  the hero, above his left shoulder on screen (`OFFSET` from his chest,
  kept `MARGIN` inside the screen; the combo guide sits on his right), so
  the important timing stays mid-screen. It follows the body, not the
  leaping model, so it holds still while he's airborne. The breaker's
  name for the element (`breaker_window()` `name`) sits under the circle,
  outlined so it reads over the floor. The heavy
  button in the middle. It fills clockwise toward full at `sweet`, and a
  thin gold band on the track marks the window from `open`. The fill turns
  gold inside the window and pulses when full. A press flashes it (gold
  and growing on a perfect), and a lockout greys it out.
  - It's kept separate from the combo guide: the guide shows only the next
    combo inputs, and nothing during a leap.
  - It reads `player.breaker_window()` every frame: `live` with the times,
    or how the last breaker `ended` ("perfect", "hit", "lock", "miss").
  - The player adds it on its own `CanvasLayer` on the first leap
    (`_breaker_prompt()`), so `hud.gd` is untouched.
  - It animates in real time, because the window plays in slow motion.
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
- `leap` must be at or before the move's `cancel`. Otherwise a buffered
  press starts the next move at the cancel point and steals the breaker
  (heavy after Spike is the Launcher; light after Flurry is L1).
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
| Window (seconds) | `open`, `sweet`, `close`, `perfect`; `BREAKER_SPILL`, `BREAKER_EARLY` (shared) |
| Damage | `spike_damage` (landing), `detonate` (once per foe), `damage` + `radius` (the dive), `perfect_mult` |
| Awakening gain | `awaken`, `awaken_perfect` |

On one dummy in the check:

| Breaker | Perfect | Late | Miss |
|---|---|---|---|
| L L H | ~51 | 40 | 12 (spike chips) |
| Charged Slam | ~49 | 41 | 12 (juggle grinds) |
| Flurry | ~43 | 32 | 0 |
| Cyclone | ~52 + return leg | 39 + return leg | 11 (juggle grinds) |
| Spike | ~55 | 44 | 0 |

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
  PASS/FAIL, plus `spill` (a press at 0.03 s is ignored and a second at
  the sweet spot still lands PERFECT) and `held` (a press 0.06 s before
  `open` dives as it opens), plus a dash out of the hang for each (Awakened, in the
  slowed window: state DASH, full speed back, ancestor and volley gone,
  ended = miss). It also checks that `breaker_window()` is live inside the
  window while the combo guide shows nothing, that each case ends the right
  way (perfect, hit, lock or miss), that the window plays in slow motion, and that full speed returns afterwards. A fifth case per breaker
  is a perfect press while Awakened (via `_set_awakened()`): the dive
  breakers must summon the ancestor, and the dash and fan ones must not.
  Two more cases run L L H through `_start_attack`: with a foe in front
  it leaps, and on a whiff it doesn't.
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

- `godot --headless --path . -s tests/hop_check.gd`: L2, L3 and CH hop and land
  on their hit; L H L L stays above 1 m through both air slashes and Triple
  Chop slams down from there; L H's height carries into L H H, which lands on its hit, and
  the model settles afterwards (PASS/FAIL).

## Gotchas / open questions

- The prompt is drawn in 2D, which headless can't render. Its preview is
  `godot --path . -s tests/breaker_prompt_preview.gd` (windowed), which
  saves five states to `user://breaker_prompt.png`. Its logic is covered
  headless by `breaker_check`, and its placement by
  `tests/prompt_follow_check.gd` (pinned at chest + `OFFSET`, follows him,
  ignores the leap height, clamped at the edges; it sets the headless root
  to 1280x720, since headless starts at 64x64). `agent.sh check` runs it.
- Not played by hand yet (everything below is only checked headless):
  breaker window sizes and dive speeds; the timing circle's spacing from
  the hero (`breaker_prompt.OFFSET`); the air dash, juggle homing
  (`AIR_HOME_*`) and the height cap (`AIR_MAX_HEIGHT`); plunge damage
  (`PLUNGE_PER_M`); Flurry's weave and afterimages (afterimages don't
  draw headless).
- The autotest bot rarely uses L H H or the air string (its routes live in
  `main.gd`), so those are covered only by `hop_check` / `breaker_check`.
