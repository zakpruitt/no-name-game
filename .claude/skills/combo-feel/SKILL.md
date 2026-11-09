---
name: combo-feel
description: Make Awaken's combo strings feel action-packed — moves that travel, hop, slam and chain (MOVES `hop` / `air` / `climb`, lunge/decay, landing slams), named combos, routing (void_route) and the combo guide. Use when the user wants combos to feel better or more dynamic, the hero to "move around" during a string, a new move/combo route, or when tuning a string's rhythm. Pair with combo-breaker for timed finishers and spirit-cast for the spectral axes.
---

# Combo feel

Pillar 1 is combat feel first. Strings should read as motion, not as standing still and swinging. The lessons
behind these rules are in the feature docs' Gotchas (`combo-breakers.md`, `void-element.md`, `element-matrix.md`,
`camera.md`, `combo-guide.md`); judging from film is the `film-and-judge` skill, the bot is `bot-strings`.

## Where things live
- **`hero_moves.MOVES`**: the per-move table. Timings are fractions of the animation:
  `hits`, `cancel`, `end`, `lunge` + `decay`, `range` / `arc` or `width`, `knockback`, `launch`, `stop` (hitstop), `shake`, `big`,
  `hop: [start, end, height]`, `air`, `climb`, `speed`, `confirm`.
- **`hero_moves.COMBOS`**: named combos (name, input, tier). Landing one plays `combo_<tier>` and shows the callout.
- **`hero_moves.void_route()`**: the single routing function (`routed()` adds the vault), used by `_next_move`, the combo guide and the checks.
  Its tables are in `scripts/void_element.gd`: `LIGHT_AFTER`, `AFTER` (right click off each weapon), `DASH_MOVE`, `CHAIN`.
- **`kit_slots.gd`**: the kit grammar's slot table; every move id on the heretic's card (`kit_check`).
- **`elements.CASTS`**: the spirit casts (see the `spirit-cast` skill). **`void_element.BREAKERS`**: timed finishers (see `combo-breaker`).
- The foe's side of a hit (knockback direction contract, craters, side vs facing): `docs/features/enemy-hit-reactions.md`.

## Movement levers
- **Hop.** `hop` lifts the model only, not the body, so hit areas don't change. A move started in the air comes down by its first
  hit (or `land`). Landing from above 0.4 m is a slam that grows with the fall (`_land_slam`). Current: L2 0.6, L3 0.9, EC 1.5, DL 0.6.
- **Air moves.** `air: true` holds the height the move started at; `climb` rises that much more by the hit (AL1 off Updraft Lash,
  IJ vaulting onto the frost spear). Moves started in the air plunge for +15% damage per metre (`plunge_mult()`) and home in on the
  nearest airborne foe (`_air_home`). Dashing out of AL1 up there is an air dash (`AIR_DASH_*`).
- **Travel.** `lunge` and `decay` set forward travel; a low `decay` keeps him moving.
- **Enders.** Enders get extra hitstop and camera push per tier (`ENDER_HITSTOP` / `ENDER_ZOOM`), a second swoosh, and the camera `kick`.
- **Dash cancels anything** after the first hit. Never remove that, even when it lets a dash skip a breaker.

## Timing contract (`tests/rhythm_check.gd` prints every number)
- **Hits land on the contact pose.** Retimed moves take `ComicLook.HERO_MOVES` hit/frames (30 fps, the frame the swing
  arrives); raw-clip moves use `MOVES.hits` as a fraction of their clip. After a re-key run `tests/contact_frames.gd`.
- **Buffer:** `BUFFER_MS` (300), two slots in press order (`hero_input.press()` / `promote()`). A press fires on the first frame past `cancel_point()`.
- **Hit-confirm:** `cancel_point()` is `cancel` on a whiff, `CANCEL_ON_HIT` of the way back to the last hit once connected
  (not before `HIT_CONFIRM_MIN` after it, nor before a breaker `leap`). Tune `cancel` as the whiff price; a per-move `confirm` shortens one hand-over.
- **String shape:** wind-ups rise opener -> mid -> ender (196 / 235 / 362 ms), the ender freezes longest, mids recover within
  260 ms, the ender in 280-400 ms. Tune with a move's `speed` (whole clip, stays in sync) and `cancel` / `end`, as named
  constants (`L1_SPEED`, `L3_SPEED`, `L3_CANCEL`, `L3_END`, `EM_SPEED`).
- **Breakers:** the window follows the rise (`BREAKER_HANG` / `TO_SWEET` / `TO_CLOSE`); `BREAKER_EARLY` holds a press 120 ms early.
- **Read the bot:** the autotest's `[rhythm]` lines give real ms per string (beats = first hit to first hit). Awakening
  (1.3x) speeds up later strings, so compare like with like. Decompose a long beat (stop + confirm + next wind-up) before tuning it.

## Process
1. **Change the data.** Prefer table edits (`MOVES`, `COMBOS`, the `VOID_ELEMENT` tables, `CASTS`, `BREAKERS`), each with a short tuning comment.
2. **List it.** Every move and combo needs a row in `scripts/move_list.gd` and a slot on the card (`kit_slots.gd`); `tests/move_list_check.gd` fails on anything `void_route()` can reach that isn't listed.
3. **Check routing.** `tests/guide_check.gd` must PASS: every guide row and its follow-up must match the real routing. Never add guide hints that aren't real routes; put timing prompts in their own widget, as `breaker_prompt.gd` does.
4. **Let the bot play it.** Add a string to `training_bot.BOT_STRINGS` if nothing reaches the move yet (`bot-strings` skill); the autotest prints the moves it started.
5. **Look.** Headless `[rhythm]` first; windowed `tests/string_film.gd -- --dir=<lane>` and `tests/element_shots.gd -- --only=<combo>` when Zak allows it (`film-and-judge`).
6. **Verify.** `bash tools/agent.sh check` (all PASS, `[autotest] done` with no errors, the counters unchanged unless you meant it).
7. **Document it.** Update the feature docs: `combo-breakers.md` (movement in the strings), `combo-guide.md`, `void-element.md`; CLAUDE.md only if a file or flag was added.
8. **Commit and land.** Work in your own worktree (`docs/agents.md`), commit with the `commit` skill, then `bash tools/agent.sh land` (`land-worktree`).
