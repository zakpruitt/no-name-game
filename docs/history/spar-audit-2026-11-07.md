# Spar audit, 2026-11-07 (spar-feel lane: combat against live foes)

Zak's loop: "increasing combat fluidity, ensure everything is snappy and very fun". Every round since the kit grammar
was built and filmed on dummies that never fight back. This audit plays every string against each spar foe.

## Method

- **Films.** Windowed `tests/string_film.gd -- --spar=<kind> --dir=spar_<k>`, every bot string (43 plus free play) in
  the plain room, once per foe: warrior, rogue, shield, minion.
  - The INDEX lines now carry the live foe: ` | spar <STATE> hp y si(strike_in) <flags> d | hero hp INV`.
  - Flags: F flying, B bound, Z frozen, A airborne, W telegraph up; b / m / s / c for buried, molten, skewered and
    charged.
  - warrior, rogue and shield were filmed on dev fe38240 (before). The minion film ran with the held fix
    and the old respawn.
  - The warrior was filmed again after every fix (`spar_w_after`).
  - The pieces room, after the fixes: `--spar=warrior --room=pieces --kit=full --from=42 --dir=spar_wp`. It has the 9
    piece strings and free play. It showed 1 hurt (pool_alt_D_L_H 035, as the string starts) and no strike through a
    hold. A strike in his dash did nothing (grate_alt_L_L_H_wait_D_L_H 026). The foe was away for 27% of it. The hook
    string counters the dummy, so the warrior was never hung.
- **Reading.** A PIL contact sheet per string (24 frames a page, labelled with real ms, move, state and scale, and the
  spar columns). An event pass over every INDEX lists each hurt (and his state), each strike, each windup cut and
  each kill. Frame references below are `string frame` in those films.
- **Mechanisms.** The bot plays every string on the dummies, so the live foe is often a bystander. Each claim the films
  only hint at was checked headless in `tests/spar_check.gd`, which puts one foe of each kind in front of him. Its
  baseline run on dev (before any fix) is the "before" column.
- **Clips.** `tests/spar_film.gd` films one foe and one scripted case (counter, hurt, collapse, poise, respawn). The
  before clips were filmed with the dev scripts swapped back in.
- Films, sheets and logs are in the session scratchpad, not committed. Clips: `Desktop\awaken-combo-clips\47 Spar *`.

## Ranked list

| # | What | Frames / numbers | Status |
|---|---|---|---|
| 1 | A foe held by a control move kept its windup and struck from mid-air or from under the floor. Collapse, Abyss and Avalanche set `thrown_foe.FLYING` with no stagger of their own; a bound or hooked foe whose stagger ran out could start one. `_strike` never checked height. | spar_check before: `carry=HIT hook=HIT held_winds_up=true` on all four kinds. Clip before: Collapse swallows a warrior at 010-014 and it is still in WINDUP at y -0.6 to -1.3 m. spar_w wall_alt_D_H_H 029-040: a respawned warrior winds up under the whole D H H hang (he is i-framed in LEAP, so no damage) | fixed |
| 2 | The spar foe respawned outside the room and fell for the rest of the run. SPOT is 8 m up the room from him, so near the back wall it spawned past it. | spar_w alt_L_H_L_L_H 021-068 (y -0.4 to -128). spar_s alt_L_H_L_L_H 024 on, and wall_D_L_H_H_H_L 019-028 (SPAWN at y 0 to -3.4, later -29.8). spar_check before: respawn at z -22.5, y -15 | fixed |
| 3 | The live foe was missing for 40-56% of every film. It died in most strings, then took 1.5 s to respawn, 1 s to rise and about 2 s to walk the 8 m back. | Frames gone or SPAWN: warrior 40%, rogue 56%, shield 46%, minion 49% | fixed (respawn 0.8 s, 6 m) |
| 4 | Warrior poise (8) held through every hit with knockback under 8, and the check ignored `big`. Most element moves pass zero knockback, so a whole string of big heavies landed on a winding-up warrior and its strike still came. | Clip before: L1, L2, then Molten Palm's first hits at 006-022 are all held. Only the launch at 026 (936 ms) stops it. After: it staggers at 018 (645 ms) | fixed |
| 5 | The rogue's windup (0.45 s) showed only 0.20 s of telegraph before the counter window opened, the shortest by far. | spar_check lead: minion 0.35, rogue 0.20, shield 0.45, warrior 0.55 s | fixed (0.5 s windup, lead 0.25 s) |
| 6 | His hurts almost all land as a string starts, not mid-string. The film's gather puts the live foe 1.6-1.8 m in front of him and it winds up while the bot walks up. Only two strikes hit him mid-string in four films: spar_w spread_H_L_L_wait_H_L 048 (in GR, telegraphed 1.1 s of real time, so fair) and spar_m face_L_H_D_L_H 024 (L1). Hurt lasts 0.35 s, with a dash out from 0.12 s (166 ms measured). | events per film: 5-9 hurts, 1-4 hp each at 1/3 damage | kept; see Decisions |
| 7 | The bot never counters a live foe. Every bot string is aimed at the dummies, so the live foe is a bystander in about a quarter of the strings (spar_w: hp unchanged in 12 of 44). The counter on live foes could not be judged from the string film. | spar_w counter_D: the warrior never winds up at him in reach | counter filmed per foe in spar_film; bot token is a decision |
| 8 | The shield only blocks frontal hits that have knockback, in CHASE or RECOVER. Zero-knockback hits (burn ticks, binds, casts) and every control move (stagger first) go round it. Big hits and launches guard-break it. | blocks= in `[spar]` below | kept (the tentacle reaches past a shield); see Decisions |
| 9 | Bolts vs the counter: archer and mage were not spar foes, so nothing tested a parry on a live shooter. | spar_check: both parried inside the window, and the parried bolt hits the shooter | added `--spar=archer|mage` |
| 10 | Death under the new effects. The warrior's kill at spar_w L_L_L_H_H 042 lands on the breaker's impact frame (the grey wash), so its kill pop is hidden. The bar reads 0 while it lives on under 1 hp (028-041). | spar_w L_L_L_H_H 028-042 | open (impact frame lane) |

Not problems (checked):

- Breaker hang: he is untouchable in LEAP (`hero_leap` sets i-frames every tick). No strike hurt him in a hang in any
  film.
- Gathers that seize (`void_grab.seize`), binds (floor_bind), thrown flights (thrown_foe), the gallows hook, ice
  cubes and the counter's lift all stagger the foe and keep it staggered (`RESTAGGER` 0.25 s), on a live foe as on a
  dummy. The one hole was the FLYING-only holds (item 1).
- Counter windows (`counter.WINDOW` 0.25 s) read on every melee foe once the rogue had its 0.5 s. No per-foe window
  scaling was needed.
- Hit stops with a live foe: its windup runs in game time, so a string's hitstops stretch the telegraph by the same
  factor as everything else (spread_H_L_L_wait_H_L 034-048: a 0.8 s windup over 1.1 s of real time).

## Fixes

- **Held foes never strike** (`enemy.held()`, `HELD_CUT`, `STRIKE_MAX_Y`).
  - A foe is held when it is carried or thrown (`thrown_foe.FLYING`), bound (`floor_bind.BOUND`, small foes only,
    since big ones are only slowed) or frozen.
  - A windup under way when the hold takes it becomes a 0.4 s stagger (`held_cuts`). No windup starts while it is held,
    the swinging dummy's swing included.
  - `_strike` refuses a held foe, or one more than 0.8 m off the floor.
  - After: spar_check shows `carry`, `throw`, `bind`, `freeze`, `hook`, `launch` and `seize` all ok on every kind.
  - Clip: the Collapse windup is cut at 010 (HURT, held).
- **Poise breaks on a big hit or the third** (`_poise_holds`, `POISE_HITS` 3).
  - Poise holds a windup only through light hits under its knockback.
  - Before / after: in the poise clip the warrior staggers at 645 ms instead of 936 ms.
  - spar_check: two light hits hold, the third breaks it, and a big zero-knockback hit breaks it.
- **The rogue's windup is 0.5 s** (enemy_types). It has 0.25 s of telegraph before the window. `chop_speed()` retimes
  the clip to meet it.
- **Spar respawn** (`spar.spot()`, `WALL_GAP` 2.5, `MIN_GAP` 4, `FALL_Y` -6, `RESPAWN` 0.8, `SPOT` 6 m).
  - It comes back inside the room, at least 4 m from him (on his other side near a wall), and sooner.
  - A foe that leaves the room anyway, and is not in a move's hands, is put back (`strays`).
  - After (spar_w_after): away for 31% of the film (was 40%). Mid-string hurts: 1 (line_out_face_D_L_H_H_H_L_D_wait_L_H 030, in EF at 0.9 m); a hold cut a real windup at wall_alt_L_L_H_D_H_H_L 022 (HURT, F).
- **More to read.** `[spar]` adds `hurts=` (times he lost hp), `blocks=`, `cuts=` and `strays=`. `--spar=archer|mage`
  are added for the bolts.

## Numbers

Autotest `--spar=<kind>`, after the fixes (plain autotest without `--spar` alongside, same build):

| `--spar=` | hits_taken | kills | hurts | blocks | strays | breakers | strings | time |
|---|---|---|---|---|---|---|---|---|
| (none) | - | - | - | - | - | 15/15 | 43/43 | 178 s |
| warrior | 166 | 31 | 5 | 0 | 0 | 15/15 | 43/43 | 180 s |
| rogue | 94 | 37 | 9 | 0 | 0 | 15/15 | 43/43 | 177 s |
| shield | 109 | 34 | 4 | 21 | 0 | 15/15 | 43/43 | 175 s |
| minion | 111 | 38 | 7 | 0 | 0 | 15/15 | 43/43 | 180 s |
| archer | 55 | 25 | 15 | 0 | 0 | 15/15 | 43/43 | 179 s |
| mage | 64 | 27 | 18 | 0 | 0 | 14/15 | 43/43 | 174 s |

- Before the fixes, the warrior run read `hits_taken=124 kills=24 strays=1`: the foe was out of the room for part of
  it.
- `cuts=0` in every run: the bot's strings never caught a live foe mid-windup with a hold. The windowed film did once
  (spar_w_after wall_alt_L_L_H_D_H_H_L 022).
- The mage run misses Lava Leash (XL). An orb hit him between Molten Palm and the leash, and the hurt reset the string:
  the next press played L1 (`[rhythm] wall spread L L L H L: ... EM->L1`). That is a fair hit, since the orb can be
  parried. It is also the cleanest example of decision 1 below.
- Adding `--spar=warrior` as a third autotest run in `agent.sh check` would add about 3 min to a 17-20 min check, so it
  was left out. `spar_check` (about 50 s) covers the same ground headless.

## Decisions for Zak

- **His hurt resets the string** (the mage run's Lava Leash). Should a hurt mid-string keep the chain, so the next
  press resumes it, or end it as now? His hurt is 0.35 s, with a dash out from 0.12 s. That is snappy enough to escape, but a strike mid-string still
  costs the string. Should the dash-out come at 0.08 s, or should Awakened-style armour hold through chip hits?
  (`player.gd`, a hot file; not changed.)
- **The bot on a live foe.** The bot could counter a live foe in reach (a token in training_bot, the feel-audit lane's
  file). Then `--spar=warrior` in `agent.sh check` would test the counter in play, not only in spar_check.
- **The shield** lets control moves and zero-knockback ticks through its guard. That is the tentacle reaching past it.
  The other reading: binds and casts from the front bounce off until a guard break.
- **The live foe in the string films** is gathered into the dummies' fan and winds up as the bot walks in. Leave it
  out of the gather (`--spar-far`), so the films show strings first and the foe joining after?

## Tests

- `tests/spar_check.gd` (in `agent.sh check`, about 50 s headless): each melee foe's real windup gives at least 0.2 s
  of telegraph before the counter window, and a dash in the window is Backlash with no damage. An uncountered strike
  lands. Each hold mid-windup (carry, throw, bind, freeze, hook, launch, seize) reaches its state and the strike never
  lands. A held foe starts no windup. Archer and mage bolts parry back. Warrior poise: two lights hold, the third and a
  big hit break it. A dash leaves his hurt within 0.2 s. The spar foe spawns and respawns inside the room.
- `tests/spar_film.gd` (windowed): the clips' cases.
