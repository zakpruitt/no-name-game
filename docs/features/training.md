# Training

## What it does

The game boots straight into the training room: one room with four training dummies (`main.DUMMY_SPOTS`) and the first layout's pillars (R swings on them), for practising the heretic's strings and breakers. There is no title screen, run, map or reward. Dummies never fight back and can't die. Hits on any of them add to the same string. Each takes hits, staggers, launches and juggles like any skeleton, then walks back to its spot and refills its HP once left alone.

Under the room title, the HUD shows the current string's damage and hits, the last string's, and the best string so far. A string ends when the combo drops.

Esc opens the pause menu:
- **Fill Awakening:** fills the meter, for practising the Awakened strings and the burst.
- **Settings**, **Restart training** (reloads the scene) and **Quit game**.

The MOVES panel beside it lists every input (`scripts/move_list.gd`).

## Files

- `scripts/training_dummy.gd`: extends `enemy.gd`.
  - `_state_chase` never winds up an attack; it faces the hero, or walks back to `home` when knocked away.
  - `take_hit` tops up HP before a hit that could kill it and emits `hit_taken(damage)`. It is also heavier in the air than a skeleton: launches lift it `LAUNCH_SCALE` (0.55) as high, and its upward speed is capped (`enemy.launch_speed_for`, the inverse of the airborne gravity profile with its apex hang) so it never rises past `MAX_HEIGHT` (3 m). Otherwise every hit of a long string (casts, tentacle ticks, breaker slams) resets its rise and juggles it out of reach.
  - `_physics_process` refills HP after `REFILL_DELAY`, and the dummy shakes off a daze (`_shake_off`: three side kicks of the spring, a stretch, `Fx.daze` inked stars, counted in `shakeoffs`).
  - Punching bag: `_lean` snaps a tilt `BAG_LEAN_MULT` (1.8) times a skeleton's lean (capped `BAG_MAX_TILT`) and `_bag_step` springs it back past upright (`BAG_STIFFNESS` 190, `BAG_DAMPING` 5: each swing back ~55% of the last; held through the hit freeze, idle while airborne or settling a landing). `_squash` goes `BAG_SQUASH_MULT` (1.6) as far. Getting up from a knockdown kicks the spring `BAG_GETUP_KICK` back against the blow. Look: `godot --path . -s tests/enemy_feel_preview.gd -- --bag`.
- `scripts/main.gd`, "Training" section:
  - `training` (always true; tests read it);
  - `_start_training()` spawns the dummies (as Skeleton_Warriors);
  - `_train_hit` / `_train_combo` / `_train_text` drive the readout;
  - `train_awaken` and `restart_training` serve the pause menu;
  - `clear_room()` removes the dummies and every foe, for tests that set up their own room.
- `scripts/pause_menu.gd`: `_open()` builds the items above.

## How it works

`main._ready` builds the room, then calls `_start_training()`. Nothing else spawns foes (`enemy.gd`, `boss.gd` and `enemy_types.gd` stay as code and data for tests and later rounds).

The dummies are not counted as a fight and their `died` signal is never connected, so the room is never cleared. Hits on them still go through the normal combo, style, Awakening and cast code.

## Invariants

- The dummy never deals damage. `training_check` asserts the hero's HP stays full.

## Testing

- `godot --headless --path . -s tests/training_check.gd`: PASS/FAIL. It checks:
  - the game boots into training;
  - the dummy survives 2400 damage;
  - hits add to the string, and a dropped combo records it;
  - a launcher every frame for a second never lifts it past `MAX_HEIGHT`;
  - the dummy walks home after a launch, never attacks and refills;
  - the pause menu items and Fill Awakening.
  Windowed, it saves `user://training_room.png` and `training_pause.png`.
- `godot --headless --path . -- --autotest`: the bot plays its strings on the dummies and prints `[training] strings= best= last=` and `[autotest] done ...`.
