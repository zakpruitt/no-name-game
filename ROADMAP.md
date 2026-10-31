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
- [x] Juggle counter / air-combo bonus feedback in HUD: "AIR xN" under the rank; `Game.AIR_MILESTONES` (3/6/10 hits) announce + pay style/Awakening; best juggle on the run summary
- [x] Settings for screen shake intensity: title + pause menu toggle cycles 100/50/0/150% (`Game.SHAKE_LEVELS`), saved to `user://settings.cfg`

## Round 2 (added once the first list was done; same rules)
- [x] Healing between rooms: `main.ROOM_CLEAR_HEAL` (25% max HP) on each room clear; `player.heal()` + `Fx.heal` green "+N" and ring (Bloodthirst uses it silently)
- [x] More upgrades (8 → 14): Rising Edge [L2], Riposte [Perfect], Long Night + Phoenix Heart [Awaken], Second Wind [Death], Reaper [Kill] (`Game.enemy_killed` signal)
- [x] Awakened moveset: Cataclysm (`MOVES.AF`) replaces heavy after L3 while Awakened; 360° launch + fire rings + `CATACLYSM_WAVES` radiating fire waves. `--start-awakened` flag, `autotest_finisher.png`
- [x] Shield skeleton: `ENEMY_TYPES.shield` (from room 3), blocks frontal hits while walking/recovering; big hits/launchers break guard 2s; sides/back always land. Shield model in `assets/kaykit/props/`
- [x] Room variety: `main.LAYOUTS` (hall / crossroads / gauntlet) chosen per room by `ROOM_LAYOUTS`, pillars sink/rise between rooms; `spike_trap.gd` tiles from room 4 (warn → stab; hurts hero, launches skeletons)
- [x] Off-screen threat indicators: `threat_arrows.gd` draws notched edge arrows for off-screen windups (red melee / purple ranged, grow as the hit nears) and bolts

## Round 3
- [x] Branching path: after each reward, choose the next room from 2 doors (fight / elite for a rarer reward / rest to heal) — `path_options()` + `path_choice.gd`; elites give 2 powers, rest heals 40%
- [x] Skeleton archer: crossbow skeleton (KayKit `Skeleton_Crossbow`) with a fast, telegraphed line shot — `ENEMY_TYPES.archer` (attack_kind "line", from room 3); orange ground line tracks you, locks red at `AIM_LOCK` 70%, then a 30 m/s bolt; `autotest_archer.png`
- [x] Upgrade levels: re-offering an owned upgrade levels it up (stronger numbers) once the pool runs thin — level-ups mix into every roll (up to `Upgrades.MAX_LEVEL` 3); numbers live in each entry's `lv` table and fill the card text; HUD/summary show "II"/"III"; `--max-upgrades` flag
- [x] Music: synthesized ambient loop with a combat layer that swells with style rank — `tools/gen_music.py` (96 BPM D-minor pad + drums/bass, 20s loops); `Game.MUSIC_RANK_LEVEL` drives the combat layer; Music volume in title/pause menus
- [x] Performance check: frame time with 12+ enemies, outlines, particles; fix hot spots — autotest prints a `[perf]` line (avg 5.5ms, worst ~21ms with 17 enemies + all upgrades, ~1.3k draw calls); fixed a ~150ms hitch entering the boss room by caching character models (`main._model()`) and preloading shield/crossbow

## Round 4
- [x] Spawn pacing: rooms bring enemies in waves (cap on how many are alive at once, the rest trickle in) so late and elite rooms stop feeling crowded — `main.MAX_ALIVE` 8 up at once, the rest queue and step in `REINFORCE_DELAY` 0.7s after each kill; HUD shows "N LEFT"
- [x] Archer readability: give archers their own look (tinted hood/cloak) so they don't read as rogues; shrink the oversized "CHOOSE YOUR PATH" title — `cloth_color` export (archer: dark green hood/cape via `ENEMY_TYPES`), `menu_screen.title_size` (path screen 56px); archer screenshot now waits for an on-screen archer
- [x] Charged heavy: hold heavy to charge a bigger hit (charge glow, breaks shields, launches), release early for the normal heavy — `State.CHARGE` + `MOVES.CH` (30 dmg, launch 8); `CHARGE_TIME` 0.8s, creep at 35% speed, dash cancels; gold glow + motes, ring/flash when full; `autotest_charge.png`. Note: neutral H now starts on release (tap length of lag)
- [x] First-run hints: short contextual prompts in room 1 (dash through attacks, launch with L→H, awaken when the meter is full), shown once and saved — `Game.HINTS` text (attack, dash, launch, shield, awaken), triggers in `main._check_hints()` with a 7s gap; saved to settings.cfg, "Reset hints" in pause; autotest/tests never save them; `autotest_hint.png`
- [x] Run records: save best room, best combo, best rank and wins to `user://`; show them on the title screen and flag new bests on the run summary — `records.gd` (`user://records.cfg`: runs, wins, best room/combo/rank/juggle, fastest win); title footer line; gold "NEW BEST" rows; autotest never saves
- [x] Gamepad rumble on big hits, perfect dodges and taking damage (respects a setting) — `Game.RUMBLE` table (hit_big / perfect / hurt / awaken: weak, strong, seconds), `Game.rumble()`; "Rumble: On/Off" in title + pause, saved. Untested on a real pad

## Round 5
- [x] Settings submenu: move shake / music / rumble / reset hints into one Settings screen shared by title and pause (menus are getting long); give hints a soft backdrop for readability — `menu_screen.open_settings()`; Esc backs out to pause; hint sits on a dark rounded panel; `menu_check` also saves `menu_settings.png`
- [x] Bones: enemies drop bones (auto-collected, more from elites); HUD counter; kept per run and listed on the summary — `bone_pickup.gd` shards pop out and home in; `"bones"` per `ENEMY_TYPES` entry (×3 elites), `Game.bones`/`bones_total`; "BONES n" by the HP bar; "Bones collected" on the summary; `pickup` sfx
- [x] Camp: rest rooms let you spend bones (max HP up, reroll a power, upgrade a power) besides the free heal — `camp.gd` menu after the heal: Vigor / Seek a power / Hone a power, costs in `main.CAMP`; unaffordable options greyed out
- [x] Reward reroll: spend bones to reroll the 3 power cards — Reroll [R] button under the cards; `main.REROLL_COST` 8, +`REROLL_COST_STEP` 4 per reroll of the same offer; greyed out when short
- [x] Necromancer skeleton: hangs back and raises fallen minions until it's killed (priority target) — `"necromancer"` in `ENEMY_TYPES` (dark-hatted mage, attack_kind "raise", from room 5): raises its `raise_count` nearest minion graves (`RAISE_RANGE`, `MAX_GRAVES`) with green rings, else shoots a bolt; its risen drop no bones and crumble when it dies; first-raise hint
- [x] Bone Warden phase 2: a new enraged attack (line of ground spikes chasing the hero) — `"spikes"` in `boss.ATTACKS` (enraged only): ground chop, then 12 bone spikes (`bone_spike.gd`) run at the hero, steering ≤22° per step, each red-flagged 0.4s before it stabs; `--boss-enraged` autotest flag → `autotest_spikes.png`

## Round 6
- [x] Hints wait for menus: never show a hint behind the reward / camp / path screens (hold it until play resumes) — `hud._notification` hides the hint panel on NOTIFICATION_PAUSED and restores it on UNPAUSED; its fade tween pauses with the tree
- [ ] Build view: the pause menu lists your powers with their levels and current descriptions
- [ ] Charged-slam powers: 2 new [Charged] upgrades (Quake: the slam sends out a shockwave ring; Bone Breaker: bonus damage to shields and elites)
- [ ] Low-HP feedback: red edge vignette and a heartbeat below 25% HP
- [ ] Bomber skeleton: walks up, lights a fuse (telegraph ring) and explodes — it hurts skeletons too, so lure it into crowds
- [ ] Elite room twists: each elite room rolls one modifier (Hasted, Armored, Volatile = explode on death), shown on the door and the room title
