# Awaken

Fast-paced 3D combo roguelike hack and slash. Godot 4.7, GDScript. Original
characters only (no licensed IP in the repo).

## Design pillars
1. **Combat feel first.** Light/heavy strings, dash cancels out of anything,
   hitstop + shake + knockback + flash on every hit. Tune before adding content.
2. **Awakening.** Style rank (variety > mashing) fills the meter; activating
   transforms the hero (moveset/speed/damage, super armor, cinematic burst).
3. **Combo-slot upgrades (roguelike hook, not built yet).** Run rewards attach
   to specific moves ("3rd light hit releases a fire wave"), so each run builds
   a different combo string.
4. Tower defense is parked. If it returns, it's a room type, not a mode.

## Layout
- `scripts/game.gd` — autoload `Game`: hitstop, shake, combo/style rank, Awakening meter, input map (bound in code)
- `scripts/player.gd` — hero state machine; moves live in the `MOVES` table (timings are fractions of anim length)
- `scripts/enemy.gd` — skeleton AI: spawn → chase → telegraphed windup → strike; poise, launch/juggle
- `scripts/main.gd` — builds arena from KayKit pieces, wave spawner, autotest bot
- `scripts/hud.gd`, `scripts/camera_rig.gd`, `scripts/fx.gd` (damage numbers, sparks, rings, flash)
- `assets/kaykit/` — CC0 models (see CREDITS.md). `vendor_src/` holds the full packs; it's gitignored and `.gdignore`d — copy pieces into `assets/` to use them.

## Workflow
- Headless check (compile + 12s bot playthrough): `godot --headless --path . -- --autotest`
- Visual check (screenshots to `%APPDATA%/Godot/app_userdata/Awaken/autotest_*.png`): `godot --path . -- --autotest`
- Effect preview (isolated, screenshot to `user://fx_preview.png`): `godot --path . -s tests/fx_preview.gd`
- Autotest also saves `autotest_hit.png` ~0.2s after the first big hit, for checking impact VFX
- Occlusion check (hero parked behind a pillar, `user://occlusion_check.png`): `godot --path . -s tests/occlusion_check.gd`
- After adding assets: `godot --headless --import --path .`
- Scenes are mostly built in code; keep `.tscn` files minimal unless the user wants editor-authored scenes.
- KayKit models face +Z; facing yaw = `atan2(dir.x, dir.z)`. Characters share one rig, so any KayKit animation works on any character.
