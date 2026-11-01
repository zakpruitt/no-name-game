---
name: combo-feel
description: Make Awaken's combo strings feel action-packed — moves that travel, hop, slam and chain (MOVES `hop`, lunge/decay, landing slams), named combos, routing and the combo guide. Use when the user wants combos to feel better or more dynamic, the hero to "move around" during a string, a new move/combo route, or when tuning a string's rhythm. Pair with combo-breaker for timed finishers and spirit-cast for the spell on each move.
---

# Combo feel

Pillar 1 is combat feel first. Zak described L L H as "axe, slam, jump in the air, rain spikes, time a press for a meteoric dive". Strings should read as motion, not as standing still and swinging.

## Where things live (all in `scripts/player.gd`)
- **`MOVES`**: the per-move table. Timings are fractions of the animation:
  - `hits`, `cancel`, `end`,
  - `lunge` + `decay` (forward travel),
  - `range` / `arc` or `width` (strip),
  - `knockback`, `launch`, `stop` (hitstop), `shake`, `big`,
  - `hop: [start, end, height]`.
- **`COMBOS`**: named combos (name, input, tier). Landing one plays `combo_<tier>` and shows the callout.
- **`route()`**: the single routing function, used by both `_next_move` and the combo guide. Change routing only here.
- **`elements.CASTS`**: the spirit cast that each move fires on its first hit (see the `spirit-cast` skill).
- **`BREAKERS`**: timed finishers on enders (see the `combo-breaker` skill).

## Movement levers
- **Hop.** `hop` lifts the model only, not the body, so hit areas don't change.
  - A move started in the air comes down by its first hit (or `land`); that's how L H rises and L H H drops onto the foe.
  - Landing from above 0.4 m is a slam: dust, a ring in the hero's colour and a shake (`_hop`).
  - Outside attacks, leaps and ultimates, the model settles back down, so a dash out of a hop doesn't snap.
  - Current values: L2 0.6, L3 0.9, LH 1.5, CH 1.1, H 0.8 (whirl, lands after its hits), DL 0.6.
- **Air moves.** `air: true` holds the height the move started at; `climb` rises that much more by the hit. Landing slams scale with the fall (`_land_slam`), and moves started in the air plunge for +15% damage per metre (`plunge_mult()`) and home in on the nearest airborne foe (`_air_home`). A dash up there is an air dash (`AIR_DASH_*`): route() `from` "AD" carries the string on in the air. The air string L H → AL1 → AL2 → L3 / LHH works this way. Any non-air move started in the air lands by its first hit.
- **Travel.** `lunge` and `decay` set forward travel. A low `decay` keeps him moving, as in Cyclone.
- **Enders.** Enders get extra hitstop and camera push per tier (`ENDER_HITSTOP` / `ENDER_ZOOM`), a second swoosh, and the camera `kick`.
- **Dash cancels anything** after the first hit. Never remove that, even when it lets a dash skip a breaker.

## Process
1. **Change the data.** Prefer table edits (`MOVES`, `COMBOS`, `CASTS`, `BREAKERS`), each with a short tuning comment, over new code paths.
2. **Add a hop.** For a new hop, add the move to `tests/hop_check.gd`, which checks that it leaves the ground and lands on its hit.
3. **Check routing.** For new routing, `tests/guide_check.gd` must PASS: every guide row and its follow-up must match the real routing. Never add guide hints that aren't real routes; put timing prompts in their own widget, as `breaker_prompt.gd` does.
4. **Check the look.** Use the `headless-render` skill for any visual change.
5. **Verify.** The autotest with no errors and an average of about 6.9 ms, plus `hop_check`, `breaker_check`, `ult_check`, `ascend_check` and `guide_check`.
6. **Document it.** Update CLAUDE.md (the player/MOVES lines) and the feature doc: `docs/features/combo-breakers.md` covers movement in the strings, and `combo-guide.md` covers the guide.
7. **Commit and land.** Work in your own worktree (`docs/agents.md`), commit with the `commit` skill, then `bash tools/agent.sh land`.

## Loops
When Zak asks to "keep improving combos in a loop", do one improvement per round, verify, update the docs, and report briefly. Good round types:
- another breaker kind or ender,
- more movement in a string,
- feedback (slow motion, freeze, camera, sound),
- shaped VFX upgrades,
- tuning damage or windows with the numbers shown,
- a robustness fix, such as "only on connect" or "velocity carry-over".
