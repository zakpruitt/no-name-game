---
name: combo-breaker
description: Add, tune or extend an Awaken combo breaker — a timed finisher that hangs off a combo ender (VOID_ELEMENT.BREAKERS: leap/hang with the tentacles on the foes, cue rings + timing circle, slow-motion window, right-click press → dive and the element's slam). Use for "add a breaker to <move>", "make <combo> end in a timed finisher", tuning a breaker's window, damage or look, or a new breaker kind.
---

# Combo breakers

Read `docs/features/combo-breakers.md` (the shared leap / window / dive) and the breakers table in
`docs/features/void-element.md` (what each slam does) first.

## What a breaker is
- When an ender **connects** and reaches `leap` (fraction of the move), `_state_attack` hands off to `_start_leap()` (`State.LEAP`).
- He leaps (`rise`, `height`, `back`) with the tentacles on what the string hit (`void_grab.seize()`), and a cue rings the landing.
- The window (`open`..`close` s after take-off) plays in slow motion; right click in it dives (`dive` s) and slams what he holds.
  Within `perfect` of `sweet` is a PERFECT (freeze, x`perfect_mult`, `awaken_perfect`). An `alt` makes L in the window a second ending.
- Too early locks it out, no press floats him down, a dash in the hang calls it off.

## Where things live
- `scripts/void_element.gd`: `_WINDOW` (shared defaults), `BREAKERS` (per breaker: `names.spirit`, `erupt`, `damage`, `leap`, `awaken`,
  `awaken_perfect`, and the keys its slam reads: `wire`, `press`, `at_spot` + `short`, `meteor`, `rip`, `collapse`, `maw`, `abyss`, `cubes`),
  `entry()`, `breaker_impact()`.
- `scripts/player.gd`: `_breaker_for()`, `_start_leap()`, `_state_leap()`, `_start_dive()`, `_breaker_impact()`, `breaker_window()`, `BREAKER_*`.
- `scripts/void_grab.gd`: `seize()`, `seized_tick()`, `slam_seized()`, `release_seized()`.
- `scripts/breaker_cue.gd`, `breaker_prompt.gd`, `breaker_quake.gd`: cue, prompt, war cry and crater.

## Process
1. **Pick an ender.** It must have no follow-up the press would steal: right click in the window must not also be a live route.
2. **Add the entry** to `VOID_ELEMENT.BREAKERS`; `leap` at or before the move's `cancel`. Prefer existing slam keys over new code.
3. **New slam:** add its branch to `VOID_ELEMENT.breaker_impact()` (and any set-up to `player._start_dive()`).
4. **List it:** a breaker row in `scripts/move_list.gd`, and a string reaching it in `main.BOT_STRINGS` so the autotest lands it.
5. **Test it:** extend `tests/void_arm_check.gd`'s breaker checks; look at it windowed with `tests/element_shots.gd -- --only=<name>`.

```
timeout 300 godot --headless --path . -s tests/void_arm_check.gd   # void_arm_check: PASS
timeout 120 godot --headless --path . -s tests/move_list_check.gd  # [moves] PASS
timeout 120 godot --headless --path . -- --autotest                # combo_breaker #N <id> perfect=true, then done
```

Then `bash tools/agent.sh check`, update the feature docs, commit and land.
