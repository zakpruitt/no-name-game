# Roadmap

Autonomous enhancement backlog. Work top-down; one item per commit. Check items
off and add notes/new ideas as you go. Never start tower defense or licensed IP.

## Combat feel
- [x] Weapon slash trails: `weapon_trail.gd` ribbon on both axes; turns orange while Awakened
- [x] Hit sparks → particle bursts; dust puff on dash and landing: `Fx.burst/impact/dust` (CPUParticles3D; GPU version misplaced first burst + compile hitch)
- [x] Brief enemy freeze (per-enemy hitstop) + squash/stretch on hit: `hit_freeze`/`hit_freeze_big` exports; enemies shudder in place, then knockback; launched enemies stretch up
- [x] Dash afterimages: `Fx.afterimage` bakes the current skinned pose into fading ghosts (blue, orange when Awakened); skipped headless
- [x] Perfect-dodge: dash ≤0.15s before a hit lands → slow-mo, +20 Awakening, +style, attacker stunned 1.2s, free re-dash (`perfect_dodge_*` exports)
- [x] Sound: synthesized placeholder SFX (`tools/gen_sfx.py` → `assets/sfx/`), played via `Game.sfx()`; kenney.nl blocks scripted downloads, swap in real CC0 sounds later by keeping file names

## Enemies
- [x] Skeleton mage: keeps ~7m away, purple-ring windup, slow bolts (`projectile.gd`) you can dash through/perfect-dodge; enemy types now data in `main.ENEMY_TYPES`
- [x] Skeleton rogue: fast, circles to the hero's back, 50% chance to hop away when you start an attack nearby (only from neutral); from wave 2
- [x] Enemy separation/steering: personal-space push, in-range enemies circle while waiting, max 2 melee windups at once (`separation_radius`, `max_melee_attackers`)
- [x] Elite modifier: ×2.5 HP, ×1.4 damage, ×1.3 size, +poise, gold aura, +15 Awakening on kill; `main.elite_count(n)` = n/2 per wave (never mages)
- [x] First boss: Bone Warden (`boss.gd`, every 5th wave) — cleave/leap slam/bolt nova (`ATTACKS` table), guard-break meter instead of flinching, enrages + summons at 50%, HUD boss bar

## Roguelike
- [x] Combo-slot upgrade system: data in `upgrades.gd`, effects in `player.gd` (`_effective_move`, `_do_hit` hooks)
- [x] Reward choice screen after each wave (pick 1 of 3): `reward_screen.gd`, pauses the game, mouse/1-3/gamepad
- [x] 8 starter upgrades: Ember Cleave, Static Step, Chain Spark, Whirlwind, Skybreaker, Bloodthirst, Momentum, Overflow
- [x] Run structure: rooms → elite → boss, run summary screen: `main.RUN_PLAN` (8 rooms, elites at 4 and 7, boss last), smaller room mixes, `run_summary.gd` on death/victory (Enter = new run)
- [x] Simple title screen + pause menu: `title_screen.gd`/`pause_menu.gd` on a shared `menu_screen.gd`; Esc/Start pauses (restart is Enter only now); `tests/menu_check.gd` screenshots both

## Polish / tech
- [x] Fade pillars that block the camera's view of the hero: `main._fade_occluders`; check with `tests/occlusion_check.gd`
- [x] Toon outline shader pass: `shaders/outline.gdshader` inverted hull in screen space (`width_px`), added to characters via `Fx.outline()` as a material next_pass
- [ ] Juggle counter / air-combo bonus feedback in HUD
- [ ] Settings for screen shake intensity
