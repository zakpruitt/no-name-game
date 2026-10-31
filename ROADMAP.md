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
- [ ] Boss pacing baseline: `--pace` also covers the boss room (time to kill the Warden, hero HP left) over a few seeds, numbers noted in ROADMAP

## Round 16 (feedback)
- [x] Combo callouts: landing a named combo (`player.COMBOS`: Triple Chop, Dash Stab, Launcher, Ground Breaker, Charged Slam, Cataclysm) plays a quiet tier sound (`combo_1..3`) and shows its name above the hero; pause menu gets a fixed MOVES list. Autotest prints `callouts=` and saves `autotest_callout.png`

## Round 17 (shaman rework)
- [x] Short Awakening: 8s flat (`player.awaken_duration`), no meter gain while Awakened (`Game.awaken_locked`), meter empties when it ends; Long Night removed (Night synergy is now Overflow + Phoenix Heart)
- [x] Hero levels: XP from kills, level-ups during the run, level shown on the HUD — `Game.LEVEL_XP` [4, 12, 24, 40, 60] (XP = enemy bones, so risen/split give none), `LEVEL_MAX` 6; each level +5 max HP (`player.level_hp`) and heals it; HUD "LV n" + thin XP bar; `--level=N` starts there; autotest prints `level= xp=`
- [x] Ascendancy at level 6: pick Wind (storm, light green), Earth (magma, volcanoes) or Water (ice); the path reshapes Awakening (colours, passive, finisher) — `scripts/ascendancy.gd` (`PATHS` tuning + effects), chosen on `ascend_menu.gd` at the first room clear after level 6. Wind: 1.25x speed, half dash cooldown, lightning every 3rd hit, finisher Tempest (pulling cyclone). Earth: 0.45x damage taken, heavy moves leave magma, finisher Eruption (volcano lobbing lava bombs). Water: hits chill, 4 hits freeze, frozen hits x1.5 and shatter, finisher Glacier (ice ring freezes all). `--ascend=wind|earth|water`, `tests/ascend_check.gd` PASS
- [ ] Element powers: reward powers tagged Wind/Earth/Water that the matching Ascendancy boosts (Water has no powers yet; Storm/Tremor/Ember could fold into Wind/Earth)
- [ ] Ascendancy feel pass by hand: is Earth's armor too safe, Water's freeze too strong vs elites, Wind's speed too twitchy?
- [x] Shaman look: recolour the Barbarian, rune-glowing dual axes, charms/feathers from primitives; ascended forms glow in their element — `tools/gen_shaman_texture.gd` recolours the palette atlas (grey wolf pelt, teal shirt, dark leather and beard, turquoise axe wraps) into `assets/hero/shaman_texture.png`; `scripts/hero_look.gd` adds hanging feathers, a bead-and-fang necklace and teal axe runes; Awakening is ancestral gold until an Ascendancy recolours it (with element motes). `tests/hero_preview.gd` renders the close-up
