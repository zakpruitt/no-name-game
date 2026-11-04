extends RefCounted
## Foe data: each kind's model and overrides for enemy.gd's exported stats,
## and the Bone Warden's (attack timings live in boss.gd's ATTACKS). Nothing
## spawns them outside tests for now; main.gd's `_spawn()` / `_spawn_boss()`
## read these. Tune here.
## `bar_height` (m above the feet, before model_scale) is where enemy_bars.gd draws the
## health bar: each comic model's head top in Idle_Combat plus 0.3 m (the bomber: its bomb, which rides behind and above the skull from the game camera),
## measured in Blender on the chunky blends (round 29). Missing = enemy_bars.HEAD_HEIGHT.

const TYPES := {
	"minion": {"model": "Skeleton_Minion", "title": "skeleton minion", "bar_height": 2.2},
	"warrior": {"model": "Skeleton_Warrior", "title": "skeleton warrior", "bar_height": 2.4, "max_hp": 75.0, "move_speed": 2.8, "attack_damage": 16.0,
		"attack_windup": 0.8, "poise": 8.0, "model_scale": 1.15},
	"mage": {"model": "Skeleton_Mage", "title": "skeleton mage", "bar_height": 2.4, "max_hp": 24.0, "move_speed": 3.0, "attack_kind": "ranged",
		"attack_range": 10.0, "preferred_range": 7.0, "attack_damage": 12.0, "attack_windup": 0.9,
		"attack_recover": 0.5, "projectile_speed": 9.0},
	"rogue": {"model": "Skeleton_Rogue", "title": "skeleton rogue", "bar_height": 1.55, "max_hp": 28.0, "move_speed": 5.4, "attack_damage": 8.0,
		"attack_windup": 0.45, "attack_recover": 0.5, "flank": true, "dodge_chance": 0.5, "run_anim": "Running_C"},
	"archer": {"model": "Skeleton_Rogue", "title": "skeleton archer", "bar_height": 2.0, "max_hp": 22.0, "move_speed": 3.2, "attack_kind": "line",
		"attack_range": 13.0, "preferred_range": 10.0, "attack_damage": 14.0, "attack_windup": 1.1,
		"attack_recover": 0.9, "projectile_speed": 30.0, "run_anim": "Running_A",
		"cloth_color": Color(0.22, 0.42, 0.3)},
	"shield": {"model": "Skeleton_Minion", "title": "shield skeleton", "bar_height": 2.45, "max_hp": 40.0, "move_speed": 3.2, "attack_damage": 12.0,
		"attack_windup": 0.7, "shield": true, "model_scale": 1.05, "run_anim": "Walking_D_Skeletons"},
	"necromancer": {"model": "Skeleton_Mage", "title": "necromancer", "bar_height": 2.8, "max_hp": 34.0, "move_speed": 2.8, "attack_kind": "raise",
		"attack_range": 14.0, "preferred_range": 11.0, "attack_damage": 8.0, "attack_windup": 1.2,
		"attack_recover": 0.6, "projectile_speed": 8.0, "cloth_color": Color(0.1, 0.13, 0.1),
		"raise_count": 2, "raise_cooldown": 5.0},
	"bomber": {"model": "Skeleton_Minion", "title": "bomber", "bar_height": 2.3, "max_hp": 26.0, "move_speed": 4.2, "attack_kind": "bomb",
		"attack_range": 2.6, "attack_damage": 22.0, "attack_windup": 1.5, "blast_radius": 3.2,
		"blast_enemy_damage": 40.0, "model_scale": 0.9, "run_anim": "Running_C",
		"body_tint": Color(1.0, 0.62, 0.42)},
}
const BOSS := {"model": "Skeleton_Warrior", "max_hp": 700.0, "move_speed": 3.0, "model_scale": 1.8,
	"hit_freeze": 0.03, "run_anim": "Walking_D_Skeletons"}
