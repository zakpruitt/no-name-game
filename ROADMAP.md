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
- [x] Build view: the pause menu lists your powers with their levels and current descriptions — "YOUR BUILD" panel left of the pause buttons (`pause_menu._build_powers`); `menu_check` grants two powers so `menu_pause.png` shows it
- [x] Charged-slam powers: 2 new [Charged] upgrades (Quake: the slam sends out a shockwave ring; Bone Breaker: bonus damage to shields and elites) — `quake` (shockwave from the impact: damage + launch in `radius`) and `bone_breaker` (+`bonus`% vs shield/elite/boss) in `Upgrades.ALL`; new `--upgrades=id,id` autotest flag. Bot rarely lands charges, so lightly exercised
- [x] Low-HP feedback: red edge vignette and a heartbeat below 25% HP — `hud._update_low_hp`: shader vignette fades in below `LOW_HP` and throbs on each `heartbeat` sfx (new in `gen_sfx.py`), beats quicken as HP drops; `--low-hp` autotest flag → `autotest_lowhp.png`
- [x] Bomber skeleton: walks up, lights a fuse (telegraph ring) and explodes — it hurts skeletons too, so lure it into crowds — `"bomber"` in `ENEMY_TYPES` (attack_kind "bomb", from room 4): carries a bomb, lights a fuse in range (flashing orange `blast_radius` ring); the fuse burns through hits/launches; blast hurts hero + skeletons, killed-while-lit bombers blow too (chains); hint + bot dashes clear. Looks close to a minion, could use its own look
- [x] Elite room twists: each elite room rolls one modifier (Hasted, Armored, Volatile = explode on death), shown on the door and the room title — `main.ELITE_TWISTS` (stat `mult`s or `volatile`), rolled per door offer; elite door reads "Elite · Hasted: faster foes"; HUD room line + banner show it; volatile corpses flash an orange ring then burst 0.7s later; `--twist=<id>` autotest flag

## Round 7
- [x] Bomber look: give bombers their own colour and silhouette so they read apart from minions at a glance — new `body_tint` stat (scorched orange bones), bigger bomb with a smouldering fuse; `tests/enemy_lineup.gd` shows every type side by side
- [x] Elite door check: autotest snaps a path screen that includes an elite door, and the twist text fits the button (`menu_check` saves `menu_path.png` with a Volatile elite door). Elite door now reads "Elite · Volatile / foes burst when slain, 2 powers"; door buttons share `button_width` 440
- [x] Enemy health bars: a thin bar over enemies once they've taken damage (elites always), fading when untouched — `enemy_bars.gd` HUD overlay: red bar (gold for elites) with a pale trail for the chunk just lost, shown `SHOW_TIME` 3s after a hit then fades; boss skipped. Juggled big elites can push it near the top HUD
- [x] Death recap: when you fall, the run summary says what killed you (enemy type / hazard) — `player.last_hit_by` (set on every hit from the attacker: "an elite skeleton archer", "the Bone Warden", "a spike trap"); "Slain by" heads the summary on a loss. New `"title"` per `ENEMY_TYPES` entry
- [x] New combo route: L L H finisher (a forward ground-breaker that knocks down everything in a line), with a matching upgrade slot — `MOVES.LLH` Ground Breaker (lunging thrust, strip hitbox via new `"width"` key, knockdown + guard break); L H stays the launcher; `fault_line` [LLH] upgrade re-erupts the strip; bot route now L H / L L H / L L L, `autotest_breaker.png`
- [x] Bone altar: between runs, spend saved bones on small permanent boosts (start HP, starting bones), saved in user:// and off in the autotest — `altar.gd` (`BOONS`: Hardened +HP, Scavenger +bones, Kindled +Awakening; `user://altar.cfg`), "Bone altar" on the title (`altar_menu.gd`); leftover bones bank at run end ("Bones banked" row); `menu_check` saves `menu_altar.png`

## Round 8
- [x] Altar in the autotest: `--altar=hardened:3,scavenger:1` applies boons without saving, so the start-of-run effects get checked — `Altar.override` (levels from the flag, never saved); autotest prints `altar=... max_hp=`; checked: hardened 3 gives 130 max HP
- [x] Verification pass: screenshot what hasn't been seen yet (Fault Line eruption, Quake ring, health bars at their final height, "Slain by" wording) and fix what looks off — Fault Line got a glowing strip that brightens until it erupts (it was lost in the dust); the near-edge rubble row now fades like pillars (it buried the hero); new `autotest_fault.png` / `autotest_slam.png`
- [x] Bot charge reliability: only start a charge when nothing nearby is winding up, so charged-slam powers get exercised — charges start from just outside melee reach (2.8–6m) with no windups, bolts or fuses near, creep toward the target, and retry after 1.5s if knocked out; slams landed in ~1 of 5 runs, now 4 of 5
- [x] Combo-routes hint: after the first launcher, teach L L H (ground breaker) — `breaker` hint once a launch has juggled and no Ground Breaker has been used yet; the autotest line now lists `hints=` shown
- [x] Perf: cut outline draw calls (~1.3k) and re-measure with the `[perf]` line — the shadow pass was the bigger cost: 2 cascades instead of 4 and no shadow casting from floor tiles took room 6 from ~916 to ~525 draw calls (room 1: ~630 → 437); frame time was already ~5.5ms avg with no spikes, so outlines stay as they are
- [x] Shrine room: a new door type with a trade (lose HP for a power, or bones for a full heal) for more route choices — `shrine` door from room 3 (never right after a rest or shrine); trades live in `main.SHRINE`, menu in `shrine.gd`; `--start-shrine` → `autotest_shrine.png`

## Round 9
- [x] Shrine in the world: a glowing shrine prop in the shrine room (KayKit piece + light) so it isn't just a menu over an empty arena — `shrine_prop.gd`: draped altar, candles, gilded sword-and-shield offering, pulsing violet light and motes; rises up-screen of the hero (clear of the menu title) and sinks after the trade; `autotest_shrine_room.png`
- [x] Health bars vs top HUD: keep enemy bars clear of the HP/room bars when juggled elites fly high (clamp below the HUD band) — `enemy_bars.TOP_MARGIN` 96px: bars pin just below the HUD band (and inside the screen edges), so off-screen juggled enemies still show their HP
- [x] Enemy variety pass: a second elite-only twist trait per late room (rooms 6–7 roll two twists) for late-run spice — `main.DOUBLE_TWIST_ROOM` 6: elite doors from room 6 roll two different twists ("Volatile + Hasted"), stacking their mults; `room_twists` array, `--twist=a,b`; doors widened to 580 so the longest text fits (`menu_path.png` now shows a double twist)
- [x] Power synergy tags: upgrades with a shared tag (fire, bone, quake) offer a small bonus when you own two, shown in the pause build view — `Upgrades.SYNERGIES` (Storm, Tremor, Ember, Blood, Night): own 2 of a tag and its `boost` multiplies those powers' lv keys inside `player.upg()`; "X SYNERGY" announce, tags on reward cards and the build panel, active synergies listed under YOUR BUILD
- [x] Autotest coverage: `--start-room=N --start-shrine`-style coverage for every room kind in one scripted run (fight → rest → shrine → elite → boss) printing a pass/fail line — `--tour` (`main.TOUR`): forced doors, fights wiped after `TOUR_FIGHT_TIME`, hero kept above half HP, `[tour] PASS rooms=fight,rest,shrine,elite,boss time=15.8s`; FAIL after `TOUR_TIMEOUT` 120s

## Round 10
- [x] Synergy numbers: reward cards and the build panel show the boosted values (e.g. "12 → 15 damage") when a synergy applies — `Upgrades.describe(u, level, active)` renders boosted keys as "base → boosted"; reward cards count the synergy the card itself would complete and add "Completes X synergy!"
- [x] Bottom HUD clearance: keep enemy health bars and the hint panel from covering the controls line at the bottom — `enemy_bars.BOTTOM_MARGIN` 48px keeps bars above the controls line (the hint panel already sat clear); the bottom-right power list ran off-screen with 17 powers, so lists over `hud.POWER_LINES` (14) drop to size 13
- [ ] Seeded runs: `--seed=N` makes layouts, doors, rewards and twists reproducible for comparing autotest runs
- [ ] Shrine variety: a third trade that rotates per shrine (e.g. lose a power level for 30 bones, or take a curse for an extra power)
- [ ] Synergy sound + flash: a distinct chime and a ring burst on the hero when a synergy activates (gen_sfx)
