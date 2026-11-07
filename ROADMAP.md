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
- [x] Seeded runs: `--seed=N` makes layouts, doors, rewards and twists reproducible for comparing autotest runs — seeds the global RNG plus a dedicated `main.run_rng` for doors/twists/spawn order/reward rolls (combat FX and AI draw from the global one, so they no longer shift the run); `seed=` in the autotest line; checked: two `--tour --seed=1234` runs picked identical powers
- [x] Shrine variety: a third trade that rotates per shrine (e.g. lose a power level for 30 bones, or take a curse for an extra power) — `main.SHRINE_ROTATING`: Dark vow (next room gets the Armored twist, gain a power) or Melt down (a random owned power for 20 bones/level), rolled with `run_rng`; `--shrine-trade=` forces one; autotest `kind=` now shows twists (`fight+armored`)
- [x] Synergy sound + flash: a distinct chime and a ring burst on the hero when a synergy activates (gen_sfx) — `synergy.wav` (rising C-E-G-C arpeggio + whoosh), teal ring, flash and sparks from `player._synergy_burst()`; autotest snaps `autotest_synergy.png` on the first one (`--upgrades=skybreaker,quake` triggers it at once)

## Round 11
- [x] Run summary: show the run's seed and active synergies, so a good run can be replayed and its build read at a glance — teal "Synergies: Storm, Tremor" line under the powers and a faint "seed N" under the New run button (replay with `--seed=N`)
- [x] Daily run: a title-screen option that starts a run from today's date as the seed (same doors/rewards for everyone that day) — "Daily run" on the title; `main.daily_seed(date)` hashes the date into `run_seed`/`run_rng`; summary reads "daily run 2026-10-31 · seed N"; `--daily` flag; two `--tour --daily` runs got identical powers
- [x] Boss variety: a new Bone Warden attack for phase 2 (e.g. a ring of bone walls that closes in, with a gap to dash through) — enraged "cage" (`bone_cage.gd`, `ATTACKS.cage`): 7m ring of bone walls around the hero closes to 1m over 2.6s, turning, with a 50° gap; dash i-frames pass walls; `--boss-attack=cage` forces it → `autotest_cage.png`
- [x] Tour coverage: the `--tour` shrine takes the rotating trade and the rest camp buys something, so those paths run every tour — camp is topped up to its first offer and buys it, shrine takes vow/melt; PASS needs both; `[tour]` line prints `trades=camp:vigor,camp:leave,shrine:melt` (seeds 1–3 cover melt and vow)
- [x] Telegraph readability: enemy attack rings get a pulsing edge so they read on bright floor tiles and for colour-blind players — every enemy/boss attack ring gets a pale rim (pulses 3→9 Hz as the windup runs out) plus a dark outline (`enemy.EDGE_*`, `fit_edge()`)

## Round 12
- [x] Boss slam readability: the Warden's slam landing ring and the bone cage's floor band get the same pale rim + dark outline as enemy telegraphs — rim code moved to `Fx.edge_ring()` / `fit_edge()` / `pulse_edge()` (`Fx.EDGE_*`); slam ring pulses with its windup, cage band rim follows the closing walls
- [x] Cage hint: the first bone cage shows a one-time hint ("Find the gap, or dash through a wall") through `Game.HINTS` — `Game.HINTS.cage`, shown from the boss `cage` signal (skips the HINT_GAP queue since it is urgent); autotest prints `hints=attack,cage`
- [x] Cage sound: a distinct grinding-bone sfx (gen_sfx) as the cage rises and closes, instead of reusing `hit_big` — `cage_rise` (bone rattle + low grind, 0.8s) when the walls burst up, `cage_shut` (clack + crunch) when it closes; gen_sfx output for existing sounds unchanged; not listened to yet
- [x] Pause menu run info: show the run seed (and "daily run DATE") in the pause panel, so a run can be noted mid-way — footer reads "Room 1 / 8 · seed N" (plus "daily run DATE" on a daily run), `pause_menu._run_info()`
- [x] Recent runs: the title screen lists the last 5 runs (room reached, result, seed) from `records.cfg` (disabled in tests) — "RECENT RUNS" panel right of the title menu (`records.recent_runs()`, `RECENT` = 5, saved under `[recent]` in records.cfg); lines read "Fell in room 6   rank A   seed N" or "Victory   rank S   daily DATE"; save/cap checked with a temp records.cfg, then deleted

## Round 13
- [x] Bot cage escape: the autotest bot heads for the bone cage's gap (or dashes a wall) so `--boss-attack=cage` runs survive and exercise the escape path; print `cage_escapes=` — `main._bot_escape_cage()` runs for the gap and dashes a wall when it is about to reach the hero away from the gap; `bone_cage.raised`/`escapes` counters; three forced-cage runs: 5/7, 8/9, 7/8 escaped, hero survived all (was dying)
- [x] Replay a recent run: picking a line in the title's RECENT RUNS starts a new run on that seed — each RECENT RUNS line is a flat button ("Pick a run to replay its seed"); `title.replay` → main sets `run_seed`/`run_rng` (and `daily_date` for a daily); checked: picking a line started seed 404135889
- [x] New elite twist "Splitting": slain foes split into two minions (once), shown on the door like the other twists — `ELITE_TWISTS.splitting` ("split": 2), `main._split()`: minions at `SPLIT_HP` 0.5 HP, `SPLIT_SCALE` 0.7 size, no bones, never split again or from raised minions; autotest prints `splits=`, `--twist=splitting` → `autotest_split.png`; combines with Volatile (splits=8 blasts=12)
- [x] Death recap for hazards: "Slain by" names the bone cage / spike line / volatile burst instead of the Warden or a generic foe — `player.take_hit(..., cause)`; reads "the Bone Warden's cage", "the Bone Warden's bone spikes", "a skeleton warrior's dying burst" (volatile), "a bomber's blast"; spike traps already said "a spike trap"

## Round 14
- [x] Recent runs focus: keyboard/gamepad can move from the title buttons into the RECENT RUNS lines (explicit focus neighbours), checked by a menu_check step — title buttons' `focus_neighbor_right` → first recent line, lines' left → Start run; menu_check builds a sample line and prints `recent focus=true` after ui_right (left not separately checked)
- [x] New power "Shatter" [H finisher]: a heavy that kills a foe bursts it into bone shards that hit nearby enemies (per-level damage/radius in `Upgrades.ALL`, Tremor-free so it opens a new build) — `Upgrades.ALL` shatter (slot Heavy: H/LH/LLH/CH/AF kills, not the boss), damage 10/16/24, radius 3/3.5/4; `player._shatter()`; autotest `shatters=` + `autotest_shatter.png`; 1–5 per bot run
- [x] Reduce flashing setting: a Settings toggle that tones down full-screen flashes and hit flashes (saved like the other settings) — "Reduce flashing: On/Off" in Settings (`Game.reduce_flashing`, saved as video/reduce_flashing): white hit flash alpha 0.85→0.3, hit sparks 60% size / 45% alpha, low-HP vignette stops throbbing; `--reduce-flashing` for tests (not saved)
- [x] Elite pacing check: autotest prints room clear time; compare Splitting/Volatile/Armored rooms against a plain fight over a few seeds and note the numbers in ROADMAP — `--pace` ends the autotest at the first clear and prints `cleared room=N kind=... time=`. Bot, room 3, seeds 1–3 (clear time s / hero HP left):
  - plain fight: 13.2, 23.0, 11.7 → avg 16.0 (HP 86–100)
  - elite+armored: 22.0, 19.7, 28.4 → avg 23.4 (HP 64–100)
  - elite+splitting: 20.2, 25.8, 23.7 → avg 23.2 (HP 76–100)
  - elite+hasted: 16.5, 19.3, 14.1 → avg 16.6 (HP 82–100)
  - elite+volatile: 8.5, 17.3, 12.1 → avg 12.6 (HP 72–100) — bursts chain-kill the crowd, so it's the fastest room
  - Splitting ≈ Armored (~45% longer than a plain fight); Volatile clears faster than plain and may want a nerf (smaller VOLATILE_RADIUS or less blast_enemy_damage). Bot-only numbers; a human will differ

## Round 15
- [x] Volatile tune: the pacing check found Volatile rooms clear faster than plain fights; trim the burst's damage to other skeletons so it stays a threat rather than a free wipe, then re-run `--pace` and note the new numbers — `enemy.VOLATILE_ENEMY_DAMAGE` 12 (was the bomber's 40) only moved the avg 12.6→12.8s; the real cause was the burst launching crowds (`blast_enemy_launch`, `VOLATILE_ENEMY_LAUNCH` 0). Now seeds 1–3: 17.8, 18.5, 11.8 → avg 16.0s (= plain fight), hero HP 72–87 (was 72–100)
- [x] "Bone" synergy: Shatter + Bone Breaker share a tag that boosts both (shard damage and the slam bonus), so the new power has a build to grow into — `SYNERGIES.bone` (shatter + bone_breaker): damage ×1.3, bonus ×1.3, radius ×1.2; checked: Shatter L1 reads "10 → 13 damage ... 3 → 3.6m", Bone Breaker bonus 80→104%, synergy burst fires
- [x] Split minions read apart: tint the Splitting twist's minions (pale bone glow) so they're distinguishable from regular minions — `enemy.set_glow()` rim overlay (restored after hit flashes), `main.SPLIT_GLOW` pale icy blue; split screenshot now 1.3s after the split
- [x] Boss pacing baseline (bot, `--pace --start-room=8`, no powers, level 1, 2026-11-01): seeds 1-5 killed the Warden in 13.6 / 13.2 / 24.4 / 25.4 / 23.5s with 105 / 83 / 57 / 5 / 63 HP left (of 100 + room bonuses). Spread is wide: one seed nearly died, two were quick

## Round 16 (feedback)
- [x] Combo callouts: landing a named combo (`player.COMBOS`: Triple Chop, Dash Stab, Launcher, Ground Breaker, Charged Slam, Cataclysm) plays a quiet tier sound (`combo_1..3`) and shows its name above the hero; pause menu gets a fixed MOVES list. Autotest prints `callouts=` and saves `autotest_callout.png`

## Round 17 (shaman rework)
- [x] Short Awakening: 8s flat (`player.awaken_duration`), no meter gain while Awakened (`Game.awaken_locked`), meter empties when it ends; Long Night removed (Night synergy is now Overflow + Phoenix Heart)
- [x] Hero levels: XP from kills, level-ups during the run, level shown on the HUD — `Game.LEVEL_XP` [4, 12, 24, 40, 60] (XP = enemy bones, so risen/split give none), `LEVEL_MAX` 6; each level +5 max HP (`player.level_hp`) and heals it; HUD "LV n" + thin XP bar; `--level=N` starts there; autotest prints `level= xp=`
- [x] Ascendancy at level 6: pick Wind (storm, light green), Earth (magma, volcanoes) or Water (ice); the path reshapes Awakening (colours, passive, finisher) — `scripts/ascendancy.gd` (`PATHS` tuning + effects), chosen on `ascend_menu.gd` at the first room clear after level 6. Wind: 1.25x speed, half dash cooldown, lightning every 3rd hit, finisher Tempest (pulling cyclone). Earth: 0.45x damage taken, heavy moves leave magma, finisher Eruption (volcano lobbing lava bombs). Water: hits chill, 4 hits freeze, frozen hits x1.5 and shatter, finisher Glacier (ice ring freezes all). `--ascend=wind|earth|water`, `tests/ascend_check.gd` PASS
- [ ] Element powers: reward powers tagged Wind/Earth/Water that the matching Ascendancy boosts (Water has no powers yet; Storm/Tremor/Ember could fold into Wind/Earth)
- [ ] Ascendancy feel pass by hand: is Earth's armor too safe, Water's freeze too strong vs elites, Wind's speed too twitchy?
- [x] Shaman look: recolour the Barbarian, rune-glowing dual axes, charms/feathers from primitives; ascended forms glow in their element — `tools/gen_shaman_texture.gd` recolours the palette atlas (grey wolf pelt, teal shirt, dark leather and beard, turquoise axe wraps) into `assets/hero/shaman_texture.png`; `scripts/hero_look.gd` adds hanging feathers, a bead-and-fang necklace and teal axe runes; Awakening is ancestral gold until an Ascendancy recolours it (with element motes). `tests/hero_preview.gd` renders the close-up

## Round 18 (elemental shaman)
- [x] Elemental casts: every move summons the hero's element (spirit before an Ascendancy, then wind/earth/water) — `scripts/elements.gd` `CASTS`: L1/L2/DL blades and L3 a fan of three (crescents, ice shards, or stone spikes along the ground), H a vortex round the spin, LH a pillar under the target that launches (beam, tornado, stone pillar, geyser), LLH a fissure, CH a nova. L2 is now a throw and LH a raised-arm cast (`Throw`, `Spellcast_Raise`). Motes orbit the hero (3 at rest, 7 Awakened). Casts stop at walls. Quiet per-element cast sounds (`cast_*`). `prewarm()` removed an ~800ms first-use shader hitch
- [x] Awakened ultimates: L H H = SKY (Ancestor's Fall / Thunder Dive / Meteor Fall / Frozen Comet), Dash L H = RUSH (Spirit Stampede / Gale Rush / Tectonic Charge / Tidal Surge), plus the finisher; slow-mo, camera push-in, a screen banner with the name, invulnerable while it plays. Each one in the same Awakening adds +30% damage (CHAIN x2, x3); all three in one Awakening call the Trinity (Ancestral Storm / Skyfall / Worldbreaker / Absolute Zero). `tests/ult_check.gd` PASS for all four elements; `tests/element_preview.gd` renders them
- [ ] Ultimate feel pass by hand: are 8s enough for all three plus the Trinity? Is RUSH's charge readable, and does the banner block the fight?
- [ ] Model work: element-specific kit pieces on the shaman (wind feathers, magma-cracked shoulder stones, ice crown) and a proper casting pose instead of the KayKit Spellcast_Raise

## Round 19 (combo guide)
- [x] Combo guide: mid-string, rows beside the hero show each input that continues it (button glyph: LMB / RMB / Space; the game shows one control set, mouse and keyboard), the move it starts in its tier colour (ultimates in the element colour, glowing), and the best named combo one more press past it. A ring fills toward the cancel point and the rows light up once a press would be taken; pressing flashes the row from `_input`, before the move starts. Real-time animation (no stalls in hitstop/slow-mo). Routing moved into `player.route()` so the guide and the moves can't disagree; `tests/guide_check.gd` PASS checks every row against the real routing and renders `guide_sheet.png`. Settings toggle "Combo guide"
- [ ] Guide feel pass by hand: placement next to the hero vs. the fight, whether the follow-up hint is too much once the moves are learned

## Round 20 (power paths)
- [x] Power paths: every power belongs to the button it upgrades and wears that colour everywhere: Light/LMB blue, Heavy/RMB gold, Dash/Space green, Awaken/Q violet, Soul rose (kills, death, juggles). The guide's key rims use the same colours (`Upgrades.PATHS`). Own 3 of a path for its mastery (+15% light or heavy damage, faster dashes and a stronger Dash Stab, +2s Awakening, +20 max HP)
- [x] Power icons and UI: 25 glyph icons (`tools/gen_power_icons.py` → `assets/icons/powers/`, drawn by `PowerIcon` in a path-coloured ring with level pips). Reward cards rebuilt: colour band, key chips, icon, numbers in the path colour, mastery progress ("HEAVY ■■□ MASTERY" / "UNLOCKS LIGHT MASTERY"); cards deal in. The pause build view groups powers by path with icons; the HUD shows owned powers as an icon strip; the run summary shows the icons
- [x] New powers to balance the paths: Quickblade and Thousand Cuts (Light), Slipstream (Dash), Eruption (Awaken). Fusions, two-colour cards offered only once you own both paths (`FUSION_CHANCE` 50% to take the last card): Crescendo (Light+Heavy), Flicker (Light+Dash), Shockstep (Heavy+Dash), Undying Flame (Awaken+Soul). `tests/power_check.gd` PASS checks the data, fusion offers, masteries and every new effect, and renders `power_cards.png` / `power_build.png` / `power_hud.png`; autotest prints `masteries=` and `power_procs=`
- [ ] Power feel pass by hand: are the mastery numbers worth chasing; do fusions show up often enough; are the weaker icons (Riposte, Shockstep) readable at HUD size
- [x] Wiki: show paths, masteries and fusions on the powers page: a Paths table (button, power count, mastery) and a path chip per power in its colour (two for a fusion). The run section now describes the map, vaults and trials instead of the two doors (Round 23)
- [ ] Element powers could become a sixth path later (see Round 17)

## Round 21 (run map)
- [x] Run map: the whole run is laid out at the start (8 columns, up to 3 lanes, the boss at the end) and you pick the next room on it instead of from two blind doors. Elite twists, vault colours and trial conditions show ahead; the route so far is lit; pause → Map shows it read-only. `RunMap` (`scripts/run_map.gd`: `WEIGHTS`, `KINDS`, `TRIALS`) generates it from `run_rng`, so seeded and daily runs share the map (seeds give different runs than before this round); `map_screen.gd` draws it; `path_choice.gd` and `path_options()` are gone. `tests/map_check.gd` PASS over 500 seeds (links, reachability, no two fightless rooms linked, rest before the boss)
- [x] Vault room: a gold chest lit in a path's colour offers 1 of 3 powers of that path (fusions count), so you can route toward your build — `main._vault()`, `vault_prop.gd`, `Upgrades.roll(..., path)`; `--start-vault=light`
- [x] Trial room: three quarters of a fight with a condition (Untouched: no hits; Swift: clear in 20 + 4×room s; Stylish: reach rank A), shown live under the room title; meeting it offers a fusion (`Upgrades.roll_fusion`), else a level-up, else 20 bones — `--start-trial=id`, autotest prints `trial=... met|failed`. Tour now runs fight → rest → shrine → elite → vault → trial → boss
- [ ] Map feel pass by hand: is the route choice interesting (enough vaults/trials vs fights in `RunMap.WEIGHTS`), is Swift's time fair for a person rather than the bot (bot data: 8-9s of 32 in room 3, 16-20s of 48 in room 7, so it's lenient early; a tighter `time` 12 would keep room 7 at 2.2x the bot), should Untouched forgive a chip hit

## Round 22 (map polish)
- [x] Map screen pass: the run's map shows once before room 1 ("YOUR RUN", Enter begins); focusing a choice lights the routes it leads to and dims rooms it can't reach, and the panel adds "Leads on to: 2 elites · Light vault · 1 rest"; hover any room for its detail ("out of reach now" / "on your way"); a legend of room kinds along the bottom; the marker walks to the picked room before the map closes; the HUD hides under the map. `map_check` now also checks the screen headless (hover, focus, walk, HUD restore)
- [x] Showman trial: land 4 different named combos in the room (`RunMap.TRIALS.showman.count`), live "2 / 4 combos" under the title; ties the map's trials to the combo list. `--start-trial=showman`
- [x] Unknown rooms (?): about one a map (`RunMap.WEIGHTS.mystery`), revealed on entry from `RunMap.MYSTERY` (leans toward elites and vaults), counted as fightless for the links so any reveal is legal; the node becomes what it was and the banner reads "ROOM N · UNKNOWN". `--start-mystery`; `map_check` reveals every unknown room over 500 seeds
- [x] Read-only map cursor: on pause → Map the arrows walk over the rooms (columns left/right, lanes up/down) and show each one's detail, so the map isn't mouse-only (`map_screen.move_cursor`, checked in `map_check`)
- [x] Map status line: HP, bones and level at the top left of the map (red below 40% HP), since the HUD is hidden while choosing and that's when HP decides rest vs elite (`map_screen.set_status`)
- [x] HUD route strip: a dot per room across the top of the screen, the rooms taken in their map colours and this room ringed, so the run's shape reads mid-fight (`hud.set_route`)
- [x] Map weights: vaults were the rarest room (about 1.3 a map, since they can't follow a rest or shrine); `RunMap.WEIGHTS` now vault 22, trial 12, rest 10, shrine 9 for about 2 vaults and 2 trials a map

## Round 23 (combos)
- [x] Flurry (L L, pause, L): let L2 finish, then light within the chain's grace for five quick cuts with little knockback; mashing still gives Triple Chop. Cyclone (Dash > H): a four-hit spin that keeps travelling (`MOVES.decay`, a slower lunge falloff). Both route through `player.route()`, so the guide shows them (Flurry in the pause gap, Cyclone after a dash); `guide_check` PASS checks both and that L L L stays Triple Chop. Cyclone counts as a heavy (Shatter, Earth's Awakened bonus), Flurry as a light (Quickblade, Thousand Cuts). The bot uses both; autotest prints `moves=`
- [x] Combos landed: the pause menu's MOVES list shows how often each named combo was landed this run ("×3") and dims the ones still to find, with "5 / 11 combos landed"; the run summary adds "Combos found" (`player.combos_landed`)
- [x] The guide stops hinting a follow-up once that combo has been landed 6 times in the run (`player.GUIDE_LEARNED`; ultimates always hinted), so the hints thin out as the moves are learned
- [x] The combo guide hints the pause combo: mid-L2 the light row adds "or pause: Flurry", from `route()` asked as if L2 had finished, so it stays in step with the routing (`guide_check` PASS)
- [x] Powers for the new combos: Razor Gale (Light, Flurry: the last cut flings a fan of 3/4/5 element blades) and Eye of the Storm (Dash, Cyclone: each hit drags foes within 5/6/7.5m into the spin, not the boss). The dash heavy was renamed Cyclone, since Whirlwind is already the Spin's power. `power_check` PASS covers both
- [x] Spike (L H H): heavy again after the launcher was just a second launcher; now an overhead chop that slams juggled foes into the floor (+60%, `SPIKE_AIR_MULT`) and knocks down foes where they land (`SPIKE_IMPACT`). Awakened it is still Ancestor's Fall, so the ultimate reads as Spike's big version. The guide shows Spike as the launcher's follow-up; autotest prints `spikes=`
- [x] Rebound (Soul, Spike): spiked foes bounce back up 7/8.5/10 m/s off the floor for another juggle, so L H H can loop; Soul had only three powers
- [x] War Chant (Awaken, named combos): each named combo grants 3/4.5/6 Awakening, double when it differs from the last one, so varying the string fills the meter (Awaken had only three powers)
- [x] Sky Reaper (Light + Soul fusion): light hits on juggled foes deal +40/60/85%, the payoff for launcher and Rebound juggles
- [x] Element casts for the new combos (`elements.CASTS`): Flurry throws two small bolts, Cyclone carries the element vortex with it
- [x] Fusion frequency measured (2000 simulated runs of `Upgrades.roll`, random picks): a fusion is offered in 83% of runs with 6 rewards (first at about the 4th reward, 1.4 offers a run) and 97% with 9 (2.6 offers), before trials add theirs, so `FUSION_CHANCE` 0.5 stays
- [x] Windowed screenshot pass (2026-11-01; all read cleanly, one fix: the intro's "Ahead" line kept "1 unknown" / "Light vault" whole when it wraps): the map intro and route preview (`menu_check` → `menu_intro.png`, `map_check.png`: status line, detail panel with the vault / trial / rest / shrine / unknown / power-range lines and its lift), the HUD route strip and "New combo" hint (`autotest_*.png`), the guide's pause hint (`guide_sheet.png`), reward cards with the combo input line and "fired ×N" (`power_cards.png`), the build view's input lines and fire counts plus the MOVES list's hooked powers (`power_build.png`), the run summary's Signature combo / Busiest power (`autotest_summary.png`), Cyclone and Spike in motion
- [x] A combo power's card flags a combo you haven't landed this run ("Flurry: L L, pause, L (not landed yet)", amber), so a power on a move you don't use reads as a commitment
- [x] The pause MOVES list shows the owned powers under each combo they hook ("L H H   Spike   ×3" then "+ Rebound"), tying the combo list to the build
- [x] The run summary adds "Busiest power: Reaper ×16", the owned power that fired most (`main._busiest_power`, from `player.power_procs`)
- [x] Unknown rooms on the map list their odds ("Could be: Elite 25% · Fight 20% · Vault 18% · ..."), so a ? is a gamble you can price (`RunMap.mystery_odds`)
- [x] The autotest bot spins from neutral every ~4s (it waits for the string to reset, then heavy), so Whirlwind fires in `--all-upgrades` runs; it never did, since the bot always heavied mid-string (LH / LLH)
- [x] Level-up cards say how often the power has fired this run ("LEVEL UP 1 → 2 · fired ×5"), so levelling a power you rarely trigger is a visible choice
- [x] The pause build view shows how often each power fired this run ("Rebound   ×7 this run"), so a power that never triggers for your playstyle shows
- [x] Every power now counts its procs (`player.power_procs`, autotest `power_procs=`), not only the newer ones. With `--all-upgrades` over seeds 1-3, Quickblade, Reaper and Undying Flame fire most; Static Step, Riposte, Crescendo and Fault Line about once a run; Whirlwind, Quake, Bone Breaker and Second Wind never (the bot rarely spins, charges or nearly dies), so those stay covered by `power_check`
- [x] The run summary adds "Signature combo: Flurry ×12", the named combo landed most (`main._signature_combo`)
- [x] Move DPS audit (damage to the cancel point, no powers): L1 18, L2 13, L3 21, Flurry 29, Spin 11 (AoE), Launcher 16, Spike 22 (35 on a juggled foe), Ground Breaker 19, Dash Stab 15, Cyclone 21; Charged Slam 31 and the finisher 39 by design. No outliers after the Cyclone retune; `power_check` now fails any move over 1.75x the median (`DPS_LIMIT`)
- [x] Map rooms say how many powers lie between them and the boss over every route on ("4–6 powers from here to the boss"), so a rest's cost in powers is visible (`RunMap.power_range`)
- [x] The map's detail panel fits its lines and lifts itself when they'd run off the bottom (the new vault/rest/shrine lines reached 873 of 900px; `map_screen.DETAIL_BOTTOM`)
- [x] Map shrines and rests show their prices against your HP and bones ("Blood pact costs 33 HP · Bone offering 15 bones (you have 12)", "Camp offers from 15 bones") (`main._map_notes`)
- [x] Map rests say what they'd heal right now ("Heals 40 HP now (30 → 70 / 100)", or that you're at full HP), so rest vs. elite is read off the map (`map_screen.rest_text`)
- [x] First time a named combo lands in a run, the HUD hint shows "New combo: Flurry  (L L, pause, L)  ·  5 / 11 found" (`player.combo_found`), so finding the moveset is a moment rather than only a pause-menu count
- [x] The pause build view also shows each combo power's input under it ("Spike:  L H H"); `Upgrades.combo_of()` maps a power to its combo for both
- [x] Map vaults say what's left in their path for your build ("In the vault: 3 new, 2 to level up", or that it tops up from other paths), so a vault of a nearly finished path isn't a trap (`map_screen.vault_pool`)
- [x] Map trials say what they'd pay with your build ("Fusion ready: Sky Reaper" or "pays a level-up"), so routing to a trial is a real choice rather than a guess (`map_screen.trial_payout`)
- [x] Reward cards for a power on a named combo show how to do it ("Flurry:  L L, pause, L"), so a new combo's power doesn't need the pause menu to look up its input
- [x] Cyclone retuned: its spin anim is short, so it reached its cancel in 0.31s for 24 AoE damage (78 DPS, the most of any move, while moving). `MOVES.speed` (new, optional) slows it to 0.55x: 20 damage over about 0.56s, near the Launcher and Dash Stab; lunge 11 → 9 since it now lasts longer
- [x] Synergies for the new powers: Gale (Razor Gale, Eye of the Storm, Slipstream: +25% damage, +20% reach) and Sky (Rising Edge, Rebound, Sky Reaper, Chain Spark: launch +20%, +25% damage); War Chant joins Night (its Awakening +25%)

## Round 24 (training)
- [x] Training mode: title → Training opens one room with a dummy that never fights back or dies (`training_dummy.gd`); the HUD shows each string's damage and hits plus the best; Esc offers a free power pick (free rerolls), Fill Awakening, Ascend and Restart training (`main._start_training`, `pause_menu._open_training`, `tests/training_check.gd`)

## Round 25 (combo breakers and strings that move)
- [x] Combo breakers (`player.BREAKERS`, docs/features/combo-breakers.md): timed finishers on enders, only when the ender connected, with a slow-motion window (`BREAKER_FOCUS`), PERFECT freeze-frame and Awakened ancestors. Ground Breaker (L L H) throws spectral axes and dives onto them; Charged Slam juggles in a sawblade; Flurry dashes through the line; Cyclone (Dash H) pulls foes in and flings a ring of tomahawks; Spike (L H H) drops a hovering axe on every foe. `tests/breaker_check.gd`
- [x] Breaker timing circle (`breaker_prompt.gd`): fills to the sweet spot with the heavy button in the middle and the breaker's name under it, pinned up and to the hero's left (the combo guide is on his right), separate from the guide. `tests/prompt_follow_check.gd`
- [x] Dash out of a breaker's hang calls it off (dash cancels anything); the autotest bot is exempt so its dodges don't throw breakers away
- [x] Strings move: `MOVES` `hop` (L2, Triple Chop, Launcher, Charged Slam, Dash Stab pounce, neutral heavy whirl), `weave` (Flurry sways side to side and leaves afterimages); landings slam harder from higher. `tests/hop_check.gd`
- [x] Air string: L H then light = Air Slash, then Sky Rend (L H L L), climbing each cut (capped at `AIR_MAX_HEIGHT`); air moves home in on the juggled foe; moves that start in the air plunge for more damage (`PLUNGE_PER_M`); Triple Chop from the top is Skyfall, slamming a fan of spectral axes
- [x] Air dash: one per trip up, keeps his height and carries the string on in the air (route `from` "AD"), cutting with a spectral axe
- [x] Breakers easier to land and more barbaric: a mashed press spilling over from the ender is ignored (`BREAKER_SPILL`) and one a hair early is held to the window (`BREAKER_EARLY`); war cry as the window opens; landings crack the floor into a crater with heaved slabs and rubble; a PERFECT makes the element erupt round it (`breaker_quake.gd`). `breaker_check` spill/held cases
- [x] Higher air string: heavy off Sky Rend is the Updraft (a gale lifts him to 4.2 m and gives the air dash back, once per trip up), then Gale Waltz, and Triple Chop from the top lands as Stormfall (crater + element eruption). `hop_check` Updraft cases, `cast_dump --cast=updraft|stormfall`
- [x] Air string visuals: the Updraft's column carries his element up in a spiral, a spinning gale stays under his feet while he's up (blows apart as he leaves it), Gale Waltz rakes wind blades down onto the floor, and Stormfall falls as a comet and lands with a shockwave dome (`air_gust.gd`, `breaker_quake.shockwave`)
- [x] Elements in the breakers: the war cry's floor answers in his element, breaker dives come down as element comets, crater cracks vent the element (embers, frost, sparks, wisps), and Gale Waltz ends on a big crossed X blade
- [x] Ascended heavies: every heavy lays down the element and the next heavy sets it off: earth wells up lava that erupts in geysers (Magma Burst), wind charges foes for a chained thunderclap, water soaks them for a flash freeze its own blows shatter; breaker landings set everything off
- [x] Training dummy is heavier in the air: launches lift it about half as high and it never rises past 3 m, so long strings no longer juggle it out of reach
- [x] Wiki on GitHub Pages: https://zakpruitt.github.io/no-name-game/ (a workflow deploys `docs/wiki/` on every push to dev that touches it)
- [ ] Hand play-test: breaker windows and dive speeds, the timing circle's spacing (`breaker_prompt.OFFSET`), the air dash / homing / height cap, Flurry's afterimages (windowed only)
- [ ] The autotest bot rarely uses L H H or the air string (bot routes live in `main.gd`), so they're covered only by the PASS/FAIL tests

## Round 26 (comic art style)
- [x] Comic style behind `--comic` (default off, `docs/features/comic-style.md`): cut-tone toon and flat emit shaders, thick ink, hard indigo lighting, comic hero, all 9 enemy types and 25 dungeon pieces, each falling back to KayKit if missing
- [x] Comic words on hits by combo tier, in Bangers (OFL). The panel cut-in was built and removed after a play-test: its black bars got in the way
- [x] `--comic-moves`: the hero's hand-keyed `Ab_` clips, retimed from `MOVES`
- [x] Blender sources kept in `tools/comic_art/`
- [x] First play-test fixes: floor stones facing down (checker pattern), hero buried in ink (hull 5.5 -> 2 px, pushed back, inner ink halved, no self-shadow), walls solid black (fill raised)
- [x] Second play-test: mouse aim with limited turning through combos, four-direction run in place of the retargeted crab walk, softer lines and shadow texture
- [x] Natural carries: hand-keyed idle, guard, fidgets, charge, hit, dash and jump, runs without the hero-pose arms; the element on both axes
- [x] Both axes huge and dragged on the floor, each leaving a fading mark in the element
- [ ] Confirm those fixes on screen and run `tests/comic_shots.gd` (windowed): the fixes are checked on the meshes, not yet seen rendered. Fix what it shows before landing
- [ ] Hand play-test under `--comic`: the moves felt good on first play. With `--comic-moves`, still judge Spike, Charged Slam and Cataclysm hit 2-3x later, so judge the feel
- [ ] Cut the hero from 67k tris to 20-30k, rescale him (2.45 m against KayKit's 2.18 m), measure dash afterimage cost
- [ ] Restore under the flag: Awakened eyes, element axe coats, Ascendancy gear placement; port spirit casts off the KayKit models
- [ ] Port the Blender comic effects (bursts, ghost axes, smears) into the game's casts
- [x] Foot skate at game speeds on warrior, rogue and maybe bomber; watch the generic `Hit_B` and `Lie_StandUp` on minion, shield, bomber, necromancer (round 38)
- [ ] Comic pass on HUD, menus and power icons

## Round 27 (combat feel loop)
- [x] Hitstop with shape (`docs/features/impact-feedback.md`): a freeze holds then eases back over its last 30% (`HITSTOP_EASE`, ease-out curve 0.45), slow motion over its last 45% (`SLOWMO_EASE`), a string's first hit freezes 80% as long (`HITSTOP_OPENER`), breaker focus stays flat, and overlapping stops each keep their shape with the slowest winning. `tests/hitstop_check.gd`
- [x] Camera hit feel: every hit pushes the camera in 1.2% (x2.5 past the third chain tier, capped at 6%), heavy hits (shake >= 0.3) roll it up to 2.5 degrees alternating sides, and kicks/push-in/roll chase spring targets so stacked hits don't jitter (`camera_rig.hit_zoom`/`roll`). `tests/camera_feel_check.gd`
- [x] Comic impact frame (`scripts/impact_frame.gd`): stops of 0.1 s+ and kills flip the view into a negative with a vignette for 50 ms then fade over 90 ms (0.45 strength for enders, full at 0.25 s stops, 0.4 on kills, at most one per 240 ms); reduce flashing keeps a soft vignette pulse only. `tests/impact_frame_check.gd`, `tests/impact_preview.gd`
- [x] Weapon trail swells with the chain (+10% reach per tier) and the hit's weight (+25% right after a 0.12 s+ freeze, fading over 0.25 s), with a fuller crescent and longer life. `tests/trail_check.gd`, `tests/trail_preview.gd -- --swell`
- [ ] Hand play-test the feel numbers (ease curve, roll, impact frame strength, swell): all judged headless or from stills
- [x] fx.gd: one `Fx.unshaded_mat()` for the nine unshaded alpha material setups and `_label()` for the floating numbers; constants gathered at the top (refactor, no numbers changed)
- [x] spirit casts: `spirit_echo.strike()` replaces the six copies of hit / register / debris / hook and `fade_ghosts()` the four per-cast fades; `cast_dump` for all eight kinds unchanged on every cast triangle
- [x] projectile halo on the shared material, typed loops in weapon_trail / air_gust
- [x] `docs/cleanup-audit.md`: every script, test, tool and feature doc classified KEEP / TANGLED / DROP / OLD HERO against the heretic hero + training target, the seams in player / main / game / hud / elements / element_rite / ascendancy, and a 10-step ordered deletion plan (about 9 000 of 20 700 script lines) with two open questions (Awakening, Ascendancy). No deletions
- [x] Enemy hit reactions in one place (`enemy._hit_reaction`, docs/features/enemy-hit-reactions.md): squash per hit kind (`SQUASH` tap 0.87 / big 0.70 / launch 1.45 / juggle 0.84 / kill 0.60), a lean along the knockback (0.2 rad, 0.42 on big hits, held through the freeze), the flash in the hero's colour (`Fx.flash_tint`), and a kill holds the corpse 0.14 s. `tests/enemy_feel_check.gd`
- [x] Juggle feel: gravity drops to 55% while |vy| < 2 m/s so a 9 m/s launch spends 34 frames within 0.3 m of its apex (25 before), the foe tumbles over backwards (~5 rad on a big launch), bounces once off the floor (0.48 m) and skates on, then slides out in dust (1.8 m/s skid) before getting up; `launch_speed_for()` keeps the training dummy's 3 m cap exact
- [x] Crowd hits read as a wave: of the foes hit in one physics frame, each after the first reacts `WAVE_STEP` (35 ms) later (freeze, flash, squash and knockback start), up to 6 steps
- [x] Windowed look at the reactions: `tests/enemy_feel_preview.gd` → `user://enemy_feel.png`
- [x] Hit direction: an airborne hit launching 7+ m/s re-launches with the launch stretch (1.45); a downward hit (launch < 0 or knockback.y < 0) drives the foe down at 24 m/s, and any touchdown past 15 m/s (also Spike's) craters instead of bouncing: pancake 0.32 held 0.12 s, a 1.6 m dark dent (`Fx.crater`), lying 0.7 s and skidding 2.6 m (a plain landing 0.25 m); grounded, it craters on the spot. Side launches roll (rotation.z, 5.2 rad) instead of backflipping
- [x] Punching-bag training dummy: hits snap it over 1.8x a skeleton's lean (tap 0.36 rad), an angular spring (190 rad/s² per rad, damping 5/s) swings it 0.20 rad back past upright and settles it in 113 frames; squashes 1.6x; it boings 0.32 rad on getting up; refilling, it shakes off a daze (three side kicks, a stretch) under inked `Fx.daze` stars. LAUNCH_SCALE, MAX_HEIGHT and refill unchanged
- [x] Each foe owns its outline (`Fx.outline_own`); big hits swell it 2.0x (spike 2.4, crater 2.6, kill 2.8) and ease back over 0.28 s. Windowed autotest `[perf]` flat: avg 5.6 ms, draw calls 961 (987 before)
- [x] Air kills spin down at 1.8x TUMBLE_BIG (3.5 rad before touchdown) and settle on a full turn; a crowd killed by one blow pops its deaths `WAVE_STEP` apart. `tests/enemy_feel_check.gd`, `tests/enemy_feel_preview.gd [-- --bag]`
- [x] Void scripts pass the downward flag: ice Deep Freeze, magma Meteor Fall (the seized foe) and dark Maw hit with `Vector3.DOWN * 6` (`void_element.DEEP_FREEZE_DOWN` / `METEOR_DOWN` / `MAW_DOWN`) and crater the foe (squash 0.32). Maw stays quiet (`burn_hit` / `dark_fx.quiet_hit` take a knockback; a spiking quiet hit gets the reaction, still no sparks or word). A slam's kill pops up, not into the floor
- [x] The Warden's reduced reactions (`boss._boss_reaction`): every hit flashes in the hero's colour, big hits swell its ink 1.6x and squash it 0.90; no lean, tumble or lift (super armour)
- [x] Training dummy for long sessions: the bag spring is hand-tunable live (`--bag-damping=`, `--bag-stiffness=`, `--bag-lean=`, `--bag-squash=`; damping 5 is still after 113 frames, 7 after 86), a hit cuts a dazed shake-off short (no more kicks, stars gone), and each dummy carries a Bangers `LAST n` tag of the damage it took in the last string (dims when the next starts)
- [x] `--spar=minion|rogue|shield|warrior` (`scripts/spar.gd`): one live foe in the training room at 1/3 damage, back 1.5 s after it dies; the autotest prints `[spar] type= hits_taken= kills=`. Off by default. Look: `tests/enemy_feel_preview.gd -- --slams`

## Round 28 (strip to the heretic)
Zak: "reduce the game to JUST the heretic combat system for now. Remove the roguelike layer, keep the training ground." Decisions made while he was away, each open to veto:
- [x] The game boots straight into the training room: no title screen, no runs, rooms, doors, waves, map, rewards, camp, shrine, vault, altar, records or run summary. Settings live on the pause menu
- [x] Foes stay as code and data (`enemy.gd`, `boss.gd`, `scripts/enemy_types.gd`, `main._spawn()` / `_spawn_boss()`), but nothing spawns them outside tests for now. Necromancer raising, elite twists and bone drops went with the run
- [x] The training room keeps the first layout's four pillars (R swings on them) and drops the spike traps
- [x] The autotest boots training, lets the bot play the dummies for 16 s and prints `[autotest] done ...`; `--seed`, `--tour`, `--pace` and the room / twist / altar / camp flags are gone
- [x] Powers (combo-slot upgrades), their paths, masteries, synergies, icons, reward cards and the training room's "Pick a power" are gone, with every hook in `player.gd`. The Awakening burst keeps its old default numbers (`AWAKEN_BURST_RADIUS`, `AWAKEN_BURST_DAMAGE`)
- [x] The Ascendancy goes (decision b): no hero levels, XP or bones, no ascend menu, aura, element rites or Awakened path passives / finishers. The hero's own element stays spirit (`player.element()`); each void move takes its element from the weapon it forms (`VOID_ELEMENT.ELEMENT_OF`). Awakening is gold (`player.AWAKEN_COLOR`). What the void moves used from the old files moved: `scripts/foes.gd` (`FOES.near()`, was `Ascendancy.enemies_near`; preloaded, no class_name), and `elements.gd` (`well`/`Well`, `arc`, `geyser`)
- [x] The heretic is the only hero (`ComicLook.HERETIC`, always): the KayKit Barbarian hero, `hero_look.gd` and its kit, the shaman comic model, the old `route()` and its moves (H, LH, LHH, LLH, CH, DH, LPL, AL2/AH/AL3, AF and their combos), the player's own BREAKERS and breaker spikes, the gale (`air_gust.gd`, one helper moved into `player._comet()`), fire wave, and the spirit casts he can't reach (cleave, avatar, crown, rift, wheel, guillotine) are gone. He routes only through `void_route()`; breakers only through `VOID_ELEMENT.BREAKERS`. Barbarian.glb stays: the spirit echo / tomahawk ghost its `1H_Axe`
- [x] Awakening stays as the meter, the activation buff (damage, armour 0.6, gold rim, charged axe coats) and the burst (decision a). Ultimates, the ultimate banner, Cataclysm and Trinity go
- [x] Void element moves keep their exact behaviour (decision d): Avalanche and the rest of `void_element.gd` are untouched apart from `FOES.near` / `ELEMENTS.` renames and the no-op `_cast_hit` hook going
- [x] Comic style is always on (`Game.comic_style` stays true as the flag the art code reads; enemies still fall back to KayKit per model). `--comic`, `--heretic`, `--comic-moves` / `--no-comic-moves` and the settings toggle are gone, and `settings.cfg`'s old `comic_style` key is ignored
- [x] The autotest bot plays void strings (`main.BOT_STRINGS`: L/H/dash/hold) into every breaker and prints `casts= breakers= perfect_breakers= moves=`
- [x] Leftovers found dead after the strip and removed: `air_gust.gd` (only the dive's comet trail was live, now `player._comet()`), the no-op `_cast_hit` hook and its 21 calls, `spirit_echo`'s Ascendancy `FORMS`, `spirit_tomahawk.shared`, the cast `fan`, the guide's ultimate glow, the non-tentacle breaker branches, `HERO_FORMS`' old-arm meshes, the air-dash "AD" route
- [x] Docs and tooling follow: CLAUDE.md, README, feature docs (powers, run map and element rites gone; combo breakers, spirit casts, combo guide, training, comic style rewritten for the heretic), the `headless-render` skill (its `cast_dump` / `hero_dump` / `render_hero.py` went), the other skills, `.vscode` and the `agent.sh` test list
- [ ] Re-measure `ComicLook.HERO_MOVES` hit frames on the heretic's own `Ab_` clips: `frames` / `hit` are still the shaman's 24 fps counts (`comic_check` now only checks the hit is inside the clip)

## Round 29 (assets)
- [x] Audit of the heretic GLB: 15.9k tris body (17.1k with weapons), one 2048 texture, 101 bones, 1.95 m against KayKit's 2.18 m; at the game camera the mane dominated, the tentacle read as a thin clump and the paint broke into speckle under the cut tones
- [x] Refined it without touching the rig (`tools/meshy_rig/heretic_refine.py`, `flatten_texture.py`): flat colour regions, tentacle thickened 2 cm, head 1.22x and left fist 1.3x, baked at 2.2 m, `PAINTED.brush` 0.12. Seen in windowed stills only
- [x] Meshy: 60 credits spent (cap 60): a realistic A-pose candidate (30, came out with no tentacle arm and a floor-length cape) and a chibi candidate (30, right proportions, broken patchwork texture). Neither used; both kept in `vendor_src/meshy/source/`
- [x] `docs/features/art-direction.md`: "chibi but badass", from Zak
- [x] Chibi base: decimated to 22k tris and mirrored (`chibi_decimate.py`), retextured (10 credits) and auto-rigged (5) through Meshy's REST API, rebuilt with `heretic_rig.py ... chibi` (six claws, Meshy's arm to the wrist), claws repainted magenta (`chibi_paint.py`), baked at 1.75 m with weapons x0.7: `assets/comic/heretic_chibi.glb`. Meshy: 15 credits this round (balance 1067 -> 1052)
- [x] Selectable: `--hero=chibi`, or Settings "Hero model (next run)" (Heretic / Chibi heretic); default unchanged. heretic_shots, comic_check, training_check, void_arm_check and the autotest pass with either. Seen in windowed stills only
- [x] Orchestrator decision (Zak can veto: `Game.HERO_DEFAULT` in game.gd): **the chibi is the default hero**; `--hero=heretic` or Settings plays round 28's model
- [x] Chibi second pass, no Meshy credits: claw hand and claws grown 1.5x about the wrist with their bones (`heretic_refine.py` `claw_scale`; 1.3/1.4/1.5 compared at the game camera), baked at 1.85 m (was 1.75, weapons still x0.7), chin and nose under the hood painted into shadow (`chibi_face.py`), glowing cyan eyes drawn over the hood's brim while he faces the camera (`heretic_rig.gd` `EYES`), the change star moved up the haft off the hood (`STAR_OFF_HAND` 1.5), and a claw grip on GR (splay, snap shut on the hit) and VS (clenched and shaking, flung open on the slam) (`GRIP_MOVES`). 21,999 tris, 89 bones. Seen in windowed stills only, not played
- [ ] Zak: play the chibi; keep it as the default or flip `Game.HERO_DEFAULT` back to "heretic"
- [ ] Chibi: the spear change's star still touches the hood from the game camera
- [x] Chibi eyes: each eye hides while the claw or a weapon passes between it and the camera (`heretic_rig._covered`), so they stay over the hood but go behind a lifted claw (VS, Updraft Lash, the leap)
- [ ] Hand play-test of the refined heretic: does 2.2 m and the bigger head feel right in motion
- [x] Chibi animation: L1, AL1, L2, L3, DL, GR, VS, Idle, Idle_Ready and Run_F hand-keyed on his own rig (`tools/meshy_rig/chibi_keys.py`: IK poses, on twos at play speed, anticipation squash, one smear drawing, held contact, swollen claw on reaches), claw splay/clench keys on every other clip; lengths and every HERO_MOVES contact frame unchanged (L1 11/31, L2 12/33, L3 24/56, DL 12/61, AL1 11/30). `heretic_rig.gd` follows keyed claws and arms (`keyed`, `KEYED_ARM`, `KEYED_COLLAPSED`); `heretic_shots -- --clips` films every clip from the game camera. Seen in windowed stills only, not played
- [x] Chibi animation, second pass: Ab_LH (Updraft Lash: raked low under them, heaved overhead with the hop), Ab_H (Reap: a splayed claw crescent), Ab_LLH (Harpoon / Frost Spear: up on his toes, spear driven into the floor ahead), Ab_AF (Molten Palm: clenched fist shaking at the hip, shoved out as a huge open palm), Hit_A (big squash flinch), Dodge_Forward (squash, streak, snap back), Run_B, Strafe_L/R (Run_F's footfalls), Jump_Start / Jump_Idle (the breaker leap) keyed; lengths unchanged, contacts on each move's hit (EC 14/51, VR 15/63, EF/IP 20/59, EM 50/99), HERO_MOVES unchanged
- [x] Chibi GLB 4.07 MB -> 2.96 MB with the extra clips: claw keys only on drawings (STEP), keyed body tracks two keys per drawing, no claw tracks on the 27 clips the game never plays; squashes widen the hood, runs sway over the planted foot, the idle holds the claw out and slowly flexes it. Seen in windowed stills only, not played
- [ ] Chibi: play the keyed clips and judge the on-twos stepping in motion; the fidgets and 2H_Melee_Idle are still the shaman's (Death_A and Ab_Swing keyed in round 35 c)
- [x] Foe audit beside the chibi hero (windowed `tests/foe_shots.gd`, `enemy_lineup.gd`): the foes were realistic skeletons (small skulls, long thin legs) and the dummies plain KayKit skeletons with no ink, so the room read as two art styles. Line width was already equal (`COMIC_INK_PX` 1.6); foe shadows were warm deep brown against his cool lilac
- [x] Chibi proportion pass on all nine foes, no Meshy credits: `tools/comic_art/chibi_pass.py` (head 1.5x, hands and weapons 1.35x, legs 0.62 long and 1.28 thick, squat torso; same bones, weights and clips, hips keys rescaled, the archer's arrow re-aimed). Tri counts unchanged (5.5k-19.8k)
- [x] The training dummy is a comic punching-bag character (`tools/comic_art/enemy_dummy.py`, `assets/comic/dummy.glb`, 9.8k tris): googly eyes that squeeze shut on hits, a `Dazed` clip with spinning pupils for the shake-off, same collision and bag spring
- [x] Foe shadows step towards the hero's lilac (`ComicLook.FOE_SHADE_MATCH` 0.5, `foe_shadow`). Seen in windowed stills only, not played
- [x] Foes in thick masses: `tools/comic_art/chunk_pass.py` voxel-unions each skeleton's bone parts per limb group (head, jaw, torso, arms, hands, legs; held props untouched), weights back from the original, so the outline sits on the silhouette, not every rib. All nine foes, 7.8k-12.3k tris (Warden 22.3k), no Meshy credits. Seen in windowed stills (foe_shots, enemy_feel_preview), not played
- [x] Health bars per kind: `bar_height` in `enemy_types.gd` (head top + 0.3 m; rogue 1.55, necromancer 2.8, bomber 2.3 to clear its bomb), read by `enemy_bars.bar_height()`
- [x] Foe shadows `FOE_SHADE_MATCH` 0.5 -> 0.8, judged side-lit (`foe_shots.gd -- --side`)
- [x] Run strides measured (`tests/foe_stride_check.gd`, in `agent.sh check`): planted feet were 1.2-30x slower than the move speed. Wider strides on rogue / warrior / shield / bomber, the shield's walk re-keyed, and `enemy.gd` plays the run at ground speed over `run_foot_speed` (`RUN_CLIP_SPEED_MIN/MAX` 0.5 / 3.0)
- [x] Spar foes (minion, rogue, shield, warrior) squeeze their eyes shut on Hit_A / Hit_B and in Death_A (keyed `eye.l` / `eye.r` scale). Seen in a Blender still only
- [ ] Zak: play `--spar=minion|rogue|shield|warrior` and judge the masses, the fast chibi runs (clip up to 3x) and the hit squint in motion
- [x] The minion's shamble swings its feet low both ways, so its forward swing still slides; a re-keyed run with a lifted swing would fix it (round 38)
- [x] Eye squeeze for the other five foes; a launch / tumble doesn't shut the eyes (only Hit_A / Hit_B / Death_A do) (round 38)

## Round 29 (heretic effects)
- [x] Storm: Live Wire's arcs and Grounded's sky strike are fat flat inked zigzag bolts on twos with a hot impact star (`comic_bolt.gd`). Sheet before: thin glowing tubes and a soft green funnel burying the foes; after: bold green-and-ink bolts that clear by +0.2 s and leave the foes visible
- [x] Ice: the Frost Spear's frost is inked cracks, ice teeth and plates over bare floor (`frost_spear.frost_mesh()`). Before: a 12 m grey-blue slab that washed out the next two moves' frames; after: the floor and foes read through it
- [x] Magma: geysers are flat overshooting lava columns with inked blobs (`comic_geyser.gd`). Before: Meteor Fall was a soup of soft swirl cones and orange dot rain hiding every foe; after: five bold tongues with the foes between them
- [x] Dark: Singularity's hole is churning ink 2.6 m wide, and Collapse a held-frame ink splat. Before: a 1.3 m disc hidden under the pile, so it was just violet hoops; after: a black pool round the pile
- [x] Ice: comic ice spikes are flat two-tone with the ink hull, chunkier and overshooting, and `nova()` uses hard hoops (comic style only). Before: Cold Front sat in a soft blue glow; after: crisp crystals
- [x] Storm: Updraft Lash's gale is fat inked wind bands spinning in held frames (`comic_gale.gd`, comic style only). Before: a soft green disc over the foes; after: a cartoon whirlwind
- [x] Every comic hit: inked impact stars, fat speed strokes along the blow and two-tone element chips (`comic_pop.gd` behind `Fx.hit_spark`/`impact`/`chain_spark`/`element_hit`/`combo_pop`/`death`/`shards`); `Fx.dust` draws nothing. Before: an orange glowing flare and gold dot rain on every foe; after: hard stars that clear in 0.25 s
- [x] Breakers: the dive is a fat inked comet with a held landing star (`comic_comet.gd`), the cue and war-cry rings are crisp inked bands. Before: a big soft orange/green disc under the foes; after: hard rings and a readable streak
- [x] Molten Palm's fist is flat and inked with molten knuckles (`comic_fist.gd`, one-line hook in `void_element._fist`); Abyss's spikes are flat violet, bigger and 0.12 s later (`dark_fx.Spout`); Undertow's smoke went with `Fx.dust`. Before: a lumpy magenta ball and black cones lost on the dark floor under the impact frame
- [x] Words: signature moves and breakers say their own word (`ComicFx.MOVE_WORDS`/`BREAKER_WORDS`), and every word goes beside the hero clear of the foe pile (`_place`)
- [x] Damage numbers: one inked Bangers number per foe (`comic_number.gd`), hits inside 0.32 s add in and pop it again, drifting away from the pile; big hits are larger, hot yellow in an orange and ink outline. Before: a cloud of white/yellow numbers over the Tow Line pile; after: four chunky totals beside it
- [x] Hit flash: a comic foe's own ink flashes paper then the hero's colour (`Fx.flash_tint`/`flash`) instead of a pale overlay. Before: the "afterimages" in the hang were zapped foes washed into soft cyan and white blobs; after: the foes keep their tones. Comic afterimages are a flat colour step then an ink step, on twos
- [x] Bursts and scorches: `Fx.burst` throws a few two-tone chips (no smoke, no dots) and `Fx.scorch` is an inked crack splat (`comic_crack.gd`). Before: an orange haze under Molten Palm's line; after: a hard orange crack star that cools darker
- [x] Dark ink bursts (`dark_fx.Splat`) are inked violet tentacles with a hot core, tapering in segments and curling. Before: four flat black slabs over the towed pile; after: tentacles lashing round it
- [x] Words also keep clear of the combo-name callout and the breaker prompt; Abyss spikes keep 2 m apart, at most 3 (two over the four-foe pile, was four)
- [x] Round 4: the void tentacle (`void_tendril.gd`: grabs, Harpoon, Tow Line ropes, the R swing) is a flat inked ribbon in the splat's layers (ink edge, violet body, hot core), 0.52 m wide at the hand tapering in four segments, a 5% sag and its whip on twos; `element_shots` films `<combo>_rope` the third frame one is out
- [x] "Parameter material is null" fixed at its cause: a mesh freed with `Fx.flash`'s overlay still on (a foe freed a frame after a hit). `Fx._overlay` clears it on the root's `tree_exiting`, and the comic ink flash stops if the foe goes mid-flash; `tests/fx_free_check.gd` frees hit minions and dummies 0-3 frames later and fails on any logged error (30 before, 0 after), in `agent.sh check`
- [x] Readability over the pile: damage numbers step off the combo-name callout and its PERFECT line, live words and the breaker prompt (`ComicNumber.dodge` on `ComicFx.text_blocks()`); the "cyan glass" in the ice frames was Dash Stab's spirit tomahawk (60% rim-lit, stacked faces) and is now a 30% flat inked axe with a depth pre-pass; the cubes and frozen foes are flat two-tone ice with the foe showing; the Live Wire hoop was the breaker cue: its bands 0.24 / 0.16 / 0.07 -> 0.15 / 0.12 / 0.055 m, the war cry hoop 0.2 -> 0.08 m, and a nova keeps one thin hoop
- [x] Camera: the impact frame's vignette leans with the last heavy blow (`Game.last_hit_dir` from `camera_rig.kick`, `DIR_SHIFT` 0.2 of the screen) and its ink takes a dark tone of his element; enders, freezes that fire the frame and kills punch the FOV 1.5-2.5 deg (cap 5) on top of the push-in. `camera_feel_check` / `impact_frame_check` cover both
- [x] Effect perf: `comic_pop` pools finished pops out of the tree (`POOL_MAX` 48; spawn 15-30% cheaper, 0.04-0.18 ms), the comic drawers and dark_fx `preload` themselves / heretic_form_fx instead of `load()` at fire time, dark_fx caches its hoop and disc meshes, and `warmup_shaders.gd` holds the rope, cube and tomahawk materials (3 new, 28). Windowed autotest cpu worst 8.9 ms (base) / 9.3 (before this, an EA compile spike) -> 8.0 ms, cpu avg 1.3-1.4, 1 cpu spike (EV)
- [ ] Next: the Live Wire's comic_gale coil and the breaker cue still read loud in the storm frames; Dash Stab's spirit tomahawk is a shaman leftover on the heretic (worth a real heretic look or dropping); the damage numbers dodge text but not each other
- [x] Round 5 (feel audit 2026-11-04): impact frame on slams and kills only, one word per beat at the blow, a closer camera that follows his hangs with a paper rim on him, and the Awakened swoosh inked and trail capped (see Round 32)

## Round 30 (combo rhythm)
- [x] Hits on the contact pose: `ComicLook.HERO_MOVES` held the shaman's 24 fps counts; his clips are those keys at 30 fps with a hold frame first, so every hit came 27-54 ms of clip time early. Now his own 30 fps contact frames (last frame the weapon hand moves at 40% of its peak): L1 11/31, L2 12/33, L3 24/56, DL 12/61, AL1 11/30, the same on the chibi. `tests/contact_frames.gd` re-measures any model; `comic_check` fails on a mismatch
- [x] Input feel: `BUFFER_MS` 300 (was 0.25 s), hit-confirm `CANCEL_ON_HIT` 0.5 (L1 hands over to L2 at 234 ms on a hit vs 267 ms on a whiff; L3 545 vs 620 before pacing), `DASH_CANCEL_WHIFF`, and mouse aim holds the move's foe within `AIM_LOCK_BREAK` 40 deg. Dash out after hit 1 works on 42/42 moves (whiff and on a foe)
- [x] String pacing: wind-ups 216 / 235 / 471 ms -> 196 / 235 / 362 ms (`L1_SPEED` 1.1, `L3_SPEED` 1.3), recoveries 214 / 225 / 330 ms; Molten Palm 619 -> 471 ms (`EM_SPEED` 2.1). Bot beats for L L L H: L1 201, L2 297, L3 414, EM 636 ms after the previous hit (was L3 ~550, EM ~720)
- [x] Breakers: one window rhythm from the top of the rise (`BREAKER_HANG` 0.1, `BREAKER_TO_SWEET` 0.14, `BREAKER_TO_CLOSE` 0.32; Meteor Fall opened 0.02 s after its rise, now 0.1); `BREAKER_EARLY` 0.08 -> 0.12, so a press 100 ms early is held
- [x] Autotest plays all 13 bot strings (`strings=13/13`, ~31 s) and prints `[rhythm]` per string; a lone L L H left the frost spear up and sent H H / L H H up it, so Collapse and Grounded never played. `tests/rhythm_check.gd` added to `agent.sh check`
- [ ] Next: judge the new L3 / Molten Palm speeds and the hit-confirm by hand; breaker count still varies 5-7 between autotest runs (foe placement); the void moves' raw `MOVES` hits (GR 0.24 vs its clip's contact 0.32, VS 0.39 vs 0.41) were left as tuned
- [x] Round 2: the tentacle moves hit on the chibi's keyed contact (`void_element.gd` `GR_HIT` 7/31 = the claw snap, `VS_HIT` 17/46 = the slam, `LH_HIT` 14/51, `H_HIT` 15/63, `LLH_HIT` 20/59, `AF_HIT` 50/99), cancel / end / leap keeping their time after the hit: GR / EE / EW / EA / EV / VD hit 146 -> 137 ms, TW 122 -> 114, VS / OW 352 -> 333, EC 242 -> 229, VR 247 -> 245, EF / IP 328 -> 327, EM 471 -> 467. Round 1's "GR 0.32 / VS 0.41" were the round-28 model's shaman clips. `tests/contact_frames.gd` measures the six clips (`VOID_CLIPS`; Ab_GR by its claw snap) and `comic_check` fails on 14 moves if one drifts (IJ, IS exempt)
- [x] Deterministic bot: before each string the dummies go back to their homes and the hero `BOT_SPOT` 2.0 m in front of the first one, facing it (after they stand again, at most `BOT_SETTLE_MAX` 2.5 s), and the bot presses `BOT_LEAD` 0.15 s before a cancel point (at the full `BUFFER_MS` an Awakened Updraft Lash's buffered L lapsed and L H L H lost Worldbreaker). Breakers were 5-7 a run; now `breakers=7/7 strings=13/13` on every run (two runs identical: max_combo 123, hits 234), and `agent.sh check` fails otherwise
- [x] Dash Stab's cast is the claw's lash (`scripts/claw_lash.gd`, `CASTS.DL` kind `lash`): the tentacle's inked ribbon whipped 8 m ahead and back, same damage (6 / 4), cut size, 0.3 / 0.32 s timing as the shaman's spirit tomahawk, which is gone (`spirit_tomahawk.gd`). `spirit_echo.gd` and Barbarian.glb stay: L1 / L2's echoes and the air dash cut still ghost its 1H_Axe, and comic_check times the old clips off it. rhythm_check: the lash cuts a foe 8 m ahead out and back for 6 + 4
- [ ] Next (round 2, not started; stopped for review): `STRING_RESET_MS` (~150) in `hero_input.gd`: a press buffered more than that before a named ender's cancel that would open a new string (L1 / GR) is dropped, so mashing L3 doesn't spill into L1; assert in rhythm_check (must fail without it)
- [ ] Next: dash out of a breaker hang keeps momentum: rhythm_check comparing its distance with a standing dash (`hero_leap._dash_out` zeroes velocity, then `_start_dash` sets dash speed: likely already equal, assert it)
- [ ] Next (feel-audit 4): the combo-name / breaker callout tweens (`player._combo_callout`, `hero_leap._callout`) on `set_ignore_time_scale(true)`, cut when a new string starts (from MOVE with the chain reset); hud `FOUND_HOLD` 2.5 -> ~1.5 s
- [ ] Next (feel-audit 9): Dash Stab carries him through a pile 2.2 m off (`DL` lunge 16, decay 3): brake the lunge near a foe ahead before the hit so the stab connects with its 0.07 freeze; give Harpoon's catch (`void_grab` pull) a hitstop
- [ ] Next (feel-audit 8): try `EM_SPEED` 1.8 (wind-up 467 -> ~545 ms); Zak judges by hand
- [ ] By hand: the void moves now hit 1-2 frames earlier on their keyed contact (GR 146 -> 137 ms, VS 352 -> 333 ms): does the grab's snap and the slam read sharper? The claw lash on Dash Stab replaces the tomahawk: does it read as his move at the game camera (no windowed look taken yet)?

## Round 31 (perf and cleanup)
- [x] The `[perf]` line measures cost, not the display: the wall avg sat at 16.4-16.5 ms because this machine caps at 60 fps even with vsync off (an empty project measures 16.67 ms), so it adds `cpu` (every node's process/physics work via `perf_probe.gd` + render submit), `gpu`, `cpu_spikes(>8ms)`, and spike lines with the move and pipeline compile counts. Baseline: cpu avg 1.4 ms, worst 38.6-39.7 ms, 13-14 cpu spikes, 12-13 wall spikes, wall worst 54.5-54.7 ms; GPU 0.6 ms
- [x] Dash afterimages skin on the GPU (`Fx.afterimage` shares the mesh with a frozen `Skeleton3D` pose) instead of `bake_mesh_from_current_skeleton_pose` (~18 ms per ghost on the heretic): the two 54 ms frames in every run are gone; same silhouette (`tests/fx_preview.gd -- --dash`)
- [x] `scripts/warmup.gd` keeps every script and built-in material shader alive: effects `load()` their scripts and build fresh StandardMaterial3Ds, and Godot freed the cached script / generated shader once the last user went, so each breaker, daze, freeze and awaken recompiled them (10-20 ms). 24 shader signatures in `warmup_shaders.gd`, refreshed with `-- --autotest --collect-shaders` (also on `tests/element_shots.gd`)
- [x] Final, over combo-rhythm's buffered bot prints (the run now plays all 13 strings, ~28 s, 7 breakers): wall avg 16.5 ms (the display cap), worst 24.7 / 25.0 / 25.9 ms, 0 / 0 / 1 wall spikes over 25 ms in ~1670 frames; cpu avg 1.3 ms, worst 8.1-10.4 ms, 1 cpu spike (Avalanche's EV breaker frame); gpu 0.6 ms
- [x] The autotest bot moved to `scripts/training_bot.gd` (main.gd 552 → 388 lines); the centre TRAINING banner that sat over the first strings is gone
- [x] Dead code and assets out: unused hints (dash/launch/breaker/shield/bomber/necro/cage), the Enter restart binding, `bone_cage.traps/ring_radius`, `spirit_echo.fade_ghosts`; six room props in both dungeon sets, the KayKit Knight, smoke_07 and four run sounds (1029 lines/binary entries)
- [ ] Next: the per-breaker effect build itself is 5-9 ms (comic_pop, geysers, craters each 1-2.5 ms): pool comic_pop nodes; `main._fade_occluders` walks the props' children every frame (cheap now, cache it if props grow)
- [x] player.gd split by job (1813 lines -> 1023 + four files, behaviour unchanged: rhythm_check's table identical, autotest within its run-to-run spread). Static functions over the hero's state, like void_element.gd; player.gd keeps a forwarder for every name other scripts and the checks call
- [x] `scripts/hero_moves.gd` (355 lines): `MOVES`, `COMBOS`, `MOVE_NAMES`, string pacing, `void_route()` / `routed()` / `chain_after()`, `progress()`, `effective_move()`, hop / plunge / landing slam, juggle homing, the air dash, the combo guide's rows
- [x] `scripts/hero_input.gd` (185 lines): the press buffer, `cancel_point()` and hit-confirm, `can_dash_cancel()` (one rule for its three uses), `combo_window()`, mouse aim, the soft lock and the mid-move steer
- [x] `scripts/hero_leap.gd` (369 lines): State.LEAP, the breaker press / dive / impact / callout / dash-out, the prompt feed, `BREAKER_*`
- [x] `scripts/hero_awaken.gd` (90 lines): activation and burst, the buff (its numbers named: `ANIM_MULT`, `DAMAGE_MULT`, `SIZE`, `SPEED_MULT`, `DAMAGE_TAKEN`), the drain, the rim
- [x] player.gd (1023 lines): declarations grouped by job, functions in sections; dead code gone (`spikes`, `callouts`, `last_callout_tier`, `_last_combo`, `heal()`, `_cast_target()`, the KayKit H / CH charge branch). `comic_check` scans `hero_*.gd` for clip names too
- [x] Cleanup round 2: casts / swoosh / callouts / ender camera / rank-up / last-kill moved to `scripts/hero_fx.gd` (player.gd 1062 -> 784 lines); every forwarder gone except `breaker_window()` (game scripts and checks call `HERO_*` directly); the death recap's `last_hit_by` / `_describe_attacker` / `take_hit` cause strings gone. Autotest breakers / strings / endings / moves / improv identical
- [x] Cleanup round 2: `tools/dead_refs.py` (names no code uses; comments don't count, docs-only names listed apart) found and removed 10 (`breaker_quake.eruption_line`, `enemy.chill_hits` / `fuse_left`, `fx_palette.TAIL_ALPHA`, six dead `void_element` consts)
- [ ] Cleanup round 2, not landed (branch `agent/cleanup2-style`): one-line comments on ~100 of today's tuning constants plus `comic_crack.LINE` = `PAL.LINE`, `comic_gale.STORM` / `LIGHT` = comic_bolt's, `comic_flat.FALL_GRAVITY`. Same values, yet on dev `4ec20ad` it moved the headless autotest's `[improv] buried_x_water` 1 -> 3 (twice; dev and the two commits before it give 1): find why (the new preloads in comic_crack / comic_gale changing load timing?) before landing
- [ ] Cleanup round 2 left: CLAUDE.md's Layout doesn't name ~30 of today's scripts and tests (the `comic_*` crossover effects, `callout_cap`, `standing_fx`, `hud_ink`, `fx_sleek_check`, `hero_stride_check`, `lean_spike_check`, `improv_shots`, `fx_coverage.py`, `dead_refs.py`); `docs/features/README.md` lists every doc. Duplicates owned by other lanes: `enemy.RUN_START_BELOW` / `RUN_STOP_ABOVE` = player's, `foe_lean.LEAN_*` = heretic_rig's

## Round 32 (feel audit fixes)
From `docs/feel-audit-2026-11-04.md`'s top 10 (numbers are the audit's).
- [x] 1. Impact frame only on breaker slams and kills: `IMPACT_STOP` 0.1 -> 0.3, `impact_frame` watches `breakers_landed` (`slam()`, 0.85 / perfect 1.0), `IMPACT_GAP_MS` 240 -> 900. Freeplay film: three flips in 10 s (the slams), was about one every 1.2 s
- [x] 2. One word per beat at the blow: a new word replaces the live one, no generic word twice in a row, placed round the contact point (`SPOT_RINGS` 12 / 55 px, `SPOT_ENOUGH` 24)
- [x] 3 / 10. Hero findable: camera (0, 10, 7.5) FOV 36, hang push-in `HANG_ZOOM` 0.12 and lift with his model (`LIFT_FOLLOW` 0.75), the combo guide on the side away from the pile, a paper rim on the hero over effects (`hero_rim.gdshader`), TRAINING / THIS STRING moved to bottom right
- [x] 5. (audit 5, brief item 4) Awakened gold, partial: swoosh inked to its outer band and the second ender arc dropped while Awakened, trail swell capped (`SWELL_MAX` 0.35, `AWAKEN_SWELL_MAX` 0.12, `AWAKEN_ALPHA` 0.6)
- [ ] 5. The flat gold axe over Awakened L2 / L3 is the spirit cast echo (`elements.CASTS` echo), not the swoosh: thin it or ink it while Awakened
- [ ] 6. One number per breaker: one total (or the biggest foe's) instead of four equal numbers, numbers dodge each other, `LAST n` only on the dummy hit most
- [ ] 7. Clear the floor between strings: Maw / Abyss pools, Meteor geysers, Undertow's crack and the frost disc fade when the next string's first hit lands (a Game signal on string start)
- [ ] 8. Molten Palm needs a palm: `comic_fist.gd` bigger than his head, knuckles forward
- [ ] 4 / 9. Callouts end with their string; Dash Stab and Harpoon land soft (combo-rhythm lane)

## Round 35 (hero locomotion)
Zak: "the movement animation is awful". The chibi's runs, idle and dash re-keyed in `tools/meshy_rig/chibi_keys.py` (Locomotion); attack clips and contact frames untouched, no game code changed. See `docs/features/heretic-hero.md` "Locomotion".
- [x] Feet locked to the floor: the runs skated 3.2x (strafes 7.7-9.7x) at 7.5 m/s; now 1.00 on all four (`tests/hero_stride_check.gd`, in `agent.sh check`). Planted foot slides `RUN_GROUND` 0.227 m a frame for 3 frames, legs and hips keyed every frame (a held foot rode forward with him and snapped back)
- [x] Run cycle 14 frames (0.424 s at 1.1): contact, down (body squashed 6%, hood +0.2), push-off on the toes, a long leap (stretched tall), 26 degree lean, hips turning and rolling over the planted foot, fist pumping, claw trailing splayed and counter-pumping; arms, head and hood on twos. Run_B and the strafes on the same cycle and phase
- [x] Seamless loops (keyed from frame 0: no held frame at the wrap)
- [x] Idle: hunched, the weight rolled from leg to leg once a loop (free heel lifts), two breaths through chest, hood and body, head tilting with the weight
- [x] Dash: one crouch drawing, a 48 degree streak stretched long with a knee tucked and a leg trailing, a skid landing
- [x] Run start (lunge, `Run_Start` 6 frames) and stop (skid, `Run_Stop` 8 frames): one-shots at the loop speed in `player._play_locomotion`, the lunge from below `RUN_START_BELOW` 0.3 of move speed into Run_F's first step, the skid on letting go above `RUN_STOP_ABOVE` 0.6 out of Run_F. Planted feet keyed against `player.accel` (0 to 7.5 m/s in 0.107 s); the skid braces a foot 0.32 m ahead, leans back, then the chest, head and hood pitch past upright and settle into Idle's first pose
- [x] Awakened runs: `player.AWAKENED_RUN_CLIP` (= `HERO_AWAKEN.SPEED_MULT` 1.2) plays the runs and the one-shots 1.32 instead of 1.1 while Awakened, set every frame in the run so it follows Awakening starting or ending mid-run; `hero_stride_check` fails on the Awakened skate too (was 1.20, now 1.00)
- [x] Turn lean (procedural, `heretic_rig._lean_into_turns`, no clip): the root bone tilts towards his velocity less a 0.12 s lagging copy, 3 degrees per m/s across his facing (0.45 of that along it), capped 15, on a spring a little under critical. Measured headless: 12 degrees banking on a 90 degree turn, 8 on a reversal, 2.5 back on a stop, 0 on a held run
- [x] Idle_Ready re-keyed on Idle's approach: 60 frames, wide and low, weight rolled from leg to leg once a loop, two breaths, claw held up in front of his face open and flexing, fist raised (was a 41-frame bounce)
- [x] Dash looked over: kept
- [x] Round 35 c: a start and a stop for each run (`Run_Start_B` / `_L` / `_R`, `Run_Stop_B` / `_L` / `_R`: backing hunched then leaning away, sideways banked into the travel, the skid braced on the leading foot out wide), and every stop again ending on the guard (`Run_Stop*_Ready`) while `_ready_t` says he fought in the last 3 s; `_play_locomotion` picks them by `RUN_SUFFIX`
- [x] Round 35 c: Death_A keyed (46 frames: flinch, woozy stagger, knees buckle, hood flops forward, face-plant with a bounce, the claw twitching and dissolving last) and Ab_Swing (41: crouched anticipation, claw flung up stretched, the yank past the hang as overshoot, then a tucked hang with a slow flex); both in `KEYED_ARM`
- [x] Round 35 c: attack readability from the game camera, contacts unmoved: a whole-body squash on the anticipation 2-4 frames before contact, a stretched smear with the claw / weapon swollen x1.3, an impact squash, then sinking on and springing up past rest (`chibi_keys.py` `PUNCH`), on L1 / AL1 / L2 / L3 / DL, the six tentacle clips and the breaker leap; the script's contact check counts the squash (`squashed`) and prints each clip's recovery margin
- [x] Round 35 c: the spear plant (Ab_LLH: Harpoon, Frost Spear) raised higher before the drive: the hand straight up over the hood (el 84, was 72), up on his toes further, the spear swollen and only -32 tip-down (a steeper one was tried at -72 and foreshortened to a stub from the game camera); contact still 20/59
- [ ] By hand: do the strafe / back one-shots read in play with mouse aim, and is the guard skid's 3 s (`READY_HOLD`) the right window?

## Round 36 (camera distance)
- [x] Zak: "zoom the camera out more, too close to the character". Rest camera 13 m (was 12.5) at FOV 37 (was 36), aimed `AIM_HEIGHT` 0.8 m up his body so the pile in front sits mid-screen instead of under the HUD: at 1080p the hero is 140 px (was 167; round 28 105) with +34% floor in frame. Fight framing: foes hit in the last 2.2 s pull the camera out up to x1.25 (~112 px) and lean it towards them, drifting back slowly. Kicks and shake scale with the distance, `PUNCH_GAIN` 1.25 on enders, `HANG_ZOOM` 0.12 -> 0.16. Flags `--cam-dist=` / `--cam-fov=` / `--cam-frame=` (`docs/features/camera.md`)
- [ ] By hand: is 13 m far enough? Try `--cam-dist=14` / `15` and `--cam-frame=1` (framing off) and say which
- [x] Camera round 2: Meteor Fall's beats (press to dive) pull the camera out past the framing cap, up to `frame_max` x `HANG_FRAME_GAIN` 1.6 (x2.0, 26 m, hero ~70 px), on foes hit within 22 m, leaning up to 5 m and undoing the hang push-in while they need the room; out at 12/s (90% in 0.19 s, before the throw hits the wall), back at 4/s on the dive (its punch-in kept). The rise and the timing window keep the push-in. Filmed (`string_film -- --from=11`): the beat-1 splats on the east wall and every thrown foe in frame (before: off the right edge). The rig's real delta is measured now (delta / time_scale snapped the dive's return home in a frame)
- [x] Camera round 2: `comic_shots`, `foe_shots`, `heretic_shots` shoot from `camera_rig.rest_view()` (the rig's offset and FOV, flags included) instead of round 28's (0, 13, 9.5) FOV 42
- [ ] By hand: is x2.0 too far for the beats (the hero ~70 px for ~0.6 s), or still too close (a throw to both side walls wants ~x3.5; the corner foe can sit at the edge)? `--cam-frame=` scales it
- [ ] The timing window before the press still pushes in on foes Undertow spread off screen (Meteor Fall's string): pull out there too, or leave the window tight? Tried in cleanup round 2 and not landed (stop-point): running the framing in the window and capping at `frame_max` also undid most of the push-in for a single foe 2 m ahead (x1.18, the head out of the 72% box), so the box test needs the hang's lift or a rest-distance test first; measure `_frame_to` per breaker in the window before choosing

## Round 33 (FX sleek)
Zak, after playing every combo: "very comicy, which I like, but ... sleeker and more put together. Right now it's very thick colours." Same comic language, less weight: `docs/features/comic-style.md` "Sleek effects".
- [x] One palette per element (`scripts/fx_palette.gd`): hit stars and chips take the blow's element (gold Awakened), so a string reads as one colour family
- [x] Trails: swoosh and weapon trail are a see-through gradient with one light line on the blade edge and a thin ink line (`body_alpha` 0.55 / 0.5; Awakened lines only / 0.18)
- [x] Impacts: one gradient star in a 0.035 m ink line (was three opaque stars in a 1.2x hull), thin speed lines with no ink, 60% of the chips, half-thick hoops, a second hoop on the same spot dropped
- [x] Element casts: bolts, gale, geysers, Molten Palm's fist and the frost disc thin-inked, see-through and with fewer shapes (gale 4 bands, geysers 3 blobs, frost 4 plates)
- [x] Breakers: thinner comet and landing star, thinner splats and spouts, half the ink drops; comic cracks at most 0.9 s, dark pools' ink at most 1.1 s
- [x] Words a quarter smaller with a thinner ink line, 14 frames (20); numbers smaller, 12 px ink (26), hold 0.38 s (0.5)
- [x] The Awakening column see-through and shorter; two daze stars (three)
- [ ] By hand: does the sleeker look still hit hard enough? Thin lines lean on the hitstop and the impact frame now
- [x] Round 2, at the 34% wider camera: round 1's lines, words and numbers still read at a 140 px hero (filmed, no width changed)
- [x] Round 2: the spirit echo's ghost axe, the spirit / void strike's sky column (`elements.comic_column`) and the comic earth spikes are a ~0.3 alpha halftone fill in a thin ink line with a light edge (`shaders/ghost_halftone.gdshader`, `ghost_ink.gdshader`, `spirit_echo.ghost_mat`), shorter-lived; breaker cue rings half as thick; spirit motes small inked beads
- [x] Round 2: one damage total per breaker landing (`comic_number.gd` `BREAKER_*`); standing effects (floor frost, dark pools, Reap's marks, cracks) fade on the next string's first hit (`scripts/standing_fx.gd`, watched from ComicFx: no new signal). Check: `tests/fx_sleek_check.gd`
- [x] Round 3: the echo axe's fill fades along the haft toward the hand (`ghost_halftone` `local_fade`), so it reads as a blade
- [x] Round 3: earth halftone as clean dots (no brown tint on the indigo floor, `spirit_echo.GHOST_TONES`); the earth strike and earth war cry hoops thin and inked (`Fx.thin_hoop`)
- [x] Round 3: ice spikes, ice cubes and the frost spear's floor in the halftone ghost look (`shaders/halftone_floor.gdshader` for the floor zone)
- [x] Round 3: an inked dust puff on run start, skid and dodge, with short skid marks (`scripts/comic_dust.gd`, watched from ComicFx, pooled)
- [x] Round 3: HUD in the same language (`scripts/hud_ink.gd`): counter and callout in the words' font with thin ink over a halftone panel; guide rows and breaker prompt see-through with halftone dots and thin lines
- [x] Round 4 (whole-game polish, every string filmed): `--collect-shaders` found nothing new (elements.prewarm already draws the halftone floor and ghost shaders); the HUD halftone costs ~0.2 ms GPU (median, HUD toggled every 20 frames under the bot); the announcements (AIRBORNE, PERFECT, GUARD BREAK) in the words' font and thin ink
- [x] Round 4: the combo / breaker name over the hero fades after 0.95 s real or when the next string starts (`scripts/callout_cap.gd`, watched from ComicFx): slow motion held FLASH FREEZE PERFECT 5 s, CATACLYSM / ABYSS 1-1.3 s into the next string
- [x] Round 4: announcements 44 px in the top fifth on real time (were 64 px mid-screen over the hero, AIRBORNE over Rockslide and Fault Line for 1.3 s)
- [x] Round 4: Cataclysm's sky bolts 0.15 m, 5.5 m tall, no fork, at most three (were five fat 8 m zigzags filling the push-in)
- [x] Round 4: a breaker-sized floor mark (Meteor Fall, the rip landing) runs its cracks out from the pile's edge with no hidden splat (`comic_crack` `PILE_*`)
- [x] Round 4: breaker craters are one inked mark with small inked star vents (`breaker_quake.crater`: no brown box cracks or rock slabs for 1.6 s, no soft flares); a foe's crater a 0.6 s inked dent (was soft soot discs for 1.4 s)
- [x] Round 4: one hit grammar: the same star size on foes and the Warden (`Fx.HIT_STAR` / `HIT_STAR_BIG`), words and numbers at one on-screen ink weight (`fx_palette.TEXT_INK_PX` 3 px; words were 3.4-8.3 px, numbers 2-3.3). Check: `fx_sleek_check`
- [x] Round 4: a breaker landing's floor mark is gone in 0.5 s (`comic_crack.PILE_TIME`; it cooled into a brown crater under the hero for 0.6-0.9 s); Meltdown's flame tongues lean out, lick side to side on twos and hook at the tip (`comic_melt` `FLAME_*`; three upright wedges read as candles)
- [ ] Round 4 follow-ups: Meteor Fall's landing is still five flame geysers plus the column over the pile (the cracks now reach out but the geysers carry it); the frost zone plus Deep Freeze's rings, ropes and cubes over a crowd; the spirit echo's 3 m halftone fans on L2 / L3 cover a third of the frame; Undertow's magma crack web stands about 2 s; burn ticks show a number with no star (by design, a tick)
- [x] Round 5 (density, measured: coverage = effect-coloured share of the middle 60% of each `string_film` HIT frame): Meteor Fall's landing three thin rim geysers, two spikes a foe (0.22 -> 0.17-0.19); Deep Freeze's cords one thin line, crater hoops and frost rings thin; the spirit echo's blade at 0.7 of its reach, its swoosh lines only (hit reach unchanged); Undertow's wells a 0.9 s crack mark (the pool lit the tile grout as a web for 4 s); quick fixes: Grounded's strikes 5 m / 0.15 m / no fork (0.40 -> 0.30-0.34), earth breakers' per-foe geyser thin, the Awakening column 0.42 wide
- [x] Round 5 densest left: Abyss (hold) landing 0.47: the dark tentacle splat and violet arms over the whole pile, plus the Awakening column
- [x] Round 5 densest left: Worldbreaker (L H L H) 0.35: per-foe rim geysers, Live Wire bolts and the big WORLDBREAKER PERFECT callout over the pile (the breaker-name callout over a pile is in most top frames)
- [x] Round 5 densest left: Cataclysm (L H L L H) 0.34: Live Wire's green bolts and stars on every foe on top of the cracks and sky bolts
- [x] Round 5 densest left: Grounded (L H H) 0.30-0.34: still five storm strikes plus a hit star per foe; cap the strikes at three, staggered (as comic_fault does)
- [x] Round 5 densest left: Maw (H L H) 0.31-0.40: the dark splat and a pink / violet hoop wall over the pile (Collapse, H H, 0.26-0.35, the same hoops)
- [x] Round 6 (sleek 6, same bot run before / after, strings mean 0.090 -> 0.075, densest 0.34 -> 0.25): Abyss one thin splat between the spouts and the Overwhelm pool eroded at the landing (0.26 -> 0.10); breaker names in the top band for 0.6 s real (`callout_cap`), the combo name stays over him; in a breaker one hit star a frame at the hits' middle and three Live Wire bolts at once, three rim geysers a batch (Worldbreaker 0.27 -> 0.25, Cataclysm 0.17 -> 0.16); Grounded three staggered strikes, one star (0.34 -> 0.22); Maw one row of short fangs, thin bite splat and hoop (0.34 -> 0.18), Collapse thin arcs and one hoop a beat (0.19 -> 0.17). Gate: `python tests/fx_coverage.py <film> --max=0.40`
- [ ] Round 6 densest left: Worldbreaker (L H L H) 0.25: three earth spikes a foe in cream and orange plus three rim geysers and the Awakening column; Grounded 0.22: the crater's green spark bursts and the column; the Awakening column is the biggest shape in most breaker HIT frames when the bot Awakens on the landing

## Round 34 (multi-element combos)
Zak: "more combos that utilize multiple elements together", "a few more complicated combos", and Meteor Fall's ending.
- [x] Rockslide (L H L L, storm into earth): the gale's air string slammed into the floor together, double on those in the air
- [x] Fault Line (L H L L H) and Cataclysm (H in the window, 6 presses): the gale back up out of the cracks, lightning in the hang, craters
- [x] Steam Burst (Dash L H H L, ice into magma) and Flash Freeze (H in the window, 6 presses): frozen foes go off in steam, then freeze and shatter again
- [x] Storm Pitch (Dash H L, dark into storm): the axe hurls Tow Line's bunch, lightning jumping off them in flight (`thrown_foe` `zap`)
- [x] Black Ice (H L H, L in the window, dark into ice): Maw's other ending freezes the pool and shatters it
- [x] Meteor Fall in three beats: thrown into the walls, dragged into one pile by the tentacles, the meteor into the pile (~1.1 s game time)
- [x] Bot plays all of them (17 strings, `breakers=9/9`, `endings=`); `string_film.gd -- --from=N`
- [x] Looks for the crossovers and the beats (round 37)
- [x] Beat 1 throws leave the frame in the middle of the room: a camera pull-out for Meteor Fall's hang (camera lane; Round 36, camera round 2)
- [x] Second pass, three elements a string: Hailstorm, Meltdown, Eruption (Dash L H H H L, H: ice, storm, magma, in the air); Impale, Backdraft, Anvil (L L H, Dash H H L, H: dark, ice, storm into the hammer)
- [x] Improvising: crossover states last `ELEMENT_HOLD` 2 s and every payoff reads the state, so a dash and the paying element cash it in (frozen into magma, buried into storm, airborne into dark)
- [x] Fault Line 1.5x (`XF_SPEED`): Rockslide's hit to Fault Line's 454 -> 403 ms; rhythm_check's hit-confirm is a mean of 4 runs (the 224 < 233 ms flake)
- [x] Film the second pass (`string_film.gd -- --from=17`, windowed): Meltdown met the cubes still rising past him (`HAIL_LAUNCH` 12 -> 9) and Backdraft's pull-back never showed before Anvil's leap (Anvil `reel`: the tentacles haul them in); looks stay with the fx lane (`TODO(fx lane)`)
- [x] Third pass, the element matrix (`docs/features/element-matrix.md`): state (frozen, buried, molten, skewered, airborne, bound) x element (storm, ice, magma, dark), 15 new cells paid by base moves through `void_element.improvise()`, move list IMPROVISING rows, three bot strings (`[improv] frozen_x_void=3, buried_x_water=1, airborne_x_water=1`), `void_arm_check._element_matrix()`
- [x] Fixes: range-0 moves skip `_do_hit`'s melee loop (a 0-damage touch broke a foe's ice); Rockslide's stop 0.1 -> 0.07 and hit-confirm 0.8 (Fault Line beat 393 -> ~320 ms); the bot's `line` setup so Harpoon reels three and Hailstorm lifts them all
- [x] Flow audit (bot `[rhythm]` beats vs 196 / 235 / 362 ms): Molten Palm / Steam Burst `EM_SPEED` 2.1 -> 2.8 (L3 -> EM 655 -> 549, EA -> XS 612 -> 515), Harpoon / Frost Spear `LLH_SPEED` 1.6 (DL -> EF 424-514 -> 350-432), Meltdown `MELT_SPEED` 1.5 (467 -> 413). Still long: Air Slash after Updraft Lash (344-372), L2 in the spear strings (325-333), Dash Stab after a dash out of a move (475-536)
- [x] (bot strings, round 4) Molten payoffs (dash out of Meltdown's hang), bound x storm off Undertow; the matrix's reach (5 m round him) against each move's own shape
- [x] Fourth pass, matrix reach: a payoff lands only inside the move's own hit shape (`void_element.improv_reach()`: the gale's circle, the harpoon / palm lines, the crescent, the pools, the tentacles, Tow Line's dash line; nothing for the vault); `_element_matrix()` adds foes behind him / off the line inside 5 m that must not pay (fails 5 ways on the old reach)
- [x] Fourth pass, beats (bot `[rhythm]`): Updraft Lash -> Air Slash 307-385 -> 232-295 ms (`AL1_SPEED` 1.25, `EC_CONFIRM` 0.8), L1 -> L2 311 -> 280-292 ms unawakened (`L2_SPEED` 1.15), a move -> Dash Stab off a dash 510-534 -> 444-449 ms (`DASH_STAB_CANCEL` 0.5 of a dash that cancelled a move)
- [x] Fourth pass, Anvil: the reel fans the kebab across his aim (`ANVIL_SPREAD` 1.5 m, kept through the dive), a crater each (was 0.08 m apart, one pile)
- [x] Fourth pass, bot: `face` / `out` / `wait` tokens and two strings (dash out of Meltdown / Undertow into Updraft Lash): `[improv] frozen_x_void=3, buried_x_water=1, airborne_x_water=1, molten_x_wind=3, bound_x_wind=1` (24 strings, `AUTOTEST_MAX` 100 s)
- [x] Fourth pass, guide: crossover rows say their element change ("storm > magma"), a row whose move would cash in a state in its reach says the payoff ("Harpoon + Frozen In"); the pause panel's MIX ELEMENTS page lists all 24 cells in plain words (`guide_check._mixing()`)
- [ ] By hand: Dash Stab at `DASH_STAB_CANCEL` 0.5 covers half the dash's ground before the lunge: check the spacing into a pile; the "+ payoff" tag's reach is read from where he faces before the press, so an aimed press can still pay where the tag didn't show
- [ ] The guide's mix / pay tags are plain text (a small element chip in the fx palette would read faster)

## Round 37 (Crossover FX)
The round 34 crossovers had placeholder looks (pillars, fissures, spikes, geysers, shards, arcs). Each now has its own flat comic drawer on `scripts/comic_flat.gd` (two surfaces on twos: camera-facing on heretic_form_fx's material, floor on comic_crack's; nothing new to compile). See `docs/features/void-element.md` "Crossover looks".
- [x] Rockslide: one inked boulder slams down on the hammer's spot (squashed over a hot star, splits into four chunks), a hot crack dent under each foe it drove down (`comic_boulder.gd`); word KRUNCH!
- [x] Fault Line: one glowing crack per foe runs out from him (nearest first, 0.06 s apart, on real time so the hit stop doesn't hold it) and the gale comes up where it arrives (`comic_fault.gd`); word SKRRRAK!
- [x] Cataclysm, less busy: was a strike + geyser + 5 spikes per foe and a hammer burst; now one fat crack per foe out of his landing with a sky bolt where each arrives, staggered; word KRAKA-DOOM!
- [x] Steam Burst: a nine-puff inked cumulus round each frozen foe and over its head, a magma star at its foot (`comic_steam.gd`); word PSSHHHH!
- [x] Flash Freeze: a see-through crystal shell climbs each held foe as he dives, with ice tips and a glint (`comic_freeze_over.gd` `foe()`); word FSSHINK!
- [x] Black Ice: the dark pool freezes over from the middle out (a two-ring mosaic of ice plates with ink between), and the landing breaks it into flying chips (`comic_freeze_over.gd` `pool()` / `shatter()`; was a frost ring, nova, splat, spikes and shards); word KLISSSH!
- [x] Storm Pitch: inked lightning forks crackle off each thrown foe for its flight with speed strokes behind it, thinner jolts to whoever it passes (`comic_arc.gd`); word ZZWANNG!
- [x] Meteor Fall: a flattened hot splat star where a beat-1 throw hits a wall (`comic_splat.gd` `watch()`), and DOGPILE! over the pile once beat 2 has them all in (`ComicFx.say()`)
- [x] Steam Burst rarely steams in the bot's string (fixed: a frozen foe in flight counts and is cut out of its roll): Ice Cube's cube is still flying (thrown) when XS fires, so `frozen` is empty and only the fist shoves (combo lane: let a flying cube count, or film it on a standing frozen foe)
- [x] Meteor Fall's wall splats are mostly off camera at 13 m (camera round 2: the hang framing, `camera_rig.HANG_FRAME_*`)
- [x] Second pass, the three-element strings: Hailstorm (a whirlwind riding each frozen foe up, hail round the cube: `comic_hail.gd`), Meltdown (a molten hammer crescent; ice off, burning down, a hot splat where each lands: `comic_melt.gd`), Eruption (the floor breaking up under each, nearest first: `comic_erupt.gd`), Impale (ice racing out of the spear, a stake through each: `comic_impale.gd`), Backdraft (a burst off the spear, wind ribbons hauling them back: `comic_backdraft.gd`), Anvil (down strokes and a crater each: `comic_anvil.gd`), Tow Line's air rip (a void tear: `comic_rip.gd`); words WHIRRRL!, SIZZ-BLAM!, KSHUNK!, FWHOOOM!, BLOOORRM!, KLANNNG!
- [x] State tells for the improvised routes: molten (halftone glow), buried (crack ring), skewered (ice stake), fading out with `ELEMENT_HOLD` (`comic_state_tell.gd`, synced from `enemy._physics_process`)
- [ ] Hailstorm only ever lifts one foe in the bot's string (the cube Ice Cube bowls); the dummies Ice Cube passes aren't frozen, so the whirlwinds read as one (combo lane: freeze the bowl's victims, or film on a pile of frozen foes)
- [ ] Eruption's landing still has the breaker's big brown crater under him for 0.6 s+, which outlasts the slabs (breaker_quake's crater; try the comic_erupt break instead on this breaker)
- [ ] Impale's hit is the busiest frame of the string: two cubes, the tentacles, a hit star and a number on each, KSHUNK! and the stakes; the stakes read only in the scratch shot
- [x] (dropped `wire`, damage 40 -> 46) Cataclysm's hang is still Live Wire's green bolts and violet binds on every foe (`wire: true`); with the landing's crater it is still the busiest breaker. Try dropping `wire` or thinning Live Wire in the hang (combo lane)
- [x] Third pass, the element matrix's 15 payoffs: a one-beat tell per cell in the two palettes that met (`comic_improv.gd`, one table, one draw function a cell; was a wind pillar, shards, steam, a rim geyser, ink bursts, scorches and arcs), its own word over the move's (`ComicFx.IMPROV_WORDS`): Gale Lift FWISSH!, Shatter SHA-KRAK!, Frozen In KRRIK!, Aftershock BA-DOOM!, Swallowed GULP!, Firestorm FWAAASH!, Quench HSSSSK!, Flare-up FWUMP!, Smother SMOOSH!, Ice Spreads KRIK-KRIK!, Torn Off RRRIP!, Freeze Aloft FRZZK!, Meteor Spike KA-CHUNK!, Torn Loose SNAPP!, Frozen in the Dark KLINNK!. Look: `tests/improv_shots.gd`; looks in `docs/features/element-matrix.md` "Looks"
- [ ] Matrix tells: Meteor Spike's falling line and Firestorm's ember line hide under Molten Palm's / Updraft Lash's own stars when the move plays; Swallowed's jaws sit under the crater squash for their first two steps (try starting them a step late)
- [ ] Matrix tells by hand: whether the payoff word over the move's word reads in fast strings, and the 12 cells the bot never reaches

## Round 38 (foe locomotion)
Zak, about the hero: "the movement animation is awful" (fixed in round 35); the nine foes had the same problem: KayKit-era runs played up to 3x so the stride check passed. `tools/comic_art/foe_keys.py` re-keys them on the chunky blends from per-foe specs (`foe_cycles.py`); see `docs/features/comic-style.md` "Foe locomotion" and `docs/features/enemy-hit-reactions.md` "Clips". Seen in Blender side sheets and windowed game-camera films, not played.
- [x] Runs keyed for each kind's move speed at 1x (legs by IK, the planted ankle sliding exactly v / 24 m a frame, legs / hips / squash every frame, arms / head on twos, loops from frame 0): minion scurry, warrior stomp, shield plod, rogue sneak-dash, archer trot, mage float, bomber waddle, necromancer glide, Warden heavy stomp. `run_clip_speed` at move speed went from 1.16-3.0 to 0.96-1.03 (`RUN_CLIP_SPEED_MIN/MAX` 0.5 / 3.0 -> 0.35 / 1.6)
- [x] `tests/foe_stride_check.gd`: the median planted speed in the lowest 20% of the foot's height (was the mean in the lower half, which lift-off and touch-down dragged 10% low), and the Warden checked too (`BOSS.run_foot_speed`; `boss.gd` plays its walk at `run_clip_speed`)
- [x] The Warden's footfalls shake the floor (`boss._stomp_shake`, `STOMP_AT` 0.04 / 0.54 of the walk, `STOMP_SHAKE` 0.12)
- [x] Hit_B, Lie_StandUp and Death_A keyed per body type (light, heavy with a braced shield arm, robed, the bomber face-first) on all eight foes, the Warden's Death_A as a heavy topple
- [x] Eyes squeeze shut on every foe: archer, mage, bomber, necromancer and the Warden got `eye.l` / `eye.r`; all nine shut them on Hit_A, Hit_B (launches too) and Death_A
- [x] `tests/foe_shots.gd -- --clip=run|Hit_B|Lie_StandUp|Death_A --frames=N --only=a,b`: films foes through one clip from the game angle, runs moved along the floor at move speed
- [ ] By hand: `--spar=minion|rogue|shield|warrior` and judge the new runs in motion (turning, the speed ramp, circling at 0.4 of move speed at clip 0.35-0.5)
- [x] Round 38 b: every foe's attack keyed as tell (on twos, shaking) / 2-3 frame smeared strike / recovery with overshoot: minion swipe, warrior overhead chop, shield bash, rogue double stab, archer draw-and-loose, mage staff cast, necromancer raise, bomber fuse leap, Warden slam (overlaid on the kit's). Melee contact on `attack_hit` (enemy_types: minion 14, warrior 19, shield 17, rogue 11) at `enemy.chop_speed()`; see `docs/features/comic-style.md` "Foe attacks"
- [x] Idle_Combat (breaths, weight shift, weapon bob, glance, jaw chatter) and Hit_A (head snap, eyes shut) keyed per foe
- [x] Rogue and minion: Run_Start (6 f) / Run_Stop (9 f) one-shots (`enemy._play_locomotion`, `RUN_START_BELOW` / `RUN_STOP_ABOVE`) and a turn lean (`scripts/foe_lean.gd`, `enemy.TURN_LEAN`)
- [x] `foe_keys.py`: absolute `aim` per bone (with twist), `keep` (props hold their world angle), `src` / `follow` overlays on kit clips, `sheet=` two-view sheets (side + game camera); fixed a hold-into-key off-by-one
- [ ] By hand: spar the rogue and minion for the start / stop / lean feel (`TURN_LEAN`, `RUN_START_BELOW`); the warrior's overhead tell is small from the game camera (the helmet covers the hands)

## Round 39 (Foe models, chibi pass 2)
Zak, on the chibi lineup: "I definitely like this chibi direction better. We can redesign and fine tune, but assume we want this kind of art style. We will refine them all going forward." `tools/comic_art/refine_pass.py` (mesh and materials only, between chunk_pass and foe_keys; every bone, rest pose and clip kept). See `docs/features/comic-style.md` "Foe models, chibi pass 2". Seen in windowed `foe_shots.gd` shots, not played.
- [x] Silhouette: one bigger signature prop per foe (minion cleaver, rogue daggers, shield wall cleared of its clutter, warrior blade, mage hat, archer bow 1.8x thicker, bomber bomb, necromancer hood, Warden arms)
- [x] Colour families by element (fx_palette.gd): legion earth orange, cult void violet, grave wind green; eyes and one region per foe in the accent (`P_Foe*` tones, `P_Glow*` emits)
- [x] Faces: eyes 1.65x tipped up to the camera, slanted brows on the eye bones (the squint folds them shut), teeth scowl
- [x] Heavier ink on the outer silhouette only (`ComicLook.silhouette`, `shaders/foe_silhouette.gdshader`, 4 px pushed 0.3 m back)
- [x] Tri budget kept (each under round 38's +20%); health bars raised for the mage, necromancer and bomber
- [x] The warrior's tell still hides under its helmet from the game camera; a longer blade helped the idle read, not the overhead chop (anim lane: aim it wider past the shoulder)
- [x] The shield's planks still break into a light / dark checker under the cut tones (brush 0.1 did not fix it): flatten the plank geometry or give the wall one flat face
- [x] Minion: still the plainest; try a bigger skull cap or a hunch with a spine ridge, and a cleaver with a clear blade shape
- [x] By hand: spar each family and see whether the accent colour sorts a crowd at a glance (`--spar=minion|rogue|shield|warrior`)
- [x] Round 39 b: the warrior's chop re-keyed so the tell holds the sword out wide past its right shoulder (az -100..-112) with the free arm at the target, and the strike whips across its front to finish low past its left foot; `attack_hit` stays 19 (filmed with `foe_shots.gd -- --clip=1H_Melee_Attack_Chop`)
- [x] Round 39 b: the shield's planks rebuilt as one flat slab (`refine_pass.py` `slab`: convex outline on the best-fit plane, inked `P_Black` rim, flat `P_Wood` face at brush 0, iron bands dropped, the orange boss centred); tris 9953 -> 8840
- [x] Round 39 b: the minion's cleaver turned to face the camera and redrawn as a square steel cleaver with an inked spine (`cleaver`), and an orange skull cap fitted over the cranium with a ridge of four bone fins (`cap`); tris 7946 -> 8108
- [x] Round 39 b: the training dummy takes the foes' face (eyes 1.65x tipped 30 degrees, angry brows on the eye bones, a scowl) and their heavy outer line (`SILHOUETTE_KINDS`); bag bones and spring untouched
- [x] Round 39 b: crowd read from the lineup and `--spar=warrior|rogue|shield --autotest`: the archer's green cloth (grave's colour on a legion foe) went burnt orange and the necromancer's red shroud deep green (`KIND_TONES`)
- [ ] The cult's void violet is also the hero's claw and void effect colour: mid-string a rogue or mage is the hardest foe to pick out; try a colder indigo or a pale rim for the cult
- [ ] `--spar` takes only legion and cult kinds (`spar.KINDS`), so the grave pair was judged in the lineup only; add necromancer to the spar list to see the green family in motion
- [ ] The shield's black rim merges with its ink line on the dark floor and reads as a thicker outline more than a rim; try an iron rim if it should read as metal

## Round 40 (hero model, chibi pass 2)
Zak confirmed the chibi heretic as the art direction: "we can redesign him and fine tune it... chibi-esque, cartoony, not taking itself too seriously, but still badass." The model is fine-tuned with the rig, bone names, rest pose and every clip kept (contact_frames prints the same frames; `chibi_keys.py` re-run over each new blend). No Meshy credits spent (75 of 200). See `docs/features/heretic-hero.md` "Chibi pass 2". Seen in windowed `heretic_shots`, `foe_shots` and `string_film` stills, not played.
- [x] Texture repainted into flat bold regions (`tools/meshy_rig/chibi_repaint.py`): every triangle classed by old colour and bones, small islands merged away, 2-3 flat design tones per region (crimson scarf and hood lining, boot soles and cuffs, tunic and skirt hems, the claw in the fx palette's void: violet body, light tips, deep wrist band); no painted shading
- [x] Silhouette (`chibi_shape.py`, vertices only): the hood's peak narrowed and sheared 0.2 m back at the same 1.85 m, so it pokes past the hood from the game camera instead of reading as an egg; every claw x1.35 round its own bones past the palm
- [x] Face: a toothy smirk drawn with the eyes (`heretic_rig.gd` `GRIN`), eyes squinting on attacks, squeezing shut when hit, blinking at rest; the grin bares or grits with them (`squint`, `_step_face`; checked in `heretic_shots`)
- [x] Weapons (`chibi_weapons.py` + `ComicLook.KIND_TONES["heretic"]`): fatter hafts in the claw's violet, void deep/ink heads, one element accent each, a 1.6x spear head and a hammer reaching 1.62 m (was 1.34); no paper rim on them (`heretic_rig.RIM_SKIP_FORMS`), thin ink only
- [x] Before / after lineup with the nine foes and the dummy at the game camera (`tests/foe_shots.gd -- --tag=`)
- [x] Presence (second lane, `chibi_presence.py`): head and hood x1.2 about the neck, the hood x1.25 wider and 6 cm taller, the claw x1.5 about the wrist with its bones, a 5 cm wider stance per foot, the hood tip at 2.05 m (Armature node scale; `chibi_keys.py` divides the run's ground speed by it). Game camera: 146 -> 183 px tall, 12.3k -> 17.7k px of silhouette (warrior 209 px, 28.4k)
- [x] Contrast: a three-value figure, bone-white hood over a blue-black body, violet claw and cyan eyes the accents, crimson scarf, sash, cuffs and wrap
- [x] A crimson scarf tail on its own spring chain (`chibi_scarf.py`: 0.89 m ribbon, scarf.01-04 off chest; `heretic_rig.gd` `ScarfSprings` + `_flutter_scarf`)
- [x] The face: a dark oval painted over Meshy's mask (`chibi_repaint.FACE_OVAL`) and a depth-tested dark `FaceShade` oval behind the eye and grin decals, so the grin sits on shadow in 3/4 views
- [x] Before / after lineup (`foe_shots -- --tag=mh2_before / mh2_after`) and a four-string film (`string_film -- --to=3`)
- [ ] He is still smaller than the warrior at the game camera (183 vs 209 px, 17.7k vs 28.4k px): the 2.05 m cap leaves a bigger bake or a hero `model_scale` as the next lever
- [ ] The scarf tail reads from the side and behind; from the front the hood hides it, and its flutter is unplayed
- [ ] By hand: whether the squint / grin on attacks reads in play or flickers across fast strings
- [x] Hero pass 3, face to camera (`chibi_faceup.py`: head tipped back 28 degrees about a point over the neck, the hood's front rim cut 5 cm wider; `heretic_rig.FACE_TIP`): bigger eyes (0.15 x 0.085 m), grin and a dark face oval drawn `FACE_PULL` 0.22 m nearer the camera so the brim stops hiding it. Idle at the game camera: face 1.7% -> 7% of his silhouette; `heretic_shots` checks the facing headless and samples the face and both eyes' pixels windowed
- [x] Hood point hooked (`chibi_hook.py`): sheared back and up, its last part bent over to his left at an angle, one hard corner in the outline
- [x] Scale: `heretic_rig.MODEL_SCALE` 1.15 on his Armature node (hit areas unchanged; `chibi_keys.py` reads it for the strides, `hero_stride_check` 1.00): Idle 214 px tall vs the warrior's 226 (0.95), 29.3k px vs 32.9k of silhouette (pass 2: 196 px, 20.1k on the same camera)
- [x] Claw raised beside his head in Idle and Idle_Ready, its spread tipped up to the camera (`chibi_keys.py` `IDLE_RH` / `READY_RH`)
- [ ] Round-3 lineup before / after (`foe_shots -- --tag=`) and the four-string film (`string_film -- --to=3`): cut at Zak's stop-point before the demo
- [ ] By hand: whether the pulled face oval draws over the claw in VS / lift poses in play (it hides with the mouth when the claw covers it)

## Round 41 (Feel audit 2)
From `docs/feel-audit-2026-11-05.md` (22 strings, the spar foes and six hero clips filmed at dev 9526983; round 1's
items 1, 2, 6, 7 and 10 fixed, 3, 4, 5 and 8 half, 9 not). Zak's wake-up page: `docs/round2-2026-11-05.md`.
- [x] 1. The Awakening column buries every breaker landing (every coverage frame over 0.2): hold it until the landing clears, or ink-outline it at ~0.3 alpha (heretic-fx). Done: `awaken_flourish.gd`, one thin inked column held 0.4 s past a landing
- [x] 2. `LAST n` tags on every dummy all the time: only the dummy hit most, number-sized, fading 1 s after the string (training). Done: every hit dummy's tag, 40 px thin ink, gone 1.5 s after its string
- [x] 3. A name callout on every move (DASH STAB, HARPOON, ICE CUBE...): names on enders, crossovers and first finds only (heretic-fx / hud). Done: enders, crossovers and breakers (`callout_cap.names_move`)
- [x] 4. The "New combo:" banner runs through the whole next string: cut it on the next string, `FOUND_HOLD` ~1.2 s real (hud / training). Done: `hud.show_found`
- [x] 5. Dash Stab and Harpoon still land soft (x1.00 on their HIT frames): brake DL's lunge on a foe ahead, a stop on Harpoon's catch (combo-rhythm). They whiffed: the dash now arrives (`DASH_ARRIVE`) and the stab brakes (`DASH_STAB_BRAKE`); not yet re-filmed
- [ ] 10b. Tow Line off a dash out of a move (EF / IP -> TW 457-526 ms): hand it over early without shortening its line (the frozen x dark cell went 3 -> 0 when tried) (combo-rhythm)
- [ ] 10c. L3 -> EM 527-544 ms and Molten Palm's two-speed retime (item 7's combo side), Meteor Fall's throw sized to `camera_rig`'s frame cap (item 9's combo side): left out at Zak's demo stop (combo-rhythm)
- [ ] 6. Overwhelm's pool is the last thick colour (hold: mean coverage 0.22): the halftone floor look, one thin rim (heretic-fx)
- [ ] 7. Molten Palm's coil is one held drawing (Ab_AF frames 8-46 of 61) and a blink at `EM_SPEED` 2.8: re-key a building ~16-frame coil, `EM_SPEED` ~1.8 (heretic anim, combo-rhythm)
- [ ] 8. The run reads as a hood dragging a claw, Run_Stop as a spin: smaller claw swing, legs clear of the hood, keep the stop's facing (heretic anim)
- [ ] 9. Meteor Fall's beats happen at the frame edge (throws off the top and right, tentacles leaving the screen): throw along `_brk_dir` inside the x2.0 view, a tighter gather (combo, camera)
- [x] 10. (Dash Stab side: move -> DL 326-406, DL -> EF 282-370 ms; Tow Line is 10b) Dash hand-overs drag: EC / XR -> DL ~500 ms (444-449 after 3f27472), -> TW 451-467, DL -> EF ~430 in the matrix routes, against the 362 ender (combo-rhythm)
- [ ] Overwhelm's pool (item 6): halftone it like the frost floor (`halftone_floor.gdshader`), a thin ink rim, fade with the hold (`dark_fx.Pool`); left out at Zak's demo stop-point (effects lane)
- [ ] The combo guide's mix / pay tags are plain text: a small element chip (dot in the element's palette) before each (`combo_guide.gd`); left out at the demo stop-point (effects lane)
- [ ] Film the round 41 effects lane after (`string_film`, `fx_coverage.py --per-string`) against the audit's 0.090 mean / 0.309 max; the lane landed on headless checks only at the demo stop-point
- [x] `foe_lean.gd` asked for a zero-axis Quaternion on a tipped-over rogue / minion (128 engine errors in one rogue spar film, now 0); `heretic_shots --clips` films Death_A and Ab_Swing (they weren't in `CLIP_SET`)

## Round 42 (Design review)
From `docs/design-review-2026-11-05.md` (combos, effects and designs against Zak's rule "every combo has a good time
to use it; used on purpose, you are very strong"; judged from the docs, the move tables and the `combo_clips` film).
Meteor Fall diving onto the largest group is decided (combo lane); Avalanche is not to be touched.
- [ ] 1. Training drills with live foes that each ask one question (shield wall, back line, rush, bomb squad, against the wall): nothing in the room asks for one move over another
- [ ] 2. A wall rule for every big knockback (splat + bounce; pillars count) and walls in reach (smaller room or inner walls): Molten Palm's wall drive can't be found in a 32 m room
- [ ] 3. Breakers with different end states (stun, bounce up, stay frozen, throw to walls, execute one): nine breakers end in the same crater
- [ ] 4. Name each foe's answer in code and on screen (Triple Chop breaks shields, throw a lit bomber, Black Tide pulls the back line, Overwhelm holds the heavy): the hooks exist in `enemy.gd`, nothing teaches them
- [ ] 5. Split the overlaps: rename the air Live Wire, Steam Burst as the room-wide frozen cash-out, Black Ice leaves them frozen (setup) and Maw is the payoff
- [ ] 6. Make the element matrix uneven (a few big cells, the rest small) and teach it as two rules (the element decides what happens, the state how much)
- [ ] 7. Combo counter and rank react: drop on a hit or a pause, grade by wall splats, matrix cells, PERFECTs and guard breaks (418 HITS SSS all session now)
- [ ] 8. A counter window after a perfect dodge (next string's first hit crits): the dash is the only defence and pays nothing past survival
- [ ] 9. Tint the dummies away from the hero's cream and colour hit stars by element: the hero and the element are lost in piles
- [ ] 10. One element ink shape per breaker impact frame, smaller per-hit numbers on lights: numbers are the loudest thing on screen

## Round 42 b (second hero: dragon prince, ideation)
Zak: "a spellblade younger dragon prince... throwing sword, flying up and smashing into it to explode it then
resummoning a new magic sword... dragon abilities like an evoker... royal sword play... kingly/pride features."
- [x] Design draft: `docs/characters/dragon-prince.md` (sword states and the One Sword rules, dragon magic, royal
  swordplay and parry, Majesty and the falling crown, a 16-string move list with four throw/fly/smash routes,
  look and Meshy prompt, clips, reuse vs new code, build order, 8 open questions). No code, models or credits
- [ ] Zak answers the open questions (doc section 9), then the first slice: a hero switch on a placeholder body,
  then Royal Chain, Javelin, Skyfall and Royal Draw on the dummies

## Round 42 c (Meteor dive, item from the design review)
Zak: Meteor Fall shouldn't use the tentacles to slam everyone into the nearest surface and regather them. Every combo
has a best situation; Molten Palm punches a group into a wall, Meteor Fall dives on that group.
- [x] Meteor Fall's beat 1 (tentacle throw into the walls) and beat 2 (tentacle gather, DOGPILE!) are gone: hero_leap phase 3, `METEOR_WALL_*` / `_GATHER_*` / `_DRAG_*` / `_PILE_AHEAD` / `_PILE_RING` / `_BEAT_STOP` / `_DIVE_LATE`, `comic_splat.gd`, `ComicFx.say()`, the rip hold (`rip_target`, `_tear`, the two-way tentacle) and `void_grab.pile` / `chased`
- [x] `void_element.meteor_target()` (pure): groups within 12 m by 3 m, a foe splatted on a wall in the last 3 s counts 1.5 (`thrown_foe` meta `last_wall_ms`), best group wins (nearer on a tie), lands on its middle; nobody in reach: ahead of him. The cue sits on it through the hang. A far group stretches the 0.3 s dive at 30 m/s (12 m: 0.4 s)
- [x] The landing hits everyone in 3 m (crater), x1.3 on the freshly wall-splatted, x1.5 on big ones; Undertow lets go as he lands. Molten Palm's x2.5 wall splat checked (34 on a test foe vs 14 for the palm alone), not tuned
- [x] Camera: the `HANG_FRAME_*` / `BEATS_PHASE` pull-out went with the beats; a hang settles at `HANG_SETTLE` and the 12 m dive follows without a snap (`camera_feel_check`)
- [x] Checks: `void_arm_check` `_meteor_target()` (stray vs group, splatted vs equal group, bigger group vs splatted stray, empty) and palm-into-wall -> Undertow -> meteor dives past a nearer foe onto the splatted one
- Supersedes round 41's item 9 and 10c's Meteor Fall throw (there is no throw now)

## Round 42 d (second hero: dragon prince, first slice)
Zak's open questions (dragon-prince.md section 9) are unanswered: built on the doc's recommended defaults, each a named
constant (`PRINCE_MOVES.ONE_SWORD` / `SMASH_ANY_TIME` / `ROYAL_DRAW`, `SUNBRAND.REFORM_TIME`; the list is doc section 10).
- [x] `--hero=prince` (`Game.hero`): `scripts/prince/prince.gd` extends player.gd on the tinted chibi body with a crown,
  horns and a built Sunbrand; the heretic without the flag is unchanged (prince_check spawns both)
- [x] Sword states in hand / out (flight, planted in the floor or a foe, returning) / shattered (`scripts/prince/sunbrand.gd`),
  a sapphire beacon and gold floor ring on the planted sword
- [x] Royal Chain (L L L), Ember Flick (L H), Javelin (L L H), Skyfall (H with the sword out: rise, hang, dive, 3.5 m blast),
  the 700 ms re-form, Rightful Return (hold L), Talon claws (L while out), Dragon Breath (H)
- [x] Combo guide rows and the pause MOVES panel are his (one-line hooks: `guide_rows()`, `move_sections()`)
- [x] `tests/prince_check.gd` in `agent.sh check` (throw, smash, re-form, breath, recall: states and damage); windowed film
  `tests/prince_film.gd`; clip `awaken-combo-clips/13 Dragon Prince core loop.mp4`
- [ ] Next slices (doc section 10): the smash's window and Royal Draw, wall pin, Sword in the Stone / Kingsfall, kindled and
  Heat the Blade, charged casts, parry, Majesty and the crown, the HUD sword icon, his model and clips

## Round 42 e (Molten Palm reaches the wall; Flash Freeze regression)
- [x] Regression: breakers=10/11 in ~2 of 3 autotests since Meteor Fall's dive, Flash Freeze missing. Cause: Awakening
  ran out during Dash L H H L (the dive's extra hits moved the meter) and `hero_awaken.set_awakened` reset
  `_anim_mult` mid-move, dropping Steam Burst's `EM_SPEED` 2.8: its palm came ~2.8x late, after the ice cube had
  shattered on the back wall. Now a move in flight keeps its pace; the next takes the new base. A player hits it too
  (any move with a `speed` when the meter runs out). `rhythm_check` covers it; XS beat back to ~406 ms
- [x] `camera_feel_check`'s dive (0.21 m "over" every run) was the test: the hero moved by wall clock, the rig by the
  engine delta. Stepped by hand now; the rig never snapped
- [x] Molten Palm carries a foe on to a wall within `PALM_WALL_REACH` 10.5 m; Meteor Fall follows a fresh splat to
  `METEOR_SPLAT_REACH` 17 m. Filmed with `string_film --layout=wall|stray`
- [ ] The splat lands at the top edge of the frame for a beat (the hang turns the fight framing off): a camera follow-up

## Round 43 (breaker choice indicator)
- [x] Zak: "make sure the indicator shows each option for the player to choose". The breaker prompt shows every
  ending at once: an inked mouse in the circle with each live button in its ending's colour, and one chip per ending
  under it (`[LMB] BLACK ICE or [RMB] MAW`, key rim and name in the fx_palette colour); one ending shows the same
  layout with one chip. The press keeps the chosen chip. `hero_leap.options()`, `breaker_prompt.gd`
- [x] The floor cue no longer flashes the first ending's colour when L picks the other: the closing ring is two-tone
  until he picks, then the picked colour (both pairs land on the same spot and reach)
- [x] Pause MOVES: a second ending prints as "or L in the window" under the first (`move_list` `or`)
- [x] Audit and a proposal table of second endings (setup vs payoff, environmental payoffs kept) in
  `docs/features/combo-breakers.md` "Round 43"; checks in `prompt_follow_check`, `void_arm_check` `_breaker_choice`,
  `move_list_check` `_check_endings`; clip `awaken-combo-clips/16 Breaker choice indicator.mp4`
- [ ] Zak picks which second endings to build (the proposal table); items / mechanics to nudge LMB vs RMB
- [ ] The combo-name callout still overlaps the top of the circle in the hang

## Round 43 b (designed effects pilot)
Zak: "the effects are not really effects, they're just polygons you're putting together. I'd like them to actually be
designs, still stylistic." See `docs/features/designed-fx.md`.
- [x] Pipeline: authored flipbook sheets drawn by a seeded Python generator (`tools/vfx_gen/`: Pillow + numpy + scipy,
  4x supersampled, inked rims, per-frame silhouettes), packed as (tone, erode order, boil, cover) and played by four
  shaders (`shaders/designed_*.gdshader`: palette ramp per element, erosion with an ink / hot burn line, strip textures
  on shaped meshes). One shared material per sheet, instance uniforms per effect, prewarmed in `elements.prewarm`
- [x] Pilot: hit star, impact strokes, swing slash, Meteor Fall's landing (crown, lava wave, rim splashes, cooling
  crust), Molten Palm's wall splat, ice shatter / cube burst, every lightning bolt and arc, the dust puff
  (`scripts/designed_fx.gd`; call sites keep their old paths)
- [x] On by default; `--fx=classic` plays the old polygon effects from the same build. Clips:
  `awaken-combo-clips/17 Designed effects before-after.mp4`, `17 Designed effects sheet.png`, one side-by-side per effect
- [ ] Zak's call on the look, then the conversion list in the doc, most seen first (element_hit chips, the axe ribbon,
  comic_dust, the breaker and crossover effects, the dark element's ink tendrils)
- [ ] The wall splat lands at the top edge of the frame (round 42 e's camera follow-up): mostly off screen in the film

## Round 44 (fx-cohesion)
Zak: "really focus on a refinement of the art style and effects. They look weird to me." See
`docs/features/designed-fx.md` "Round 44".
- [x] The tentacle: a smooth tapered Catmull-Rom ribbon with an authored skin (back, belly, suckers, wrinkles), ink
  drawn in metres with the hero's paper rim, a claw tip, a tangent-entry coil (1.35 turns) and a lash smear;
  `points()` / `tip()` / `electrify()` for other lanes (`void_tendril.gd`, `shaders/tentacle*.gdshader`)
- [x] Every flat floor hoop is a designed ground stamp (3-5 broken brush arcs racing out on twos) or gone: comic_pop
  rings, dark hoop runs, the rank-up, hop-landing and crater hoops; the breaker cue is a brush ring and dashes with
  the same colours and timing (`designed_ink.gd`, `shaders/designed_stamp.gdshader`)
- [x] One designed pop a hit in the element's shape (storm, magma, ice, dark), element chips gone, crowd caps (two
  full pops a frame, one streak set, one chain spark)
- [x] Weapon trail plays the designed slash strip (`shaders/weapon_trail_designed.gdshader`)
- [ ] Still drawn as polygons: dark pools / Singularity vortex, the Reap crescent, comic_axe_aura, chain halos, daze
  stars, comic_dust, the dash streak, combo pop strokes, kills, the Awakening, the spirit echo ghost
- [ ] Zak's call on the look (clips `awaken-combo-clips/21 Cohesion ...`)

## Round 44 (hero model v2)
Zak: "please take a look at the heretic model, it sucks and is super buggy in game lol. I'm fine going a different
route than the original with hood and such". See `docs/features/heretic-hero.md` "Hero model v2".
- [x] A hand-scripted chibi body on the same rig (`tools/hero_build/hero_v2.py`, headless Blender, no Meshy): bone-white
  hood with devil horns and a back point, a real recessed void face with a crimson rim, blue-black tunic and skirt, big
  boots and left glove, crimson scarf, a beaded violet claw arm with a palm, three big claws and a thumb. 20.4k tris,
  flat swatch palette. Picked from three variants (hook / horns / twin)
- [x] Put into the committed GLB by a byte-level repack (`tools/hero_build/glb_swap.py`): every bone, the skin and all
  62 clips unchanged, so contact frames, `HERO_MOVES` and every check hold
- [x] The face is geometry: eyes and grin lie on the face plate, depth-tested; `FACE_PULL`, `FaceShade`, `EYES`,
  `HEAD_GROW`, `FACE_TIP` and the claw cover test (`_covered`) deleted from `heretic_rig.gd`
- [x] Chunky inked weapons formed by the claw, built in each weapon bone's frame: crescent axe with a green edge,
  broad cyan leaf spear with barbs, a lava-banded hammer block with spikes (3.7k tris)
- [x] Before / after and the variant sheet: `awaken-combo-clips/18 Hero model v2 *.png`
- [ ] Zak plays it: seen in stills and films from the game camera only
- [x] Second pass, judged on the play camera's film: void-dark horns with crimson tips (violet merged into the
  claw), a crimson stripe over the crown and a longer back point, a wider and longer scarf, a crimson skirt hem;
  Awakened keeps his colours (tight gold fresnel edge instead of a gold wash); the clips' hood squash damped to
  45%; the axe 0.8x (it hid the dummies); the axe edge in the storm lime; `chibi_keys.py` puts the v2 body back
  after every export. Clip: `awaken-combo-clips/18 Hero model v2 before-after.mp4`
- [ ] Zak: horn tips crimson or violet, the Awakened edge strength, whether to re-key the hood squash for v2
## Round 44 (fx-air)
Zak: "Air needs to be clearly air but stylistic, and make lightning combos more a part of everything." The storm
element had one green for wind and lightning alike; its whirlwind read as a green spring. See
`docs/features/designed-fx.md` (Air twister, Air gust, Lightning palette; shape language Air vs Lightning).
- [x] Air palette row (`fx_palette.AIR`, designed row `air`): pale white-mint, one cool shadow tone, slate ink
- [x] The designed twister for every `comic_gale` (Updraft Lash, Fault Line): floor swirl, three hooked wind ribbons
  on depth-tested helix bands (far half a band darker), wisps flung off the top, leaves / paper / pebbles spiralling
  up; four look rounds from the film (`scripts/designed_twister.gd`, `tools/vfx_gen/air_sheets.py`)
- [x] Lightning in electric lime round a white-hot core (picked over yellow-white, which sat on the hit star's
  yellow): storm row, `elements.LOOK.wind`, the axe form burst; bolt_strip / storm_burst redrawn
- [x] Storm blows' directional half is a pale air gust (two a beat), storm swings in the air row; Hailstorm,
  Backdraft, Gale Lift, Firestorm, Torn Loose in air; Storm Pitch lands in wind (`DESIGNED.wind_burst`)
- [x] For the combo-lightning lane: `DESIGNED.bolt_path()` (a bolt along a polyline), `DESIGNED.zap()` (a pop on a foe)
- [ ] Still the old look: `comic_axe_aura` storm sparks and the axe's own glow material (`P_GlowWind`, still green),
  `comic_arc`'s speed strokes, the dash streak in storm
- [ ] Zak's call on the look (clips `awaken-combo-clips/19 Air ...`)

## Round 44 (combo-lightning)
Zak: "make lightning combos more a part of everything. I specifically want one where the tentacle conducts lightning
and zaps everybody". See `docs/features/void-element.md` ("The tentacle conducts") and `element-matrix.md` (charged).
- [x] Live Wire's hang is conducted (`scripts/live_current.gd`): the charge gathers at the claw, each `WIRE_STEP` jolt
  runs out along every tentacle's drawn curve as a lime knot with the bolt strip lit behind it, the tentacle washed
  storm-light on twos (`void_tendril.electrify`), each foe zapped as its pulse arrives (quiet `zap_hit`, two forks),
  then arcs on to those no tentacle holds
- [x] Galvanize (H L L, `XC`): a tentacle out to each foe Reap marked, wherever it stands, and one pulse down them all;
  7 a zap x (1 + 0.3 per other link), arcs on (6). Best on a spread-out crowd; bot string `spread H L L`
- [x] The charged state: set by Live Wire's jolts, Grounded, Storm Pitch, Galvanize, Fault Line, Cataclysm; a crackle
  tell on the foe; cells Overload (storm), Superconduct (ice), Arc Flash (magma), Conduct (dark) with tells and
  words; bot string `spread H L L wait L H` (Overload)
- [x] Clips: `awaken-combo-clips/20 Lightning *`
- [x] Grounded's LMB ending (Short Circuit, combo-breakers.md round 43 table): round 44 b
- [x] Feel pass: no pitch control, so a hit stop a step longer and a fatter bolt each link instead (round 44 b)
- [ ] Zak plays Galvanize and the four cells by hand

## Round 45 (fx-cohesion2)
Orchestrator review of round 44: the floor still read as circles, and the cue turned lime and loud. See
`docs/features/designed-fx.md` "Round 45".
- [x] One ring-like floor mark at a time: open hair-thin shock arcs (~45% of the circle) living 0.15-0.25 s, a second
  within 5 m dropped, none while a breaker cue is closing (Live Wire max marks 4 -> 3, shocks during the cue 4 -> the
  press snap only)
- [x] Quieter breaker cue: thin target line, broken cream closing dashes with every third tile in the ending's colour
- [x] Dark: authored pool and Singularity vortex decals (boiling on twos, light rim), the Reap crescent as the designed
  slash; the hole's inward hoops gone
- [x] Kills, dash streaks and locomotion dust drawn (`dust_puff`, impact streaks, a held hit star)
- [x] Clips: `awaken-combo-clips/21 Cohesion Live Wire tentacle and rings before-after.mp4`, `21 Cohesion Singularity
  rings and vortex before-after.mp4`
- [ ] Still polygons: `comic_axe_aura`, chain halos, daze stars, combo pop strokes, the Awakening, the spirit echo ghost
- [ ] Zak's call on the cue (cream with an accent vs the ending's colour all round)

## Round 44 b (fx-air, round 2)
Orchestrator's round 2 for the air / lightning split. See `docs/features/designed-fx.md` (Sky strike, Crawling arcs,
Tentacle lightning; tuning).
- [x] Old storm greens: the axe glow rows `P_Wind` / `P_StormGreen` in the storm lime (`comic_look.EMITS`); the axe
  aura and its sparks already read `ELEMENTS.LOOK` (lime); the dash streak is spirit teal / Awakened gold (no green)
- [x] The sky strike as an authored moment (`designed_strike.gd`): leader, white-hot main bolt held through the hit,
  forked afterimage, scorched star on the floor, arcs crawling on the struck foes; Grounded, Cataclysm, Fault Line;
  three look rounds (an isolated shot twice, then the film)
- [x] Wind presence: the twister's anticipation holds 0.12 s with debris dragging in along the floor; Fault Line's
  gales at full twister size; Storm Pitch's burst gusts over the pile's heads; Backdraft's haul trails gusts
- [x] The tentacle's conducted bolt fatter and crackling white-hot on twos; arcs crawl on every zapped foe
- [ ] Left green on purpose: `comic_bolt` / `comic_gale` STORM consts (`--fx=classic` only), `fx.gd`'s classic
  `element_hit` (fx-cohesion's), `P_GlowWind` (foe eye glow), `void_tendril.electrify`'s default tint (fx-cohesion's)
- [ ] Galvanize's tentacles not filmed (no bot string in the film range); it shares Live Wire's code
- [ ] Zak's call on the look (clips `awaken-combo-clips/19 Air f..` onward)

## Round 44 b (combo-lightning, second pass)
Orchestrator: make Galvanize the showpiece, thin Live Wire's late hang, Short Circuit, real-move proof for the cells.
- [x] Galvanize as an event: tentacles whip out to everyone within 8 m (Reap's marked from 11 m, x1.25), one by one;
  a held charge beat in half-speed slow motion, the tentacles lighting out from his claw; one fat pulse lands on all
  of them on the same frame (a real hit and stagger each), the hit stop and BZZRAKK! sized by how many are linked;
  the arcs on, a longer hit stop each link; the tentacles snap back
- [x] Live Wire: one small fork per arrival; the charged mark and its crackle only once the hang ends; the per-jolt
  numbers already merge into one counting number per foe (`comic_number` `MERGE_S`)
- [x] Short Circuit (Grounded's LMB): the held take half and are spent, the charge arcs out one after another to up
  to 8 foes not held within 12 m; best when the room is full past the tentacles. Bot string `spread far alt L H H`
- [x] Charged lasts 3 s; every charged cell has a real-move bot string (Overload, Conduct, Arc Flash, Superconduct)
- [x] Clips: `awaken-combo-clips/20 Lightning r2 *`
- [ ] Short Circuit's far arcs land off the game camera at 10 m: read from the test and the [improv] line, not seen
- [ ] fx-air2 to polish the bolt look (`live_current._trail_strip`, `_head`, `_claw`, `_pop`)
- [ ] Zak plays Galvanize and Short Circuit by hand

## Round 46 (feel-audit3: the whole game on film after rounds 44-45)
Orchestrator: film every string, audit combat feel as a whole, fix the worst. `docs/feel-audit-2026-11-06.md`.
- [x] Audit: 30 strings + free play filmed, ranked top 10 with frame evidence; audit 2's list re-scored
- [x] Item 1: Live Wire's later pulses take a 0.012 s hair stop, not a 0.035 s freeze each (the hang stuttered)
- [x] Item 2: the combo guide keeps the side away from the pile (an edge-slack bug sent it back onto the foes)
- [x] Item 3: an ender's name goes to the top band in the hang, off his chest
- [x] Item 4: the lava well's ticks are quiet burns (words and stars with nothing doing them)
- [x] Item 5: Short Circuit cues its targets for the camera (`FRAME_CUE`), so the far arc lands in frame
- [x] Item 6: Meteor Fall's wall splat in the top-left corner (feel-polish: Molten Palm cues the splatted foe, the hang frames cued foes)
- [ ] Item 7: L3 -> Molten Palm 538 ms (re-key Ab_AF's coil, then `EM_SPEED`; heretic anim + combo-rhythm)
- [x] Item 8: the frost spear's 5 m halftone floor (fx-elements: the drawn `ice_frost` floor)
- [x] Item 9: the spirit echo's brown halftone fan on L2 / L3 (feel-polish: drawn at 0.62 of the reach, thin ink line, real time)
- [x] Item 10: Maw's landing total at the top edge: `comic_number` keeps every number inside `PAGE_MARGIN`
- [x] The spear vault (IJ) is the only contact without a stop (feel-polish: `VAULT_STOP` 0.06)
- [ ] Zak plays Live Wire / Short Circuit / Galvanize by hand after these

## Round 46 (fx-elements: ice and magma base moves designed)
Zak: "the effects are not really effects, they're just polygons you're putting together." The ice and magma right
clicks as authored sheets and faceted meshes. See `docs/features/designed-fx.md` "Round 46".
- [x] Molten Palm: the drawn molten fist (wind-up, flight boiling on twos, squashed impact held, cooling into globs),
  the fissure as a lava seam with spurts every other step
- [x] Lava spurts, geysers (Worldbreaker's rim geysers) and Undertow's lava pool drawn; Meteor Fall's fireball in
  flight drawn (was cones and spheres) and turned to the dive
- [x] Ice: faceted crystal spikes (nova, the fissure in water, Worldbreaker), the frost spear's floor and Deep Freeze's
  cracks drawn; the ice block / frozen foe's ice and the frost spear as faceted meshes (`shaders/ice_facet.gdshader`)
- [x] Clips: `awaken-combo-clips/22 Elements *` (before left, after right)
- [x] The ice dive (Avalanche) drawn as a crystal trail (`ice_trail` on `comic_comet`)
- [ ] Still polygons: the breaker dive trail in the other elements (`comic_comet.gd`), the tentacle's lava / ice skins
- [ ] Zak's call: the fireball stands behind him (he reads in front) rather than wrapping him; the ice block is see-through

## Round 46 (fx-finish: the most-seen polygon effects as authored sheets)
Orchestrator: "effects look weird, just polygons": make the Awakening, the every-hit flourishes, the echo, the weapon
change and the crossover breakers drawn. `tools/vfx_gen/gen_finish.py`, `scripts/designed_finish.gd`,
`docs/features/designed-fx.md` "Round 46".
- [x] The Awakening: gather lines, a gold flame crown behind him, a floor sunburst (`awaken_flourish`)
- [x] Chain halos, daze stars, combo burst strokes
- [x] Spirit echo: a drawn axe head on the arc's edge, no 3 m halftone axe (feel-audit3 item 9)
- [x] Weapon change burst as the element pop; axe aura tongues / motes off on the designed path
- [x] Rockslide boulder, Steam Burst cloud, Eruption and Anvil landings
- [ ] `hero_fx.rank_up`, `callout_cap`, `comic_fault` ground, freeze-over, melt, impale, rip, improv tells
- [ ] Zak: is the Awakening crown big enough (5.4 m), and should the echo axe stay or go entirely?

## Round 47 (fx-ice2: no crystals, ice blocks that fit)
Zak: "get rid of the crystals. i love the new ice block, ensure they're covering the whole character model tho. the
dummies part of them clip out." See `docs/features/designed-fx.md` "fx-ice2".
- [x] No ice crystals in designed mode: water spikes (nova, Deep Freeze's ring, Worldbreaker, Harpoon's line) are
  frost cracks on the floor and cold mist (`designed_elements.frost_mark`); the block's crown, the frost spear's ring
  and crystal head, the frost floor's plates, the ice dive's crystal trail, Flash Freeze's shell, Impale's spikes and
  stake and the improv tells' ice tips are gone (`ice_spike` / `ice_trail` sheets deleted; new `ice_mark` crack sheet;
  the every-hit `pop_ice` redrawn as a shard-free ring and glint)
- [x] Every ice block is fitted to the foe's posed model (`fit_block`, a margin, a random turn); frozen foes hold their
  pose and stand upright, the dummy's wobble is held; `tests/ice_block_check.gd` checks every kind's vertices
- [x] Clips: `awaken-combo-clips/25 Ice *` (before / after)
- [ ] Weapons held out past 1.2 m still poke out of a spar foe's block (by design); the skewered stake tell stays
- [ ] Zak: is a dummy's block (2.2 m across) too big now it holds the arms?
- [x] fx-ice3: the last crystals on film are gone: Dash Stab's cyan blades (its weapon ribbon and swing arcs: off on a
  `thrust` in designed mode), the latch's upright ice-blue streaks (no water streaks on a vertical blow), `ice_shatter`'s
  shards (now a ring, glint and cold mist), Harpoon's set chips (a `frost_mark`), `pop_ice`'s corner rays. Clips
  `awaken-combo-clips/25 Ice fx-ice3 *`

## Round 47 b (combo-harpoon2: Harpoon's tentacles gather, two breaker endings)
Zak: "harpoon grabs any enemies near by in a clean tentacle animation and places them in a line or group in front of
the heretic", then a molten fist punches the cubes into a wall or thunder breaks them where they stand.
`scripts/harpoon_gather.gd`, `scripts/slapshot_fx.gd`, `docs/features/void-element.md`.
- [x] Harpoon (Dash L H): a tentacle to every foe within 8 m (x the chain's reach growth, 5 at most, nearest first):
  reach, latch (10), a curved carry round him, set down in one rank across his aim short of walls, then the cube.
  Big ones freeze where they stand. H during it is still Ice Cube (Dash L H H)
- [x] A pause after it leaps into a two-ending window: LMB Slapshot (Molten Palm's fist slides the cubes along the
  floor with a frost streak; a wall shatters them, 63 base each, KRAKOOM; no wall 14) and RMB Shatterstorm (a sky
  strike on each cube where it stands, 30 base). Bot strings `ring D L H` and `wall alt D L H`; void_arm_check asserts
  the gather and the ordering (three cubes: wall 386 > thunder 184 > open 86)
- [x] Camera: a cued foe lets the framing lean up to 3.5 m (`FRAME_CUE_LEAN_MAX`) so the slide and the wall hit stay
  in view; `string_film --fps=N --tail=MS`
- [x] Clips: `awaken-combo-clips/26 Harpoon *` (grab, Shatterstorm, Slapshot into a wall)
- [x] Fitted ice (after fx-ice2): the row is spaced by each foe's fitted block (`ice_radius()`, `HARPOON_GAP` 0.15,
  `ICE_CORNER`), the hang finishes any carry and keeps the row iced, Slapshot stops a cube when its ice's face meets
  the wall (`wall_gap`), the wall hit says KER-SMASH! (breaker words KRSSSH-BOOM! / THWAKK!); ice_block_check holds
  every dummy's vertices inside its block after the gather, in the hang and mid-slide; `string_film --no-awaken`
- [ ] Zak's call: the endings sit behind a pause (Ice Cube keeps its line), not on Harpoon outright; hand-play the
  gather's speed and whether a wall past ~10 m (the slide's reach) should still count

## Round 47 c (feel-polish: audit 3's open items, then the whole game on film again)
Zak: "keep improving on whatever you see fit". `docs/feel-audit-2026-11-06b.md`; clips `awaken-combo-clips/28 Feel *`.
- [x] Meteor Fall: Molten Palm cues a foe it carries to a wall (`PALM_CUE_MS`), and a hang frames cued foes only
  (`camera_rig.FRAME_CUE_RANGE`): the splat stays whole in frame through the hang and the dive
- [x] Frost spear (designed): a ground stamp (brush ring 1.25 m + `frost_mark` cracks ~2.5 m), no 5 m frost floor
- [x] Spirit echo: 0.62 of the reach, a 1.4 m axe head and a thin ink line, on real time (gone by the next hit)
- [x] Hit stops: the vault's push-off (`VAULT_STOP` 0.06) and Harpoon's first latch (`LATCH_STOP` 0.035)
- [x] 32 strings re-filmed (`feel4_a/b/c`), coverage PASS (max 0.163); rhythm_check PASS
- [ ] Live Wire's hang with a far foe: the current runs off frame (cue Short Circuit's targets in the hang? Zak's call)
- [ ] Ice Cube pressed during Harpoon's gather finds nobody (the tentacles still carry them): combo-harpoon lane

## Round 47 d (fx-polygons: the last runtime polygons drawn)

- [x] Designed sheets for the polygons still on film (`gen_polygons.py`, `designed_polish.gd`): breaker dive trails
  (storm a lime bolt, void an ink smear), `Fx.burst` chips (rank-up), state tells (stone crust, frost rime, flame licks,
  arcs), Reap's mark as ink claw strokes, Fault Line, Black Ice / Flash Freeze, Meltdown, Tow Line, improv payoffs,
  drag mark, `Fx.soul`, last-kill flare; no crystals. See `docs/features/designed-fx.md` "fx-polygons"
- [x] Clips: `awaken-combo-clips/27 Polygons *`
- [ ] Trace the purple radial wedges round the hero on some breaker leaps; check the drag mark on film


## Round 48 (breaker-pairs: a second ending where it is compelling)
Zak: "start refining the breakers to be really flashy and awesome ... offer two breaker options", then "NOT everyone
needs a dual, but only when its truly compelling and awesome." `scripts/breaker_alt_fx.gd`, `docs/features/combo-breakers.md`
"Breaker pairs".
- [x] Meteor Fall / LMB Meteor Shower: a fireball on every foe the palm hit, wherever it went (scattered 310 vs 175;
  piled on a wall 628 vs 336)
- [x] Anvil / LMB Pinwheel: the kebab whirled round him in a twister and hurled into the nearest wall or pillar (wall
  519 vs 406; open 152 vs 406)
- [x] The autotest counts every window ending (`endings_n=`, `agent.sh check` fails short); Cold Front got its string
- [x] Cataclysm / LMB Tempest: a twister takes the crowd up its column, bolts blast each out, harder the more it holds
  (five 666 vs 524; two 144 vs 209). Bot string `alt L H L L H`
- [x] Skipped on purpose (combo-breakers.md says why): Avalanche, Collapse, Abyss, Flash Freeze, Eruption
- [x] Clips: `awaken-combo-clips/29 Breakers *` (Meteor Shower, Pinwheel, Tempest; filmed on top of breaker-spectacle)
- [ ] Zak's call: Pinwheel's wall splat lands on the top edge of the frame under the breaker callout banner (camera lean
  cap 3.5 m); Meteor Fall and Meteor Shower share the magma colour, so the prompt's two chips are both orange

## Round 48 b (breaker-spectacle: every breaker ending as a flashy comic beat)
Zak: "start refining the breakers to be really flashy and awesome", with wind and lightning as the bar. See
`docs/features/combo-breakers.md` "Round 48" and `docs/features/designed-fx.md` "Breaker spectacle".
- [x] The window: the endings' colours charge round the ring; a press sweeps the chosen ending's colour round it; a PERFECT flashes white with gold rays; the chips are bigger so they read at 800x450; the hang gets focus lines and a vignette. The hang's length is unchanged.
- [x] The landing, for every ending:
  - the negative in the element's colours, with halftone and speed lines;
  - a camera jolt and a crunch-then-exhale stop per family;
  - a burst behind the pile, speed lines (not for ice), a floor-wide spread and pillars shaking dust;
  - after-beats on the struck (arcs, smoke, mist, wisps);
  - one banner with the ending's name and its total.
  - Sheets: `tools/vfx_gen/gen_spectacle.py`. Check: `tests/breaker_spectacle_check.gd`.
- [x] Clips: `awaken-combo-clips/30 Spectacle *` (before / after boards and side-by-side clips)
- [ ] Shatterstorm and Slapshot's banner shows the name only: their damage lands later, through the blocks.
- [x] The banner drops to the bottom of the screen when a cued or wall-splatted foe is under it (Pinwheel's wall throw sat under it at the top edge)
- [ ] Wall-splat stars are not clearly verified on film: the palm's splat sits at the frame's edge.
- [ ] Zak: Cold Front's and Flash Freeze's small blue spoked stars (existing ice hit pops, in the before film too) may read as crystals

## Round 49 counter (kit grammar slot 9: the dash counter, Backlash and Ricochet)
Zak approved the kit grammar ("implement it"); slot 9 is a Smash-style counter on the dash. See
`docs/features/counter.md` and `docs/characters/kit-grammar.md` section 4.
- [x] Space into a foe's strike (its last 0.25 s before contact, aimed within 60 deg) is the counter: i-frames, a
  hitstop, a drawn violet parry flash (`tools/vfx_gen/gen_counter.py`), the attacker staggered and marked, then
  Backlash (KRRAK-SNAP!): the tentacle swings it up over him and slams it for 18. A dash with nothing coming is the dash
- [x] A perfect (last 0.1 s) opens the counter breaker window, one violet ending: Ricochet (KA-SPLATT!) hurls the
  attacker into the nearest foe or wall (30, x2.5 on a wall) and binds it; the breaker spectacle fires on its landing
- [x] Enemy bolts in the window are batted back at their shooter (x2 damage)
- [x] Swinging dummies: Settings "Dummies swing" / `--swing` (windup 0.7 s after he stands in front 0.5 s, 4 damage)
- [x] Check `tests/counter_check.gd` (in `agent.sh check`); bot string `counter D` (perfect, Ricochet into the crowd)
- [x] Clips: `awaken-combo-clips/31 Counter *`
- [ ] Zak's call: the bot turns swinging on for its counter string only; bolts get no Backlash or window; the counter
  window keeps the shared breaker rhythm; `--spar=` foes are counterable by design (melee windups) but not filmed

## Round 49 matrix (kit grammar section 3: one payoff rule per state, `docs/characters/kit-grammar.md`)
- [x] Matrix collapse (section 3): six states, one payoff rule each (Shatter, Arc, Burst, Snap, Juggle, Crater), any
  element's hit; the 18 old cells are Kit upgrades (`--kit=full`); one look per rule tinted by the hitter; MIX ELEMENTS
  lists the rules and the upgrades; `[improv]` per rule, `agent.sh check` runs a second autotest with `--kit=full`.
  Sheets `awaken-combo-clips/32 Matrix *`. `docs/features/element-matrix.md`

## Round 49 (kit-slots: the kit grammar's slot table in code)
Zak approved the kit grammar ("implement it"). The heretic's kit is now data a second character can fill in. See
`docs/features/kit-slots.md` and `docs/characters/kit-grammar.md` section 5.
- [x] `scripts/kit_slots.gd`: 10 groups, 24 slots (input shape, role, one-word tag, window). The heretic's card fills
  22 slots (the counter by its window, Ricochet); the dark x magma crossover is pending, and the meter has no move id. It also lists his
  route steps and the demoted upgrade. `KitSlots.of(Game.hero)`; the prince's card is a TODO with his obvious moves
- [x] The gate: Storm Pitch (`Dash H L`) is off unless `--kit=full` / `--kit=storm_pitch`. Rockslide's buried payoff
  was gated too, then put back in the base kit (Zak): Fault Line's x2 and the Crater rule need buried. The routing, the combo guide, the MOVES panel and `move_list_check` agree
- [x] The MOVES panel is laid out by slot group (role line, per-row tag, dim "upgrade" rows, pending slots), then ROUTE
  STEPS, UPGRADES and MIX ELEMENTS. The combo guide tags each row with its slot
- [x] Bot strings name their slot. The autotest prints `[kit] slots=22/22 windows=13/13 upgrades=0/0`
  (`--kit=full`: 37 strings, `upgrades=1/1`). `agent.sh check` runs both and asserts the line
- [x] `tests/kit_check.gd`: every slot filled with a routable move, shapes, ≤ 2 endings a window, ≤ 15 windows, ≤ 6
  crossovers on distinct pairs, every MOVES id on the card, every slot with a bot string, demoted moves reachable
  only with their gate
- [ ] Zak: Reap fills the mark slot at H L (the grammar says H; his H alone is the grab). Impale (Dash H H) has no
  window

## Round 49 dark-magma (kit grammar slot 8: the sixth crossover, Lava Leash / Hellseam)
Zak approved the kit grammar ("implement it"); dark x magma was its one empty crossover. See
`docs/features/void-element.md` "Crossovers" and `docs/features/combo-breakers.md` "Hellseam".
- [x] Lava Leash (L L L H L, `XL`, Molten Palm's free L): a tentacle to everyone the palm hit, wherever it went (the
  wall too), dragged back along the floor through a lava seam into a pile at his feet, paid by the metre (x1.6 off a
  wall); the seam erupts under the pile (SHLURK-FWOOM!): molten, bound
- [x] Its best situation differs from Galvanize's and Black Tide's (`tests/lava_leash_check.gd`, all three in each; in `agent.sh check`):
  palm's foes at mixed ranges by a wall 103 / 42 / 72; a spread crowd 7 m round him, unmarked 36 / 130 / 0; marked foes
  8-10 m off, no palm 0 / 67 / 96 (Lava Leash / Galvanize / Black Tide)
- [x] One ending, Hellseam (KRAKA-FWOOOM!): he dives on the pile, a crater harder the further each was dragged, then the
  eruption runs back out along every seam and catches whoever stands on one; the breaker spectacle's magma family
- [x] Designed sheets only (`tools/vfx_gen/gen_leash.py`: `lava_seam` ribbon, `leash_burst`), tentacles `void_tendril`,
  lava `designed_elements`; no polygons, no crystals. Bot string `wall spread L L L H L` (`spread` + `wall` lays the
  arc toward the wall); `endings_n=` counts Hellseam; element_shots `--only=leash`
- [x] Clips: `awaken-combo-clips/33 Dark-magma *`
- [ ] Zak's call: the tentacles glow pink-orange in the lava (purple washed with `electrify`); the move's clip plays at
  0.95 (was 1.1 in the first cut) so the pile's burst shows before his leap; Hellseam's far seam ends sit under the
  ending banner when the palm sent them to the back wall
- [x] `kit_slots.gd`: the heretic's `cross_dark_magma` slot filled with `XL` (the card is full: 23 slots)

## Round 49 wiki (the field guide rebuilt for the kit grammar)
Zak: "update the wiki with this new system and how it will grow, also update the heretic's wiki." The old wiki went with
the roguelike layer (499138a); this one is the game as it is now. See `docs/features/wiki.md`.
- [x] `docs/wiki/index.html`, one page with a left nav: Home (what it is, controls, breaker windows, the counter,
  Awakening, where it is going), the kit grammar (signature + three elements, six states, ten slot groups, windows,
  crossovers, upgrades, the empty card), the heretic's full card slot by slot (input, element, MOVES text, state, best
  situation, each ending's button, word, damage and best situation), route steps and Storm Pitch, Backlash / Ricochet
  and the swinging dummies, the Dragon Prince's card with TODOs, the six rules and the 18 upgrade cells, a changelog of
  rounds 43-49
- [x] `tools/wiki_data.gd` writes `docs/wiki/data.js` from kit_slots, move_list, hero_moves, BREAKERS + BREAKER_WORDS,
  RULES, kit.gd, counter.gd, training_dummy.gd; `python tools/wiki.py` runs it and checks `notes.js` covers every move
  and ending; `tests/wiki_check.gd` in `agent.sh check` fails on a stale data.js
- [x] Ten screenshots from `string_film -- --dir=wiki_film` and `heretic_shots` (the hero, the two-chip window, Galvanize,
  Harpoon's row, Lava Leash, Backlash's parry flash, one landing per breaker family), 28-53 KB each
- [x] `.github/workflows/wiki.yml` restored: a push to dev that touches `docs/wiki/` publishes it
- [ ] Zak: Backdraft's MOVES note says "Ice into storm" and `ELEMENT_OF.XW` is wind, while its card slot is dark x ice

## Round 50 environment (structure targeting, an easier Pinwheel, environmental beats)
Zak: "absolutely love the pinwheel! i think this should maybe be a bit easier to execute though. maybe just an
indicator to click on the structure for combos that require environment!" See `docs/features/environment.md`.
- [x] `scripts/env_target.gd`: the room's walls (segments), pillars (points) and torches; one pick per move for
  Pinwheel, Slapshot, Ricochet, Collapse, Meteor Fall's pile, Molten Palm's carry, Lava Leash's tear and the pillar
  slam; an inked bracket in the ending's colour plus floor chevrons (designed sheets, `tools/vfx_gen/gen_environment.py`),
  a dim dashed "too far" bracket when nothing is in reach
- [x] Click to choose: the cursor ray (or right stick) picks a structure in reach; the window's L / H is the trigger
- [x] Pinwheel easier: Impale (Dash H H) has its own window, Anvil (H) / Pinwheel (L), a pause window (15/15 windows)
- [x] Collapse throws into the picked structure (x1.6); a pillar hit cracks it and sheds chunks; wall hits leave a
  mark per element (capped at 14) and swing a torch nearby; hold H through H H's grab by a pillar for a pillar slam
- [x] `tests/env_target_check.gd` (in `agent.sh check`); bot strings `pillar H hold`, `wall alt D H H`; `[env]` line
- [x] Clips: `awaken-combo-clips/34 Environment *`
- [ ] Zak's call: Collapse's x1.6 into a structure; the pillar slam on a held H; the palm's too-far bracket; Meteor
  Fall's cursor only takes a structure with palm foes on it; Dash H H then a pause is now Pinwheel / Anvil, so a
  slow Dash H H L leaps instead of Backdraft
