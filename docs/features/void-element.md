# H on the void arm: shots and E breakers

## What it does

For the comic hero (`player._void` isn't null), right click is the element button and it only ever shoots or sets an element up: it never spins. On its own it shoots his last weapon's element. Off a weapon it plays that weapon's element.

The strings have three beats: a weapon and its element as the set-up, H again to shoot, then E in the timing window as the breaker. The tentacles seize up to `SEIZE_MAX` foes, hold them up through the slow-motion window, and slam them into the breaker's element.

The KayKit hero's `route()`, `BREAKERS` and `H` move are untouched. Hold H (`CH`) stays as the slam, but for this hero its breaker is his own, not the sawblade.

## Moves

| Input | Id | Name | Effect |
|---|---|---|---|
| H | `EB` | Element Shot | A bolt of his last weapon's element. H H H keeps shooting |
| Dash H | `DS` | Scatter Shot | A fan of `DASH_SHOTS` bolts |
| L H | `EC` | Updraft | A gale ahead pulls foes together and throws them up |
| L H H | `EE` | Thunder Volley | `VOLLEY_ZAPS` lightning shots shared round the nearest foes |
| L L H | `EF` | Frostline | Line of spikes that freezes |
| L L H H | `EA` | Shard Storm | `SHARD_SHOTS` ice lances aimed at the foes in reach |
| L L L H | `EM` | Magma Heart | Crater and lava wells |
| L L L H H | `EV` | Magma Barrage | Molten bolts, and it sets off the wells near him |
| Dash L H | `EG` | Glacier Run | Second lunge with a shorter ice line |
| E H | `EX` | Conduit | Bursts the held foe with his last weapon's element |
| L H L H L H | `EM` as `CONVERGENCE` | Convergence | Magma Heart at `CONVERGE_MULT`, with lightning and ice |

## Breakers (`VOID_ELEMENT.BREAKERS`)

| Input | Off | Name | Under each foe |
|---|---|---|---|
| L H H E | `EE` | Worldbreaker | Magma geyser and rock spikes |
| L L H H E | `EA` | Shatterstorm | Lightning |
| L L L H H E | `EV` | Absolute Zero | Ice crystals, freezes |
| Dash L H E | `EG` | Thunderclap | Lightning |
| hold H, E | `CH` | Landslide | Magma geyser and rock spikes |
| L H L H L H E | converged `EM` | Convergence Breaker | All three |

E earlier in a string, with no window, is the plain slam with that element's finish: `STORMSNARE`, `COLD_SNAP` or `MOLTEN_SLAM`.

## Files

| File | Role |
|---|---|
| `scripts/void_element.gd` | Routing tables (`AFTER`, `CHAIN`, `FINISHERS`), `BREAKERS`, `fire()`, `finish()`, `breaker_impact()`, all tuning |
| `scripts/player.gd` | `MOVES` and `COMBOS` rows, `void_route()`, `_breaker_for()`, the `tentacle` branches of `State.LEAP`, `_el_seen` |
| `scripts/void_grab.gd` | `seize()`, `seized_tick()`, `slam_seized()`, `release_seized()`, `finisher`, `weapon_element`, `let_go()` |
| `scripts/breaker_prompt.gd` | Shows E when `breaker_window().button` is `special` |
| `scripts/comic_look.gd` | `HERO_MOVE_FORMS`: which weapon each move forms |
| `scripts/move_list.gd` | `VOID_SECTIONS`, `VOID_ONLY` |

## Invariants

- Void breakers stay out of `player.BREAKERS`: `move_list_check` and `comic_check` walk that table for the KayKit hero. `_breaker_for()` picks the table.
- A breaker entry is `_WINDOW` merged with its row (`entry()`). `press: "special"` is what makes E the button.
- `leap` must be at or before the move's `cancel`. `EM` only leaps when converged.
- Every exit from the hang lets go: no press, dash out and `_end_leap` all call `release_seized()`. The tendrils stay in `_spare` for the next one.
- `_end_leap` clears `_buffered` for this hero, or the press that dove him would also grab.
- Damage comes from `fire()`. The move's own blow in `MOVES` is small, and `fire()` returning above 0 counts as connecting, so a shot at range still opens the breaker. Shots count who they're aimed at, since they land later.
- `fire()` runs once per move, on its first hit.
- `_el_seen` clears when an attack starts from outside `State.ATTACK`, so a dash or a pause ends the run at Convergence.
- These moves skip `_swoosh` and the weapon trail. Both are in his axe's teal and hid the element.
- New moves go in `VOID_ONLY`, or `move_list_check` expects `route()` to reach them.
- Clips come straight from `MOVES.anim`, as with `GR` and `VS`, so hit fractions are frame / frames of that clip.

## Tuning

Damage: `SHOT_DAMAGE`, `VOLLEY_DAMAGE`, `SHARD_DAMAGE`, `BARRAGE_DAMAGE`, each breaker's `damage` (times `perfect_mult` 1.5 and the chain's `_cast_power()`). Timing: `_WINDOW` (`open`, `sweet`, `close`, `perfect`). The hold: `SEIZE_RANGE`, `SEIZE_MAX`, `SEIZE_LIFT`.

## Not done

- Tentacle combos with a held foe: E L (flail), E L L (skewer), E L L L (anvil). Pillar swing into L or H.
- Clips are borrowed from other moves and retargeted, so the poses are approximate.
- Heavy foes aren't lifted or tentacled: they take the area damage only.
- Pillars, geysers, lightning and combo rings are the older soft or bright effects. Only the star and chips (`heretic_form_fx.gd`) are in the flat comic style.
- Spell sounds reuse `cast_*`.
- Magma Barrage's big geysers (`RITE.set_off`) still blow out white and hide foes. Hold H still shows the old spectral shaman from `CH`.

## Checks

`godot --headless --path . -s tests/void_arm_check.gd` covers routing, each move hurting a foe, finisher names, each breaker holding and hurting a foe and letting go, a missed window and Convergence (PASS/FAIL, stand-in foes, in `agent.sh check`).

`godot --path . -s tests/element_shots.gd` is windowed. It films each string against real foes at the game camera, through the hang and the slam, to `user://element_shots/`.
