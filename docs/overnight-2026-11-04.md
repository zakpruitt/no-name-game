# Overnight, 2026-11-04: what landed and what needs you

The game is now only the heretic's combat in a training room (round 28), with the chibi heretic as the
default hero. Everything below landed on `dev` between 06:50 and 11:00; nothing was pushed. All of it was
judged from headless checks and windowed stills or film; none of it has been played by hand.

## What landed (one line per lane, `git log dev`)

- **Strip to the heretic** (round 28): 4929c88 run cut to training, 3ec03e0 powers out, 3959d4b Ascendancy out, 30d07af heretic the only hero, 10f8705, d16f8ae.
- **Feel** (round 27): ef07545 shaped hitstop, 8c9d062 camera push-in / roll, fe6643b comic impact frame, 9a0a338 trail swell, 3c533ab docs; refactors 4f3cdca, 671ce55, ed6cc6c; 9983173 cleanup audit.
- **Enemy feel** (round 27): 8b8f166 hit reactions, e8a929b juggles, 4294ec2 hit direction, 795a6cc punching-bag dummy, 02a04d7 element slams crater, 36e0c1d Warden, 3c0656f bag knobs and LAST tag, ee928d3 `--spar`, 7d65917 docs.
- **Heretic model** (round 29 assets): 5d589ee refined heretic, f23dbdc chibi model, 2d224fc chibi rebake, 7337cec chibi default, cb7569b and e57b706 hand-keyed chibi clips, e31f9a7 GLB 4.07 to 3.09 MB, 06b5e92 eyes behind the claw, f1c5209 docs.
- **Heretic effects** (round 29 fx): e8a5739..4751a11 flat inked storm / ice / magma / dark, d7c24b7 comic hits, 3bdcd40 comic numbers, 672af5d inked tentacle, 1c02027 freed-mid-flash fix, 2d05171 impact frame leans, 16d8ac8 effect perf, 1249619.
- **Combo rhythm** (round 30): 16b7e51 hits on the contact frames, 5f3b6ff 300 ms buffer / hit-confirm / aim lock, 104a3a2 string pacing, 8433229 breaker windows, f9f6a6e all 13 bot strings with `[rhythm]`, 439a63c docs.
- **Perf and cleanup** (round 31): f404668 cpu/gpu `[perf]`, 55327f1 GPU afterimages, dc2088e shader warmup, 9d817d8 bot to training_bot.gd, 6a58675 and d6b9a14 dead code and assets, 08a9885 final numbers.
- **Split player** (round 31): 6d829ff hero_moves.gd, f8d6c89 hero_input.gd, d684a36 hero_leap.gd, fb9d4a4 hero_awaken.gd, 097ea9f, 738a619 docs.
- **Feel audit** (this lane): `tests/string_film.gd` and `docs/feel-audit-2026-11-04.md`, the top-10 list for the next rounds.
- **Foes chibi** (foe GLBs and tones) was still running when this was written; check `git log dev` for its commits.

Windowed autotest now: all 13 strings, 7/7 breakers perfect, `cpu avg=1.3ms worst=8.0-8.6ms`, 0-1 cpu spikes, `gpu avg=0.6ms`.

## How to play it

- `godot --path .` boots straight into training (four dummies that never die). Esc opens the pause menu:
  MOVES lists every string, plus Fill Awakening, Settings and Restart training.
- `godot --path . -- --hero=heretic` plays round 28's full-size heretic instead of the chibi.
- `godot --path . -- --spar=rogue` (or minion / shield / warrior) adds one live foe at 1/3 damage.
- `godot --path . -- --bag-damping=7` (also `--bag-stiffness=`, `--bag-lean=`, `--bag-squash=`) tunes the
  dummies' wobble live; the default damping is 5.

## Decisions made for you (veto any)

- **The chibi is the default hero.** Flip `Game.HERO_DEFAULT` in `scripts/game.gd` back to `"heretic"`.
- **Awakening stays** (meter, buff, burst); ultimates, Cataclysm, Trinity and the whole Ascendancy (levels,
  XP, bones, rites) are gone.
- **The comic style is always on**; the toggle and `--comic` flags are gone.
- Foes stay as code and data but nothing spawns them outside tests; the room keeps the four swing pillars.

## Meshy credits

75 credits in round 29: 60 on two whole-model candidates (a realistic A-pose and a chibi, neither used, both
in `vendor_src/meshy/source/`), then 10 for the chibi retexture and 5 for its auto-rig (balance 1067 -> 1052).

## Needs your hands

- Play the chibi and keep it or flip `HERO_DEFAULT`; judge the refined heretic's 2.2 m and bigger head in motion.
- Judge the chibi's on-twos stepping in motion; Death_A, the fidgets and 2H_Melee_Idle are still the shaman's.
- String speed: L3 at 1.3x (`L3_SPEED`) and Molten Palm at 2.1x (`EM_SPEED`); the film says the palm is now too quick to read.
- Input feel: the 300 ms buffer (`BUFFER_MS`), hit-confirm cancels (`CANCEL_ON_HIT` 0.5) and the 40 degree mouse aim lock (`AIM_LOCK_BREAK`).
- Breakers: Meteor Fall's window now opens 0.1 s after the rise; breaker count still varies 5-7 between runs.
- Feel numbers from round 27: the hitstop ease, camera roll, impact frame strength (the audit thinks it fires far too often) and trail swell.
- Dummy wobble: damping 5 (113 frames to settle) or 7 (86).
- Still open in the effects: the spear change's star touches the chibi's hood; Live Wire's coil and the
  breaker cue read loud; Dash Stab's spirit tomahawk is a shaman leftover; damage numbers don't dodge each other.

The feel audit (`docs/feel-audit-2026-11-04.md`) has the full per-string notes. Its short version: contact
holds and string rhythm read well; the impact frame, stacked words, lingering callouts and Awakened gold
crescents bury a hero who is already small at this camera.
