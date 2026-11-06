---
name: combo-breaker
description: Add, tune or extend an Awaken combo breaker — a timed finisher that hangs off a combo ender (VOID_ELEMENT.BREAKERS: leap/hang with the tentacles on the foes, cue rings + timing circle, slow-motion window, right-click press → dive and the element's slam). Use for "add a breaker to <move>", "make <combo> end in a timed finisher", tuning a breaker's window, damage or look, or a new breaker kind.
---

# Combo breakers

Read `docs/features/combo-breakers.md` (the shared leap / window / dive) and the breakers table in
`docs/features/void-element.md` (what each slam does) first.

## What a breaker is
- When an ender **connects** and reaches `leap` (fraction of the move), `_state_attack` hands off to `hero_leap.start()` (`State.LEAP`).
- He leaps (`rise`, `height`, `back`) with the tentacles on what the string hit (`void_grab.seize()`), and a cue rings the landing.
- The window (`open`..`close` s after take-off) plays in slow motion; right click in it dives (`dive` s) and slams what he holds.
  Within `perfect` of `sweet` is a PERFECT (freeze, x`perfect_mult`, `awaken_perfect`). An `alt` makes L in the window a second ending.
- Too early locks it out, no press floats him down, a dash in the hang calls it off.

## Where things live
- `scripts/void_element.gd`: `_WINDOW` (shared defaults), `BREAKERS` (per breaker: `names.spirit`, `erupt`, `damage`, `leap`, `awaken`,
  `awaken_perfect`, and the keys its slam reads: `wire`, `press`, `at_spot` + `short`, `meteor`, `rip`, `collapse`, `maw`, `abyss`, `cubes`),
  `entry()`, `breaker_impact()`.
- `scripts/hero_leap.gd`: `entry_for()`, `start()`, `tick()`, the dive and impact, `window()` (`player.breaker_window()` forwards it for the prompt), `BREAKER_*`.
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

## Lessons
- **A second ending (`alt`) shows itself.** `hero_leap.options()` reads `BREAKERS[...].alt`, and the prompt draws one
  chip per ending and lights that mouse button; the cue goes two-tone. Add the `or` row in `move_list.gd` (checked by
  `move_list_check` `_check_endings`) and an `"alt"` bot string; nothing in the prompt or cue needs touching.
- **If an `alt` lands somewhere else or with a different reach** (another `short` is fine: the cue marks the effect's
  spot, not his feet), the single target ring would lie: move the cue in `_start_dive()` with the merge, or give the
  cue a second target ring.
- **Testing a real window press headless:** `Input.action_press("attack_light")` right after `await physics_frame`,
  release a frame later, with `bot_enabled` false; the bot path sets `_brk_alt` from `bot_alt` and never reads Input.
  Flip the code to the wrong button once and see the check fail (a CRLF file swallowed a sabotage edit the first time,
  so the check "passed" with broken code).
- **Prompt at the game camera:** 1600x900, Bangers 19 px names on a see-through ink capsule read in every frame of the
  hang; without the capsule a violet name on Maw's violet pool vanished. Film at full size (string_film's frames are
  800x450, half the window) before judging text.
