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
