extends RefCounted
## Foe data: each kind's model and overrides for enemy.gd's exported stats. In play only
## `--spar=<kind>` (scripts/spar.gd) spawns one; main.gd's `_spawn()` reads these. Tune here.
## `bar_height` (m above the feet, before model_scale) is where enemy_bars.gd draws the
## health bar: each comic model's head top in Idle_Combat plus 0.3 m,
## measured in Blender on the chunky blends (round 29). Missing = enemy_bars.HEAD_HEIGHT.
## `run_foot_speed` (m/s, before model_scale) is how fast a planted foot slides back on the comic
## run clip at 1x; enemy.gd plays the run at ground speed over it (`run_clip_speed()`). Measure it
## with tests/foe_stride_check.gd after any change to a foe's run clip.
## `attack_hit` (frame, 24 fps) is where the melee foes' keyed 1H_Melee_Attack_Chop lands (foe_cycles.py,
## round 38 b): enemy.chop_speed() plays it so that frame meets the windup's end (each at ~1x). Move it
## with the keys.

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "title": "skeleton minion", "bar_height": 2.2, "run_foot_speed": 3.51, "attack_hit": 14.0},
	"warrior": {"model": "Skeleton_Warrior", "title": "skeleton warrior", "bar_height": 2.4, "run_foot_speed": 2.40, "attack_hit": 19.0, "max_hp": 75.0, "move_speed": 2.8, "attack_damage": 16.0,
		"attack_windup": 0.8, "poise": 8.0, "model_scale": 1.15},
	"mage": {"model": "Skeleton_Mage", "title": "skeleton mage", "bar_height": 2.55, "run_foot_speed": 2.97, "max_hp": 24.0, "move_speed": 3.0, "attack_kind": "ranged",
		"attack_range": 10.0, "preferred_range": 7.0, "attack_damage": 12.0, "attack_windup": 0.9,
		"attack_recover": 0.5, "projectile_speed": 9.0},
	"rogue": {"model": "Skeleton_Rogue", "title": "skeleton rogue", "bar_height": 1.55, "run_foot_speed": 5.62, "attack_hit": 11.0, "max_hp": 28.0, "move_speed": 5.4, "attack_damage": 8.0,
		"attack_windup": 0.5, "attack_recover": 0.5, "flank": true, "dodge_chance": 0.5, "run_anim": "Running_C"},
	"archer": {"model": "Skeleton_Rogue", "title": "skeleton archer", "bar_height": 2.0, "run_foot_speed": 3.21, "max_hp": 22.0, "move_speed": 3.2, "attack_kind": "line",
		"attack_range": 13.0, "preferred_range": 10.0, "attack_damage": 14.0, "attack_windup": 1.1,
		"attack_recover": 0.9, "projectile_speed": 30.0, "run_anim": "Running_A"},
	"shield": {"model": "Skeleton_Minion", "title": "shield skeleton", "bar_height": 2.45, "run_foot_speed": 3.07, "attack_hit": 17.0, "max_hp": 40.0, "move_speed": 3.2, "attack_damage": 12.0,
		"attack_windup": 0.7, "shield": true, "model_scale": 1.05, "run_anim": "Walking_D_Skeletons"},
	# Meshy foes (tools/meshy/meshy.py build <kind>, docs/features/meshy-foes.md): no `model`, the GLB is assets/comic/<kind>.glb
	"brute": {"title": "brute", "bar_height": 2.75, "run_foot_speed": 3.58, "attack_hit": 24.0, "max_hp": 120.0, "move_speed": 2.4, "attack_damage": 22.0,
		"attack_windup": 1.0, "attack_recover": 0.9, "poise": 14.0},
	"cultist": {"title": "cultist", "bar_height": 2.15, "run_foot_speed": 2.27, "max_hp": 26.0, "move_speed": 3.2, "attack_kind": "ranged",
		"attack_range": 10.0, "preferred_range": 7.0, "attack_damage": 12.0, "attack_windup": 0.9,
		"attack_recover": 0.5, "projectile_speed": 9.0},
}
