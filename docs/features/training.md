# Training

## What it does

**Training** on the title screen opens a single room with a training dummy, for practising combos, breakers and ultimates without a run. The dummy never fights back and can't die. It takes hits, staggers, launches and juggles like any skeleton, then walks back to its spot and refills its HP once left alone.

Under the room title, the HUD shows the current string's damage and hits, the last string's, and the best string so far. A string ends when the combo drops.

Esc opens a TRAINING pause menu:
- **Pick a power:** three cards, with free rerolls.
- **Fill Awakening:** fills the meter, for practising the finisher and ultimates.
- **Ascend:** pick an element, while not yet ascended.
- **Restart training:** reloads into training with no powers.

The usual Settings and quit options and the build and moves panels are also there.

## Files

- `scripts/training_dummy.gd`: extends `enemy.gd`.
  - `_state_chase` never winds up an attack; it faces the hero, or walks back to `home` when knocked away.
  - `take_hit` tops up HP before a hit that could kill it and emits `hit_taken(damage)`.
  - `_physics_process` refills HP after `REFILL_DELAY`.
- `scripts/main.gd`, "Training" section:
  - `training` and the static `_train_next`;
  - `_start_training()` spawns the dummy (as a Skeleton_Warrior);
  - `_train_hit` / `_train_combo` / `_train_text` drive the readout;
  - `train_power`, `train_awaken`, `train_ascend` and `restart_training` serve the pause menu;
  - `_reroll_cost()` returns 0 in training.
- `scripts/title_screen.gd`: the Training button (`training` flag, read by main after `started`).
- `scripts/pause_menu.gd`: `_open_training()` replaces the run's pause items when `main.training` is set.

## How it works

`main._ready` sets `training` from `_train_next`, `--training` or the title's pick. It then calls `_start_training()` and returns before the run map and `_next_room()`, so no map, rooms or summary exist in training.

The dummy is not counted in `_alive` and its `died` signal is never connected, so a room is never cleared. Hits on it still go through the normal combo, style, Awakening and cast code.

## Invariants

- The dummy never deals damage. `training_check` asserts the hero's HP stays full.
- A `static var` survives `reload_current_scene()`; that is how "Restart training" lands back in training instead of the title.

## Testing

- `godot --headless --path . -s tests/training_check.gd`: PASS/FAIL. It checks:
  - the dummy survives 2400 damage;
  - hits add to the string, and a dropped combo records it;
  - the dummy walks home after a launch, never attacks and refills;
  - the pause menu items, power pick, free reroll, Fill Awakening and Ascend.
  Windowed, it saves `user://training_room.png` and `training_pause.png`.
- `godot --headless --path . -- --autotest --training`: the bot plays on the dummy and prints `[training] strings= best= last=`.
