---
name: combo-feel
description: Make Awaken's combo strings feel action-packed — moves that travel, hop, slam and chain (MOVES `hop` / `air` / `climb`, lunge/decay, landing slams), named combos, routing (void_route) and the combo guide. Use when the user wants combos to feel better or more dynamic, the hero to "move around" during a string, a new move/combo route, or when tuning a string's rhythm. Pair with combo-breaker for timed finishers and spirit-cast for the spectral axes.
---

# Combo feel

Pillar 1 is combat feel first. Strings should read as motion, not as standing still and swinging.

## Where things live
- **`player.MOVES`**: the per-move table. Timings are fractions of the animation:
  `hits`, `cancel`, `end`, `lunge` + `decay`, `range` / `arc` or `width`, `knockback`, `launch`, `stop` (hitstop), `shake`, `big`,
  `hop: [start, end, height]`, `air`, `climb`.
- **`player.COMBOS`**: named combos (name, input, tier). Landing one plays `combo_<tier>` and shows the callout.
- **`player.void_route()`**: the single routing function (`_routed()` adds the vault), used by `_next_move`, the combo guide and the checks.
  Its tables are in `scripts/void_element.gd`: `LIGHT_AFTER`, `AFTER` (right click off each weapon), `DASH_MOVE`, `CHAIN`.
- **`elements.CASTS`**: the spirit casts (see the `spirit-cast` skill). **`VOID_ELEMENT.BREAKERS`**: timed finishers (see `combo-breaker`).

## Movement levers
- **Hop.** `hop` lifts the model only, not the body, so hit areas don't change. A move started in the air comes down by its first
  hit (or `land`). Landing from above 0.4 m is a slam that grows with the fall (`_land_slam`). Current: L2 0.6, L3 0.9, EC 1.5, DL 0.6.
- **Air moves.** `air: true` holds the height the move started at; `climb` rises that much more by the hit (AL1 off Updraft Lash,
  IJ vaulting onto the frost spear). Moves started in the air plunge for +15% damage per metre (`plunge_mult()`) and home in on the
  nearest airborne foe (`_air_home`). Dashing out of AL1 up there is an air dash (`AIR_DASH_*`).
- **Travel.** `lunge` and `decay` set forward travel; a low `decay` keeps him moving.
- **Enders.** Enders get extra hitstop and camera push per tier (`ENDER_HITSTOP` / `ENDER_ZOOM`), a second swoosh, and the camera `kick`.
- **Dash cancels anything** after the first hit. Never remove that, even when it lets a dash skip a breaker.

## Timing contract (round 30; `tests/rhythm_check.gd` prints every number)
- **Hits land on the contact pose.** Retimed moves take `ComicLook.HERO_MOVES` hit/frames (30 fps, the frame the swing
  arrives); raw-clip moves use `MOVES.hits` as a fraction of their clip. After a re-key run `tests/contact_frames.gd`.
- **Buffer:** `BUFFER_MS` (300). A press fires on the first frame past `cancel_point()`.
- **Hit-confirm:** `cancel_point()` is `cancel` on a whiff, `CANCEL_ON_HIT` of the way back to the last hit once connected
  (not before `HIT_CONFIRM_MIN` after it, nor before a breaker `leap`). Tune `cancel` as the whiff price.
- **String shape:** wind-ups rise opener -> mid -> ender (196 / 235 / 362 ms), the ender freezes longest, mids recover within
  260 ms, the ender in 280-400 ms. Tune with a move's `speed` (whole clip, stays in sync) and `cancel` / `end`, as named
  constants (`L1_SPEED`, `L3_SPEED`, `L3_CANCEL`, `L3_END`, `EM_SPEED`).
- **Breakers:** the window follows the rise (`BREAKER_HANG` / `TO_SWEET` / `TO_CLOSE`); `BREAKER_EARLY` holds a press 120 ms early.
- **Read the bot:** the autotest's `[rhythm]` lines give real ms per string (beats = first hit to first hit). Awakening
  (1.3x) speeds up later strings, so compare like with like.

## The foe's side of a hit (`scripts/enemy.gd`, docs/features/enemy-hit-reactions.md)
- **Direction is a contract.** `take_hit(..., knockback, launch, ...)`: `launch >= enemy.RELAUNCH_MIN` (7) while up re-launches with the stretch; `launch < 0` or `knockback.y < 0` is a slam (crater, long skid); any fall past `SPIKE_FALL` (15 m/s) craters too. A new move that should crater passes a negative `knockback.y`.
- **Side vs facing.** Knockback across the foe's facing rolls it; along it backflips. Aim knockback where the hit visually goes.
- Visual reactions go in `_hit_reaction` / `_react` only. Sample `last_squash` / `last_ink` in headless tests, not `model.scale` (tweens run on idle frames).
- **Making a move crater:** next to its `take_hit`, pass `Vector3.DOWN * <MOVE>_DOWN` (a named const, 6 m/s) as the knockback, flat part zero if it pins the foe (Deep Freeze, Meteor Fall, Maw do). A quiet hit (`burn_hit` / `dark_fx.quiet_hit`) takes the same knockback and still craters, with no sparks. Check it with `last_squash == SQUASH.crater` after calling the real `void_element` function on a minion in `enemy_feel_check`.
- **Bosses** don't call `enemy.take_hit`: their reaction is `boss._boss_reaction` (flash, and ink + small squash on big hits). Don't add lean or tumble there: super armour must read as unmoved.
- **Trying a string on a foe that moves:** `godot --path . -- --spar=rogue` (or minion / shield / warrior), 1/3 damage; the autotest with `--spar=` prints its `hits_taken`.

## Lessons
- Measure a clip's contact frame off the tracks (`Animation.*_track_interpolate` up the bone chain): an AnimationPlayer
  doesn't pose a skeleton from a `-s` script's `_initialize`, so every sampled frame reads the rest pose.
- "Last frame at 40% of peak hand speed" matched the shaman's hand-picked hit frames on all five clips; it's the arrival of
  the swing, a frame after peak speed.
- Every `cancel` / `end` keeps its time after the hit (`retime`), so moving a hit later moves the whole move later; the
  0.25 s buffer then stopped covering a press made as L1 started (void_arm_check's by-hand spear caught it).
- A long ender wind-up hides in start-to-start gaps: read first hit to first hit (`beats`) as well.
- Headless input is a frame or three late (one `await physics_frame` can cover two steps): a timing test that needs a press
  at an exact moment sets `_state_t` itself, then presses, and must fail with the old constant (try it).

## Process
1. **Change the data.** Prefer table edits (`MOVES`, `COMBOS`, the `VOID_ELEMENT` tables, `CASTS`, `BREAKERS`), each with a short tuning comment.
2. **List it.** Every move and combo needs a row in `scripts/move_list.gd`; `tests/move_list_check.gd` fails on anything `void_route()` can reach that isn't listed.
3. **Check routing.** `tests/guide_check.gd` must PASS: every guide row and its follow-up must match the real routing. Never add guide hints that aren't real routes; put timing prompts in their own widget, as `breaker_prompt.gd` does.
4. **Let the bot play it.** Add a string to `main.BOT_STRINGS` if nothing reaches the move yet; the autotest prints the moves it started.
5. **Look.** Windowed `godot --path . -- --autotest` screenshots, `tests/element_shots.gd`, `tests/fx_preview.gd`.
6. **Verify.** `bash tools/agent.sh check` (all PASS, `[autotest] done` with no errors).
7. **Document it.** Update CLAUDE.md (the player/MOVES lines) and the feature docs: `combo-breakers.md` (movement in the strings), `combo-guide.md`, `void-element.md`.
8. **Commit and land.** Work in your own worktree (`docs/agents.md`), commit with the `commit` skill, then `bash tools/agent.sh land`.

## Loops
When Zak asks to "keep improving combos in a loop", do one improvement per round, verify, update the docs, and report briefly. Good round types:
- another breaker or ender,
- more movement in a string,
- feedback (slow motion, freeze, camera, sound),
- shaped VFX upgrades,
- tuning damage or windows with the numbers shown,
- a robustness fix, such as "only on connect" or "velocity carry-over".

## Filming and judging feel (feel audit 2026-11-04)
- **Film the string, not a still.** `godot --path . -s tests/string_film.gd` films every `BOT_STRINGS` string at 12 fps
  from the game camera, played by the real bot, plus a frame marked HIT the first drawn frame after each new hit or
  breaker slam, with an INDEX line per frame (real ms, move, hits done, `Engine.time_scale`). Contact holds and freezes
  almost never land on a 12 fps beat; without the HIT frame the sheet shows the wind-up and the recovery and skips the blow.
- **Put `time_scale` on the label.** A frame at x0.03 is a freeze, x0.6 the breaker focus, x0.05 a slam; colouring
  those labels made the hitstop beat readable on a sheet at a glance.
- **Check the hits connected before judging.** The first film's L L L H after a Grounded breaker swung at air (the combo
  count never moved, no freeze): the breaker scatters the dummies. The film gathers them in a fan in front of him per string.
- **Move the hero too, not only the foes.** Gathering the dummies in front of wherever he stood walked every later string
  into the east wall (a dark band through the pile, and their homes followed). Reset him to the middle facing up the screen.
- **A gathered pile changes the moves.** At 2.2 m Dash Stab lunges through the foes and the bot's D L H never reached
  Harpoon; in the autotest (foes further off) it does. Say which setup a frame comes from.
- **Read the next string's first second.** Callouts, banners, words and ground effects from the last string were most of
  the clutter; per-string sheets that start at the string's first press show it, stills of one move don't.
- **Zoom before judging.** At 400 px thumbnails the 1.85 m chibi is a few pixels; crop the middle 60% at 600 px
  (scratchpad `feelaudit_keys.py`) for the hero, and use the full sheet for timing.
- Tentacle moves play their Ab_ clips raw: their `hits` are `void_element.gd` `*_HIT` (contact frame / clip frames,
  `tests/contact_frames.gd` `VOID_CLIPS`), and cancel / end / leap are written as `*_HIT + offset` so they keep their
  time after the hit. The 40% hand-speed rule finds Ab_GR's yank home, not the grab: grab clips use the claw-snap rule.
- Measure contact on the model the clips were keyed for (the chibi); the round-28 heretic's shaman clips contact 1-27
  frames later, which is where round 1's "GR 0.32 / VS 0.41" came from.
- The autotest bot is repeatable only from fixed spots (`training_bot.BOT_SPOT`, dummies reset home): before that,
  breakers varied 5-7 per run from where the last string threw the foes. Read `breakers=N/N` before trusting a timing change.
- A bot that presses at `combo_window().ready` (the full BUFFER_MS early) can lose the press when hit-stop and
  Awakening shift the cancel; it presses `BOT_LEAD` (0.15 s) early instead, still well inside the buffer.

## Camera (round 36, `docs/features/camera.md`)
- Distance and lens are `camera_rig.DIST` / `FOV` / `AIM_HEIGHT`; dial by hand with `--cam-dist=` / `--cam-fov=` /
  `--cam-frame=` before changing a constant, and keep `camera_feel_check`'s hero-px and floor bounds in step.
- Callers' push-ins (`ENDER_ZOOM`, `BREAKER_FOCUS_ZOOM`, punch values) are fractions tuned at 12.5 m; the rig scales them
  (`PUNCH_GAIN`) and the metre-sized kicks (`dist / REF_DIST`), so new camera calls pass round-32-sized numbers.
- The fight framing reads `last_hit_ms` on `"enemies"`: a new foe type gets framed only if it sets that on a hit.
- **Breaker beats get the pull-out for free in phase 3.** The rig reads `_brk_phase`: in `BEATS_PHASE` it frames
  foes hit in 4 s within 22 m up to x2.0 (`HANG_FRAME_*`), and the dive (phase 1) comes back in under its punch. A
  new breaker that throws foes between press and dive should run those beats in phase 3, not add camera calls.
- **Size a throw against the cap, not the rest view.** At x2.0 the training room's both-walls throw still wants ~x3.5;
  a beat that flings foes to opposite walls will put one at the edge. Throw them to one side (along `_brk_dir`) or
  shorter if every splat must read.
- Film the beats with `string_film -- --from=N` and read the `brk=3` frames; a probe printing `_frame` and the worst
  foe NDC per frame (root `size` 1920x1080 headless) finds the cap and the ease long before a film does.

## Crossover strings (round 34)
- **Find the dead ends first.** A new route has to hang off a press that today only restarts the chain (L off AL1,
  EA, TW, XR were all `L1`): walk `void_route()` for every move and list the continuations that land on `L1` / `GR`.
  Off a breaker ender nothing else is reachable once it connects (the leap eats the press), so a long string ends in
  a new breaker rather than passing through one.
- **Make the payoff need the first element.** Read the state the first move leaves rather than routing on it
  (`void_route` stays pure): Rockslide doubles on `is_airborne()` (the gale's lift), Steam Burst only explodes
  `in_cube()` / `frozen_t` foes, Fault Line reads `void_grab.buried` (Rockslide's list), as Undertow reads `shoved`.
- **A second ending is an `alt`.** Maw's L-in-the-window became Black Ice in one dict entry plus a branch, the way
  Cold Front hangs off Worldbreaker; the bot plays it with an `"alt"` token (sets `player.bot_alt` for the string).
- **Tentacle clip + `*_HIT` = comic_check for free.** A new `X*` move on Ab_VS / Ab_LH / Ab_AF / Ab_H with
  `hits: [*_HIT]` and the clip's usual `cancel` / `end` offsets passes the contact-frame check with no new keys.
- **A move that takes over a foe another move is flying:** `thrown_foe.launch()` refuses a foe with the FLYING meta.
  `thrown_foe.cut(e)` ends the old flight (and the old node returns early on its last physics frame) first.
- **Breakers with beats:** a sequence between press and dive is a new LEAP phase (Meteor Fall's phase 3); run the
  press half (`_brk_ended`, cue, slowmo end) on the press so the prompt and `rhythm_check` see a normal dive.
- **The training room is wider than the camera.** A 14 m throw "into the wall" from the middle left the frame and
  read as the foes vanishing; 10 m kept them at the edge. Film it before trusting a throw distance.

## Three-element strings and improvising (round 34, second pass)
- **Dead ends for a long string:** heavy off EA and TW, light off IJ / EM / VR / XR / XT (and XG / XK before this
  pass) went to `GR` / `L1`. A 7-9 press string is one crossover move per hand-over hung off those, ending in a new
  breaker ender, since nothing passes through a breaker.
- **The frost spear eats every press while it stands** (`vaults()`): a string that plants it and then routes on
  (L L H, Dash H H L) needs its moves in `VOID_ELEMENT.NO_VAULT`, or H off Tow Line vaults.
- **`enemy.freeze()` staggers**, which takes a foe out of AIRBORNE: ice on a foe you just launched is set by hand
  (`freeze_aloft()`: `frozen_t`, `frozen_mult`, `cube_on`). A hit on ice queues the old cube's free, so `cube_on()`
  sees it and adds none: rename the dying cube first.
- **Void moves with `range` 0 still hit a foe inside his radius** (`_do_hit`'s `d > range + radius`): a 0-damage
  touch that thaws a frozen foe standing on him before `fire()` reads it. Payoffs that read the ice should not
  count on a foe at 0 m.
- **The bot's Harpoon only reels in one dummy** (Dash Stab lunges into the fan), so a payoff "on every frozen foe"
  must also take the one Ice Cube is bowling (`THROWN.cut` it) or the bot never connects and the breaker is missed
  (`breakers=10/11`). Print the candidates' distance / airborne / frozen / flying once (`[dbg]`) before retuning.
- **Improvise by state, not route:** a crossover marks its foes (`mark(e, "buried")`, metas with a real-time
  expiry of `ELEMENT_HOLD`) and the paying element's base moves read the mark in `fire()` wrappers, so the round-1
  bodies other lanes are editing stay untouched. Extra hits go before a move that throws (`THROWN.launch` refuses
  a flying foe, and nothing may move one in flight).
- **Shorten a hand-over with the second move's `speed`** (a named const, `XF_SPEED`): fractions keep the contact
  frame and the breaker leap in sync; the bot's `[rhythm]` beats showed Rockslide -> Fault Line 454 -> 403 ms.
