---
name: combo-breaker
description: Add, tune or extend an Awaken combo breaker — a timed finisher that hangs off a combo ender (player.BREAKERS: leap/hang, cue rings + timing circle, slow-motion window, heavy press → dive / juggle slam / dash-through / tomahawk ring). Use for "add a breaker to <move>", "make <combo> end in a timed finisher", tuning a breaker's window, damage or look, or a new breaker kind.
---

# Combo breakers

Read `docs/features/combo-breakers.md` first. It has the full design, files, invariants and the damage table.

## What a breaker is
- When an ender **connects** and reaches `leap` (fraction of the move), `_state_attack` hands off to `_start_leap()` (`State.LEAP`).
- He leaps (`rise`, `height`, `back`; a negative `back` leaps forward) and waits in the air or a stance.
- Timing cues show the window:
  - floor rings at the zone (`breaker_cue.gd`),
  - the timing circle pinned up-left of the hero (`breaker_prompt.gd`, which reads `player.breaker_window()`).
- The window `open..close` plays in slow motion (`BREAKER_FOCUS`).
- Pressing heavy:
  - near `sweet` (within `perfect`) is a PERFECT: ×`perfect_mult`, a freeze-frame and more Awakening,
  - inside the window, but not near `sweet`, is a normal hit,
  - too early locks the breaker out,
  - no press floats him down.
- The combo guide shows nothing during a leap. Keep the two prompts separate.

## Kinds (keys on the `BREAKERS` entry)
| Kind | Keys | Example |
|---|---|---|
| Dive (default) | `spikes`, `spike_damage`, `detonate`, `zone`, `spread`, `radius` | L L H: throws spectral axes (`breaker_spike.gd`), dives onto them |
| Juggle | `juggle`, `juggle_damage`, `juggle_radius`, `juggle_axes` | Charged Slam: spins in a `spirit_wheel` on the model, then slams |
| Dash | `dash`, `pass_damage`, `width`, `hang_anim`, `radius: 0` | Flurry: dashes through the line, `_dash_wake` raises a rift |
| Fan | `fan`, `fan_damage`, `fan_back`, `fan_range`, plus `juggle` + `pull`, `pull_radius` | Cyclone: whirl pulls foes in, then a ring of tomahawks |
| Volley | `volley`, `volley_damage`, `volley_radius`, `volley_max`, `volley_size` | Spike: an axe hovers over each foe (`spirit_guillotine` `wait`), and all of them drop with the dive |

Names go in `names` per element (spirit, wind, earth, water). Don't reuse a power's name: check `upgrades.gd`, where an `eye_of_storm` clash already happened once.

## Adding one to a move
1. **Pick an ender.** It must have no heavy follow-up that the press would steal: LH can't have one, because heavy after LH is LHH.
   - Its cast (if any) fires on the hit, before the leap. Keep it or drop its `CASTS` entry.
2. **Add the entry.** Add a `BREAKERS` entry in `player.gd`, copying the closest kind's numbers.
   - Keep `open/sweet/close` around 0.3–0.36 / 0.42–0.5 / 0.56–0.66 s and `perfect` at 0.06.
   - Set `leap` just after the move's last hit, and at or before its `cancel`. Otherwise a buffered press starts the next move first and the breaker never happens.
3. **Add a new kind if needed.** Branch on its key in:
   - `_state_leap` (hang),
   - `_start_dive` (anim / sfx),
   - `_breaker_impact` (what lands).
   - Decide whether Awakened adds the ancestor (`_breaker_ancestor`; dive kinds only) or something else.
   - `_end_leap` must clean up anything the kind spawns on the hero, and it zeroes velocity.
4. **Cap the damage.** Volleys and multi-piece hits share one hit record, so each foe is hit once per wave:
   - `breaker_spike.blasted`,
   - `spirit_tomahawk.shared`,
   - `_brk_passed`.
   Aim for a perfect at about 45–55 on one dummy at rest, before the Awakened ×1.6.
5. **Test it.** In `tests/breaker_check.gd`, add the move's dummy spot to the per-id position map. Put it inside the dive zone, or on the dash line for a dash.
6. **Look at it.** Use the `headless-render` skill:
   - `cast_dump --cast=breaker --breaker=<id>` mid-hang (`--t=0.45`) from `top`,
   - after landing (`--t=-0.4`),
   - with `--awakened` if it changes.
7. **Document it.**
   - In `docs/features/combo-breakers.md`: what it does, the Files bullet, a Tuning row and a damage table row.
   - In `CLAUDE.md`: the combo breakers line.

## Verify (every change)
```
timeout 300 godot --headless --path . -s tests/breaker_check.gd   # [breaker] PASS
timeout 120 godot --headless --path . -s tests/hop_check.gd       # [hop] PASS
timeout 200 godot --headless --path . -- --autotest [--seed=7]    # no SCRIPT ERROR/ERROR, [autotest] combo_breaker #N <id> perfect=true
```
Then run `ult_check`, `ascend_check` and `guide_check`; all must PASS.

`breaker_check` covers, for each breaker:
- perfect, late, early lockout, no press and Awakened,
- the `breaker_window()` live/ended states,
- the slow motion and the return to full speed.

It also checks that a connected L L H triggers its breaker and a whiff doesn't.

**Perf:** the average must stay about 6.9 ms headless. Spikes logged with `enemies=0` are room loads, not breakers; re-run a seed before blaming the change.

## Gotchas
- **Slow motion uses `Game.hitstop` at `BREAKER_FOCUS`.** Any press must call `Game.end_slowmo()`, because hitstop only extends.
- **Test press timing.** The test's press lands 1–2 physics frames late. Late cases press at `close - 0.04`, not `- 0.02`.
- **Real time vs game time.** UI animations should use real time (`Time.get_ticks_usec`). The game slows during the window and freezes on a perfect.
- **`_set_awakened(true)` for Awakened tests.** Setting `awakened = true` directly turns itself off on the next tick, because `_awaken_t` is 0.
