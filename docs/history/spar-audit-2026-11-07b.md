# Spar audit 2, 2026-11-07 (spar2 lane: the counter and the holds in real play)

The first spar pass ([spar-audit-2026-11-07.md](spar-audit-2026-11-07.md)) left four things open. The bot never
countered a live foe. The film gathered the foe into the dummies' fan. No hold ever cut a windup in play (`cuts=0`).
Nobody had filmed the gallows or Galvanize on a live foe. This pass plays all four in real play and measures his hurt.

## Method

- **Bot strings on the live foe** (`training_bot.gd`, only with `--spar=`). Two new waits: `C` / `CP` hold the dash
  until the counter window, and `W` holds the next press until the foe is mid-windup.
- **Films** (windowed `string_film.gd`):
  - every string against a warrior, plain room (`spar2_w`, 49 strings);
  - the spar strings in the room with pieces, `--kit=full` (`spar2_wp`, `_wp2`, `_wp3`, then `spar2_clips` at 30 fps);
  - the gallows string again with `--spar-hp=5` (`spar2_hook5`);
  - the archer's `foe C C` (`spar2_clips_a`).
- **Reading.** PIL contact sheets with the INDEX columns, plus an event pass over every INDEX. For each hurt it logs the
  time into the string, and whether a move had started in that string. It also counts how often the foe is away (dead
  or still spawning).
  - It was run on the predecessor's films (`spar_w`, `spar_w_after`) and on the new one.
- **Numbers.** Headless autotests `--spar=` on each kind, plus plain and `--kit=full --room=pieces --spar=warrior`.
  - `[spar]` adds `mid=` and `hurt_ms=`; `[spar_bot]` counts the bot's foe tokens.
- **Clips:** `Desktop\awaken-combo-clips\50 Spar2 *` (half speed, 15 fps from 30 fps frames). Films, sheets and logs
  are in the session scratchpad.

## Findings and fixes

| # | What | Evidence | Status |
|---|---|---|---|
| 1 | The bot never countered a live foe. | dev `--spar=warrior`: `counters=1` (the swinging dummy's string) | **fixed**: `C` / `CP` tokens. After: `counters=3 perfect=2`, `[spar_bot] c=1 cp=1` |
| 2 | `cuts=0` in every autotest: a hold's own first hit (the grab's, Harpoon's lift) staggers the foe a frame before the hold takes it, so the windup was gone when `held()` came true. Nothing in play ever counted. | spar_check bot pass, debug print: every real hold arrived 0.017 s (one frame) after the windup broke | **fixed**: `enemy.HOLD_CUT_GRACE` 0.2 s. A windup broken and then held (or grabbed by the tentacle, `_grabbed()`) inside the grace counts. Backlash's lift is excluded (`_countered()`). |
| 3 | No bot string caught a windup with a hold. | `W` token | **added** `foe W H H` (the grab) and `foe W D L H` (Harpoon). Warrior `cuts=` 0 -> 3-6 per autotest |
| 4 | The film pulled the live foe 1.6-1.8 m in front of him as each string started, so it wound up while the bot walked in. Its hurts clustered there. | event pass `spar_w_after`: 7 hurts, 4 before the string's first move. `spar_w` (before): 5 hurts, 4 before | **fixed**: `string_film._gather` leaves it where it is. Only past `SPAR_NEAR` 7 m is it put back, on his flank. `spar2_w`: 2 hurts, both mid-string (`hold` OW, `tide` H L H); foe away 21% (31% before) |
| 5 | The other strings walked up to and aimed at the live foe when it was nearest, not at the dummies. | `training_bot._drive_bot` `nearest` | **fixed**: only `foe` strings aim at it; the rest ignore it (it joins in on its own) |
| 6 | Gallows on a live foe: Ricochet onto the hook splats it for 146-234. That is more than the warrior's 75 (and than its leftover hp from earlier strings: 6 and 11 in two takes), so the hang only ever held a corpse, and the Snap and Galvanize's latch had nothing to hold. | `spar2_wp` hook string 052-079 (152 kills it, it dangles dead); `spar2_wp3` 068-076 (234 on 196 hp); `spar2_wp2` (Backlash's 18 kills a leftover 11 hp before the perfect) | **fixed in the spar**: melee spar foes get 3x hp (`spar.HP_SCALE`, `--spar-hp=N`), refilled as a `foe` string starts. After (`spar2_clips` hook): 207 -> 60 on the splat. It hangs bound about 1.5 s, then Galvanize's tentacle runs up to it under the hook, charges it (c), and the hit Snaps it down. **The splat still kills any real 75-hp warrior**: see Decisions |
| 7 | The bot pressed on as soon as he landed from the window. The next press (the grab) then plucked the foe out of Ricochet's throw mid-air, and the banner counted the grab's 6 into Ricochet. | `spar2_wp` 053-058, "RICOCHET 6" then "152" | **fixed for the bot**: a `settle` token waits until it is down or hung for 0.5 s. A player can still grab it mid-throw: see Decisions |
| 8 | Harpoon's hold cut lands late on the warrior. Poise holds through Dash Stab and the first Harpoon tick, so the freeze arrives at `si 0.13-0.17`, 2-3 frames before the strike. Fair, and it reads as a last-instant save. | `spar2_wp` W D L H 032-042; `spar2_clips` 066-082 | kept |
| 9 | The `[spar]` autotest with pieces and a live warrior ran out of time (55/58 strings) once the spar strings were in. | `--kit=full --room=pieces --spar=warrior` | **fixed**: `AUTOTEST_SPAR` +60 s with `--spar=` only; 58/58 |
| 10 | A shooter at 3x hp shot him ~20-24 times a run, and the archer run lost the counter string's Ricochet once. | `--spar=archer` at 3x: hurts 20, `breakers=14/15` once | **fixed**: `HP_SCALE` applies to melee kinds only (ranged keep 1x unless `--spar-hp=`) |

Also seen, not this lane's files:

- The Ricochet banner (`designed_breaker`) keeps adding the next string's hits to its total for ~1.5 s: 146 -> 152 ->
  198 as the grab and Reap land on the dummies (`spar2_hook5` 094-110).
- Ricochet in the room with pieces always takes the gallows when the warrior attacks inside 10 m of the east hook. The
  bot's `foe CP` there hung it too, the same as the `hook` string.

## Numbers

`[spar]` autotests, same build, headless (`mid` = hurts within 0.6 s of a move, hold or breaker; `hurt_ms` = real ms
he spent in State.HURT, avg/max):

| `--spar=` | hits_taken | kills | hurts | mid | hurt_ms | cuts | counters (perfect) | spar_bot c/cp/bolt/w/missed | breakers | strings |
|---|---|---|---|---|---|---|---|---|---|---|
| (none) | - | - | - | - | - | - | 1 (1) | - | 15/15 | 45/45 |
| warrior | 231 | 22 | 4 | 2 | 379/386 | 3 | 3 (2) | 1/1/0/2/0 | 15/15 | 49/49 |
| rogue | 191 | 33 | 10 | 5 | 379/379 | 5 | 3 (2) | 1/1/0/2/0 | 15/15 | 49/49 |
| minion | 192 | 34 | 10 | 3 | 389/421 | 4 | 3 (2) | 1/1/0/2/0 | 15/15 | 49/49 |
| archer (1x hp) | 64 | 23 | 24 | 10 | 391/483 | 2 | 3 (1) | 0/0/2/0/0 | 15/15 | 46/46 |
| mage (1x hp) | 69 | 30 | 16 | 5 | 419/517 | 0 | 3 (1) | 0/0/2/0/0 | 15/15 | 46/46 |
| warrior, pieces, `--kit=full` | 253 | 23 | 8 | 1 | 459/531 | 5 | 6 (4), ricochet=hook | 1/2/0/2/0 | 15/15 | 58/58 |

An earlier warrior run of the same code read `hurts=2 cuts=6 hurt_ms=459/531` (the hurt's real length depends on
which hitstops overlap it). The mage run's 21/22 endings: an orb hurt him mid-string and reset it, as in audit 1.

Before (dev 9cc4cc7, `--spar=warrior`): `hits_taken=164 kills=31 hurts=5 cuts=0`, `[counter] counters=1 perfect=1`,
strings 45/45.

`spar_check` (in `agent.sh check`) now also plays the bot's spar strings, twice each, in a fresh room. Warrior
`c=2 cp=2 w=4 missed=0 counters=4 ricochet=true cuts=4`; archer `bolt=4`. It runs ~105 s, up from ~50.

## His hurt (task 5: measured, not changed; `player.gd` is another lane's)

- **Timing.** `_state_hurt`: 0.35 game s, a dash out from 0.12 s, 0.5 s of i-frames from the hit, and a 0.06 s
  hitstop.
  - Measured in play, the bot never dashes out, so this is the full stun: 379-421 ms against the rogue and minion,
    379-459 ms avg and up to 531 max against the warrior (hitstops overlapping it stretch it).
  - spar_check's dash-out leaves hurt at 165 ms real.
- **How often.** Hurts per autotest (mid-string of them): warrior 4 (2), rogue 10 (5), minion 10 (3), in 49 strings each.
  - The warrior's 0.8 s windup with 0.55 s of telegraph is almost never the one that lands.
  - The rogue (0.5 s windup, flanking) and the minion land them.
- **No hurt-lock.**
  - The next strike comes at least `attack_cd` 0.8 s + windup later (warrior >= 1.6 s, rogue >= 1.3 s, minion
    >= 1.4 s).
  - That is past both the 0.35 s hurt and the 0.5 s of i-frames, so two hurts never chain.
- **Recommendation: keep 0.35 s and 0.12 s.**
  - At 0.12 s the hit still reads (the flash, the Hit_A pose, the number) before the dash can cancel it. At the
    predecessor's 0.08 option the 0.06 s hitstop eats most of it.
  - The escape is already free: the dash's own i-frames overlap the hurt's 0.5 s.
  - What a mid-string hurt really costs is the string: it resets the chain (spar audit 1, decision 1), and the
    rogue's mid-string ones are lost strings.
  - If anything changes, make the chain survive a hurt the player dashes out of (resume the string on the next press
    within the buffer). Don't shorten the hurt.
  - Against the warrior nothing needs changing: it hit him 2-4 times in 49 strings.

## Should `--spar=warrior` be in `agent.sh check` (task 6)

**No; `spar_check` is the gate.**

- The full `--spar=warrior` autotest adds ~3.5 min to a ~20 min check.
- Its live parts (the counter in play, Ricochet, a hold cut) are the 4 spar strings, and `spar_check` now plays them on
  a live warrior and archer in ~55 s, failing if Backlash, the perfect, Ricochet, a cut or a bolt parry doesn't land.
- The other 45 strings of a spar autotest only add a bystander that can hurt him: nondeterministic noise, which the
  plain autotest's breaker / string asserts would turn into flaky FAILs. The archer cost a breaker once in four runs.

## Decisions for Zak

- **The gallows on a real foe is an execution.** Ricochet onto the hook (146-234) kills a 75-hp warrior on the
  splat, so in a real fight the hang, the Snap and the Galvanize latch only ever happen to something big. Options:
  - Leave it: the gallows is the kill.
  - Cap the splat at the foe's hp minus 1 when it hangs, so it always hangs alive for the follow-up (counter.gd /
    env_flourish.gd, not this lane).
  - Hang the corpse on purpose, longer, as a trophy beat.
- **Grabbing a foe out of Ricochet's throw** (the grab's 9 m reach catches it mid-flight) adds the grab's hit into the
  ending's total and drags it off its path. Should a thrown-by-Ricochet foe be untargetable until it lands?
- **The spar foe's 3x hp** (melee kinds; `HP_SCALE` 3, `--spar-hp=1` for the old 75). It lets a string meet a foe
  that survives its first breaker, so holds, hangs and counters happen on something alive. Revert if the sparring
  partner should die like a real foe.
- **The hurt**: keep 0.35 / 0.12 (above). The open question is still spar audit 1's: should a hurt mid-string reset
  the chain?

## Not verified

- A human's feel of the counter tokens' timing (`BOT_C_AT` 0.2 s, `BOT_W_AT` 0.6 s): the bot presses on the frame.
- The shield, rogue and minion on film this pass (headless numbers only). The archer is filmed only for its parry.
- The mage's `foe C C` string on film (headless: `bolt=2`).
