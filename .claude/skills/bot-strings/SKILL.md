---
name: bot-strings
description: Add or change an entry in Awaken's autotest bot (`scripts/training_bot.gd` `BOT_STRINGS`): the slot / upgrade / room / spar keys, the setup tokens (`alt`, `line`, `out`, `face`, `spread`, `wall`, `wait`, `foe`, ...), `BOT_SPOT` repeatability, `AUTOTEST_MAX`, the `[autotest]` / `[kit]` / `[env]` / `[improv]` counters `agent.sh check` asserts, strings that strand the bot, and press timing. Use when a new move, breaker, ending, kit slot, upgrade or room piece needs the bot to reach it, when `breakers=` / `strings=` / `[kit]` / `[env]` stop matching, or when the autotest runs past its cap.
---

# Bot strings

Read the header of `scripts/training_bot.gd` and `BOT_STRINGS` first: the token names below are the live ones, and
the comments beside each entry say what it is for. The bot plays every entry once from the same spots
(`BOT_SPOT`; the dummies reset home), so the run is repeatable and `agent.sh check` can assert counts.

## An entry
`{"slot": <KitSlots id or list>, "tokens": [...]}` plays a kit slot's moves; `{"upgrade": <Kit id>, ...}` plays
only with that upgrade on (the `--kit=full` run); `"room": "pieces"` only in the room with pieces; `"spar": "melee"|
"ranged"` only with a `--spar=` foe of that sort. Presses: `L` light, `H` right click, `D` dash, `hold` (Overwhelm),
`C` / `CP` / `W` wait for a live foe's strike / perfect / windup. Setup tokens (anywhere before the presses,
`BOT_SETUP`): `alt` (the window's press is L, the `alt` ending), `line` (dummies in a column along his aim),
`spread` / `far` / `ring` / `wall` (crowd shapes, the wall ahead), `face` (aim at the nearest foe every press),
`out` (lets him dash out of a breaker hang), `wait` (hold the next press until he stands, so L is L1 not Dash
Stab), `counter`, `pillar` / `keg` / `grate` / `torch` / `hook` / `pool` / `brazier` (stand by that piece),
`stab` / `tide`, `foe` / `settle` (spar). Pick the shape the move is for: from the default fan Dash Stab lunges into
the first dummy and Harpoon only ever reels that one (`line` fixed it); a payoff "on every frozen foe" needs the cube
Ice Cube is still bowling. Print the candidates once (`[dbg]` distance / airborne / frozen / flying) before retuning a move.

## What the check asserts
`agent.sh check` runs `--autotest` plain and with `--kit=full --room=pieces` and fails unless the `[autotest] done`
line has `breakers=N/N strings=N/N endings_n=N/N`, `[kit]` has `slots=N/N windows=N/N upgrades=N/N`, and (pieces
room) `[env]` has `pieces=N/N` and every built verb above 0. So:
- every kit slot, breaker, window ending (each `BREAKERS` name and its `alt`), upgrade and piece verb needs a string
  that lands it; a new one of any of those is a new entry (or an `alt` twin) in the same commit;
- breakers count distinct ids landed (`player.breakers_seen`); endings are listed separately. `hits=` and
  `max_combo=` vary run to run (foe placement): compare `breakers=`, `strings=`, `endings_n=`, `moves=`, `casts=`,
  `[improv]`, `[kit]`, `[env]` for "identical";
- `[improv]` cells can silently drop when a move's reach or a dash length changes (`buried_x_water` 1 -> 0 when the
  dash carried him past the buried; `face` brought it back): read `[improv]` after any reach or dash change.

## Strings that strand the bot
- **The frost spear stands 5 s** and a fresh press facing it vaults (`void_element.vaults()`): a lone `L L H` sent
  the next strings up the spear and two breakers never played while the autotest stayed green. Put spear strings last
  (or inside a string that blows it apart, `L L H L H`), and check `breakers=` / `moves=` against what the strings
  should reach, not only that the run finished.
- **The Awakening meter runs out mid-string** when an earlier ending hits harder, and `set_awakened` resets
  `_anim_mult` mid-move: a crossover that needs its first hit before a state expires (Steam Burst on the cube) then
  misses "sometimes". A breaker that drops out in 1 of 3 runs is a meter or placement problem, not the string.
- Effects left standing carry into the next string (read neighbouring films); the bot presses Awaken the frame the
  meter fills, so the Awakening column lands in that string's film.

## Press timing
- The bot presses `BOT_LEAD` (0.15 s) before the cancel, inside `BUFFER_MS`, and waits for `_hits_done > 0` before a
  press that follows a hit: pressing at `combo_window().ready` lost presses when hitstop or Awakening shifted the
  cancel, and pressing before a whiff-timed cancel while the hit was still to come let the stop outlast the buffer.
- In ATTACK a dash lands before any leap (dash cancels after the first hit), so `out` matters only once LEAP began;
  `wait` keeps a light after a dash from being Dash Stab.
- Bot lines are buffered and printed at the end: a `print` mid-fight is a 2-10 ms frame spike (see `perf-probe`).

## The cap
`AUTOTEST_MAX` caps the run; every string must have played (`strings=N/N`) before it. A new string that pushes the
last one past the cap fails as `strings=N-1/N`: raise the cap by what the string takes (spar strings add
`AUTOTEST_SPAR`), and say why in one line, not a changelog. Check a changed bot compiles with a real check
(`guide_check`), not `--check-only` (see `godot-headless-test`): a parse error hangs `--autotest` until `timeout`.
