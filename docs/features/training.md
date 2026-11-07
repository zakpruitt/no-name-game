# Training

## What it does

The game boots straight into the training room: one room with four training dummies (`main.DUMMY_SPOTS`) and the first layout's pillars (R swings on them), for practising the heretic's strings and breakers. There is no title screen, run, map or reward. Dummies never fight back and can't die. Hits on any of them add to the same string. Each takes hits, staggers, launches and juggles like any skeleton, then walks back to its spot and refills its HP once left alone.

Under the room title, the HUD shows the current string's damage and hits, the last string's, and the best string so far. A string ends when the combo drops. Each dummy also carries a comic `LAST n` tag over its head: the damage that dummy took in the last string (feel audit 2, item 2: it pops when that dummy's string ends, small, `TAG_SIZE` 40 in a `TAG_INK_PX` 1.5 px ink line, and fades out `TAG_SHOW_S` 1.5 real s later; the next hit on it takes it down).

`--spar=minion|rogue|shield|warrior` adds one live foe of that type beyond the dummies, for trying strings on something that moves, dodges or blocks. It hits at 1/3 damage and comes back 1.5 s after it dies. Off by default. Its strikes can be dash-countered ([counter.md](counter.md)).

**Swinging dummies** (round 49, for the dash counter, [counter.md](counter.md)): Settings "Dummies swing" (saved), `--swing` for one run, or the bot's `counter` string. A dummy he stands in front of (2.8 m, 60 deg) for 0.5 s winds up with the spar foes' telegraph ring (0.7 s), its bag rocking back, and swings at him for 4 (a spar foe's third), every 1.4 s while he stays. Off by default: the dummy otherwise never attacks.

Esc opens the pause menu:
- **Fill Awakening:** fills the meter, for practising the Awakened strings and the burst.
- **Settings**, **Restart training** (reloads the scene) and **Quit game**.

The MOVES panel beside it lists every input (`scripts/move_list.gd`), by kit slot group (round 49, `docs/features/kit-slots.md`).

## Files

- `scripts/training_dummy.gd`: extends `enemy.gd`.
  - `_state_chase` never winds up an attack; it faces the hero, or walks back to `home` when knocked away.
  - `take_hit` tops up HP before a hit that could kill it and emits `hit_taken(damage)`. It is also heavier in the air than a skeleton: launches lift it `LAUNCH_SCALE` (0.55) as high, and its upward speed is capped (`enemy.launch_speed_for`, the inverse of the airborne gravity profile with its apex hang) so it never rises past `MAX_HEIGHT` (3 m). Otherwise every hit of a long string (casts, tentacle ticks, breaker slams) resets its rise and juggles it out of reach.
  - `_physics_process` refills HP after `REFILL_DELAY`, and the dummy shakes off a daze (`_shake_off`: three side kicks of the spring, a stretch, `Fx.daze` inked stars, counted in `shakeoffs`).
  - Hand-tune knobs: `bag_damping`, `bag_stiffness`, `bag_lean_mult`, `bag_squash_mult` start at the `BAG_*` consts and take `--bag-damping=N`, `--bag-stiffness=N`, `--bag-lean=N`, `--bag-squash=N` (`bag_overrides()`, read in `_ready`; prints `[training] bag knobs ...` once). A tap is still after about 9 / damping s: 5 → 113 frames (1.9 s), 7 → 86. The header comment in the script has the formulas.
  - A hit during the shake-off cuts it (`_cut_shake_off`: the tween stops, the stars go, the `Dazed` clip lets go; `shakeoffs_cut`). The comic bag holds `DAZE_CLIP` ("Dazed": spinning pupils, lolling head) over `DAZE_TIME` while it shakes off.
  - The tag: `StringTag` Label3D (Bangers, `TAG_*`), fed by `string_damage` in `take_hit` and closed by `Game.combo_changed(0)` (`_on_combo`, `last_string_damage`).
  - Punching bag: `_lean` snaps a tilt `BAG_LEAN_MULT` (1.8) times a skeleton's lean (capped `BAG_MAX_TILT`) and `_bag_step` springs it back past upright (`BAG_STIFFNESS` 190, `BAG_DAMPING` 5: each swing back ~55% of the last; held through the hit freeze, idle while airborne or settling a landing). `_squash` goes `BAG_SQUASH_MULT` (1.6) as far. Getting up from a knockdown kicks the spring `BAG_GETUP_KICK` back against the blow. Look: `godot --path . -s tests/enemy_feel_preview.gd -- --bag`.
- `scripts/main.gd`, "Training" section:
  - `training` (always true; tests read it);
  - `_start_training()` spawns the dummies: the comic punching bag `assets/comic/dummy.glb` (`tools/comic_art/enemy_dummy.py`), KayKit's Skeleton_Warrior if it is missing;
  - `_train_hit` / `_train_combo` / `_train_text` drive the readout;
  - `train_awaken` and `restart_training` serve the pause menu;
  - `clear_room()` removes the dummies and every foe, for tests that set up their own room.
  - the room has no centre banner: the HUD's top line says TRAINING and the empty readout says "Esc: moves, Fill Awakening".
- `scripts/training_bot.gd`: the autotest bot, added by `main._ready` with `--autotest` (`BOT_STRINGS`, screenshots, the `[autotest]`, `[perf]` and `[training]` lines). `scripts/perf_probe.gd` times each frame's node work for `[perf]`.
- `scripts/pause_menu.gd`: `_open()` builds the items above.
- `scripts/spar.gd`: `--spar=<kind>`. `main._start_training` calls `SPAR.start(self)` (null without the flag) and `_autotest_finish` calls `report()`: `[spar] type= hits_taken= kills=`. It spawns through `main._spawn` at `SPOT` from the hero, scales `attack_damage` by `DAMAGE_SCALE`, respawns after `RESPAWN`. `enemy.hits_taken` counts landed hits (blocks not).

## How it works

`main._ready` builds the room, then calls `_start_training()`. Nothing else spawns foes (`enemy.gd`, `boss.gd` and `enemy_types.gd` stay as code and data for tests and later rounds).

The dummies are not counted as a fight and their `died` signal is never connected, so the room is never cleared. Hits on them still go through the normal combo, style, Awakening and cast code.

## Invariants

- The dummy never deals damage unless it swings (off by default). `training_check` asserts the hero's HP stays full; `counter_check` covers the swing.

## Testing

- `godot --headless --path . -s tests/training_check.gd`: PASS/FAIL. It checks:
  - the game boots into training;
  - the dummy survives 2400 damage;
  - hits add to the string, and a dropped combo records it;
  - a launcher every frame for a second never lifts it past `MAX_HEIGHT`;
  - the dummy walks home after a launch, never attacks and refills;
  - the pause menu items and Fill Awakening.
  Windowed, it saves `user://training_room.png` and `training_pause.png`.
- `godot --headless --path . -- --autotest`: the bot plays its strings on the dummies and prints `[training] strings= best= last=`, `[autotest] done ...` and `[kit] slots=N/N windows=N/N upgrades=N/N missing=`. Each `BOT_STRINGS` entry is `{"slot": <KitSlots id, or a list>, "tokens": [...]}`, or `{"upgrade": <Kit id>, ...}` for a demoted move's string, which plays only with that upgrade on (`training_bot.active()`, `strings`). `agent.sh check` runs it twice, plain and with `--kit=full` (37 strings, `upgrades=1/1`), and fails unless `[kit]` is full both times (`docs/features/kit-slots.md`). With `--spar=shield` (say) it also prints `[spar] type=shield hits_taken=7 kills=2`.
- `tests/enemy_feel_check.gd` covers the bag knobs, the cut shake-off, the tag and `--spar`; look: `tests/enemy_feel_preview.gd -- --bag`.
