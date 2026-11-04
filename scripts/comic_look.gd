class_name ComicLook
extends RefCounted
## The comic-book look (Game.comic_style): palette, model swap, clip names and
## lighting. See docs/features/comic-style.md. The tones are copied from
## vendor_src/shaman_redesign/comic_poc (comic_lib.shared_materials + each
## enemy_*.py's extras), keyed by the material names the GLBs carry.

const TOON_SHADER := "res://shaders/comic_toon.gdshader"
const EMIT_SHADER := "res://shaders/comic_emit.gdshader"
const MODEL_PATH := "res://assets/comic/%s.glb"
const PIECE_PATH := "res://assets/comic/dungeon/%s.glb"
const KAYKIT_PIECE_PATH := "res://assets/kaykit/dungeon/%s.glb"
const OUTLINE_SHADER := "res://shaders/outline.gdshader"

## Material name -> toon tones (comic_lib.toon's arguments, sRGB). Optional keys:
## hi (else = light), rim (else black), spot (0.075), inner (0.17).
const TONES := {
	"P_Skin": {"shadow": Color(0.36, 0.1, 0.14), "mid": Color(0.86, 0.46, 0.28), "light": Color(1, 0.75, 0.5), "hi": Color(1, 0.92, 0.74), "rim": Color(0.55, 0.26, 0.2), "brush": 0.1},
	"P_Socket": {"shadow": Color(0.012, 0.01, 0.02), "mid": Color(0.1, 0.03, 0.05), "light": Color(0.18, 0.06, 0.07), "brush": 0.05, "inner": 0.0},
	"P_Hair": {"shadow": Color(0.2, 0.24, 0.5), "mid": Color(0.62, 0.68, 0.86), "light": Color(0.95, 0.95, 0.92), "hi": Color(1, 1, 0.98), "rim": Color(0.25, 0.35, 0.6), "brush": 0.2, "inner": 0.2},
	"P_Iron": {"shadow": Color(0.05, 0.06, 0.14), "mid": Color(0.2, 0.25, 0.38), "light": Color(0.46, 0.54, 0.68), "hi": Color(0.86, 0.92, 1), "rim": Color(0.18, 0.3, 0.5), "brush": 0.16, "inner": 0.2},
	"P_Bronze": {"shadow": Color(0.2, 0.06, 0.02), "mid": Color(0.68, 0.34, 0.08), "light": Color(0.98, 0.68, 0.18), "hi": Color(1, 0.95, 0.56), "rim": Color(0.3, 0.16, 0.05), "brush": 0.14},
	"P_Leather": {"shadow": Color(0.1, 0.03, 0.03), "mid": Color(0.34, 0.14, 0.08), "light": Color(0.6, 0.32, 0.15), "rim": Color(0.15, 0.07, 0.04), "brush": 0.2},
	"P_Cloth": {"shadow": Color(0.02, 0.08, 0.16), "mid": Color(0.03, 0.32, 0.36), "light": Color(0.08, 0.6, 0.56), "hi": Color(0.34, 0.86, 0.72), "rim": Color(0.05, 0.24, 0.24), "brush": 0.28},
	"P_Trousers": {"shadow": Color(0.06, 0.05, 0.13), "mid": Color(0.2, 0.17, 0.32), "light": Color(0.42, 0.36, 0.5), "rim": Color(0.1, 0.1, 0.2), "brush": 0.24},
	# the hero: the black of his veins, the void arm and what it forges
	"P_Tendril": {"shadow": Color(0.1, 0.025, 0.22), "mid": Color(0.34, 0.1, 0.6), "light": Color(0.62, 0.34, 0.92), "rim": Color(0.5, 0.2, 0.8), "brush": 0.14},
	"P_VoidHard": {"shadow": Color(0.04, 0.012, 0.1), "mid": Color(0.15, 0.05, 0.3), "light": Color(0.31, 0.15, 0.52), "rim": Color(0.5, 0.2, 0.8), "brush": 0.14},
	"P_Blight": {"shadow": Color(0.015, 0.01, 0.03), "mid": Color(0.07, 0.035, 0.12), "light": Color(0.2, 0.12, 0.34), "rim": Color(0.3, 0.1, 0.5), "brush": 0.12},
	"P_Rock": {"shadow": Color(0.05, 0.02, 0.05), "mid": Color(0.2, 0.12, 0.16), "light": Color(0.42, 0.28, 0.28), "hi": Color(0.72, 0.55, 0.44), "rim": Color(0.8, 0.28, 0.03), "brush": 0.14, "inner": 0.22},
	# the axes' blades in the elements that have no blade of their own (AXE_INFUSIONS)
	"P_AxeWind": {"shadow": Color(0.05, 0.25, 0.14), "mid": Color(0.2, 0.6, 0.34), "light": Color(0.55, 0.92, 0.6), "hi": Color(0.92, 1, 0.88), "rim": Color(0.5, 1, 0.55), "brush": 0.1, "inner": 0.14},
	"P_Bone": {"shadow": Color(0.36, 0.17, 0.1), "mid": Color(0.8, 0.6, 0.36), "light": Color(0.98, 0.92, 0.72), "rim": Color(0.2, 0.15, 0.1), "brush": 0.14},
	"P_Ice": {"shadow": Color(0.08, 0.3, 0.72), "mid": Color(0.26, 0.62, 0.96), "light": Color(0.6, 0.9, 1), "hi": Color(0.98, 1, 1), "rim": Color(0.4, 0.7, 1), "brush": 0.08, "inner": 0.14},
	"P_Teeth": {"shadow": Color(0.4, 0.28, 0.16), "mid": Color(0.8, 0.7, 0.44), "light": Color(0.96, 0.9, 0.68), "brush": 0.08, "inner": 0.0},
	"P_Black": {"shadow": Color(0.012, 0.01, 0.02), "mid": Color(0.03, 0.02, 0.03), "light": Color(0.06, 0.05, 0.06), "brush": 0.05, "inner": 0.0},
	"P_Floor": {"shadow": Color(0.03, 0.03, 0.07), "mid": Color(0.09, 0.09, 0.16), "light": Color(0.17, 0.165, 0.26), "brush": 0.1, "inner": 0.0, "spot": 0.02},
	# env_kit.env_materials, multiplied by the mesh's per-stone `g` (see tone_by_g)
	"comic_floor": {"shadow": Color(0.042, 0.042, 0.085), "mid": Color(0.085, 0.085, 0.15), "light": Color(0.128, 0.125, 0.205), "brush": 0.06, "inner": 0.0, "spot": 0.015},
	"comic_floor_hi": {"shadow": Color(0.05, 0.05, 0.1), "mid": Color(0.1, 0.1, 0.17), "light": Color(0.168, 0.163, 0.26), "brush": 0.05, "inner": 0.0, "spot": 0.015},
	"comic_grout": {"shadow": Color(0.016, 0.016, 0.036), "mid": Color(0.036, 0.036, 0.07), "light": Color(0.066, 0.064, 0.118), "brush": 0.02, "inner": 0.0, "spot": 0.01},
	"comic_stone": {"shadow": Color(0.045, 0.045, 0.105), "mid": Color(0.125, 0.125, 0.235), "light": Color(0.225, 0.225, 0.365), "hi": Color(0.3, 0.3, 0.45), "rim": Color(0.06, 0.07, 0.16), "brush": 0.025, "inner": 0.12, "spot": 0.05},
	"comic_cap": {"shadow": Color(0.04, 0.04, 0.095), "mid": Color(0.11, 0.11, 0.21), "light": Color(0.195, 0.195, 0.32), "hi": Color(0.26, 0.26, 0.39), "rim": Color(0.05, 0.06, 0.14), "brush": 0.025, "inner": 0.1, "spot": 0.05},
	"comic_iron": {"shadow": Color(0.025, 0.025, 0.06), "mid": Color(0.09, 0.1, 0.18), "light": Color(0.2, 0.215, 0.33), "hi": Color(0.38, 0.41, 0.55), "rim": Color(0.08, 0.1, 0.2), "brush": 0.1, "inner": 0.16},
	"comic_wood": {"shadow": Color(0.04, 0.03, 0.07), "mid": Color(0.12, 0.09, 0.15), "light": Color(0.235, 0.165, 0.21), "hi": Color(0.31, 0.22, 0.25), "rim": Color(0.06, 0.04, 0.08), "brush": 0.2, "inner": 0.14},
	"comic_bone": {"shadow": Color(0.17, 0.11, 0.15), "mid": Color(0.42, 0.34, 0.33), "light": Color(0.68, 0.6, 0.5), "hi": Color(0.8, 0.72, 0.58), "rim": Color(0.12, 0.08, 0.08), "brush": 0.12, "inner": 0.12},
	"comic_banner": {"shadow": Color(0.22, 0.025, 0.06), "mid": Color(0.56, 0.07, 0.05), "light": Color(0.86, 0.2, 0.05), "hi": Color(0.96, 0.32, 0.07), "rim": Color(0.2, 0.03, 0.02), "brush": 0.22, "inner": 0.14},
	"comic_gold": {"shadow": Color(0.2, 0.07, 0.05), "mid": Color(0.55, 0.26, 0.06), "light": Color(0.82, 0.5, 0.12), "hi": Color(0.95, 0.7, 0.3), "rim": Color(0.2, 0.1, 0.02), "brush": 0.12, "inner": 0.12},
	"comic_void": {"shadow": Color(0.008, 0.008, 0.02), "mid": Color(0.016, 0.016, 0.036), "light": Color(0.028, 0.028, 0.06), "brush": 0.02, "inner": 0.0},
	# enemy_*.py extras
	"P_Rust": {"shadow": Color(0.14, 0.04, 0.03), "mid": Color(0.55, 0.24, 0.09), "light": Color(0.8, 0.45, 0.2), "hi": Color(1, 0.82, 0.55), "rim": Color(0.3, 0.12, 0.04), "brush": 0.3},
	"P_Wood": {"shadow": Color(0.15, 0.06, 0.06), "mid": Color(0.42, 0.23, 0.13), "light": Color(0.72, 0.47, 0.25), "hi": Color(0.95, 0.74, 0.44), "rim": Color(0.22, 0.1, 0.05), "brush": 0.32, "inner": 0.1},
	"P_Bomb": {"shadow": Color(0.02, 0.02, 0.05), "mid": Color(0.065, 0.065, 0.115), "light": Color(0.14, 0.145, 0.23), "hi": Color(0.34, 0.37, 0.52), "rim": Color(0.75, 0.24, 0.05), "brush": 0.12, "inner": 0.12},
	"P_Shroud": {"shadow": Color(0.08, 0.015, 0.06), "mid": Color(0.32, 0.05, 0.11), "light": Color(0.58, 0.12, 0.16), "hi": Color(0.84, 0.3, 0.24), "rim": Color(0.3, 0.05, 0.1), "brush": 0.16},
	"P_WardenIron": {"shadow": Color(0.04, 0.05, 0.11), "mid": Color(0.16, 0.19, 0.3), "light": Color(0.36, 0.42, 0.56), "hi": Color(0.72, 0.8, 0.92), "rim": Color(0.14, 0.24, 0.4), "brush": 0.16, "inner": 0.2},
	"P_Edge": {"shadow": Color(0.2, 0.24, 0.34), "mid": Color(0.55, 0.62, 0.72), "light": Color(0.9, 0.95, 1), "hi": Color(1, 1, 1), "rim": Color(0.3, 0.4, 0.5), "brush": 0.1, "inner": 0.1},
	"P_IronPlain": {"shadow": Color(0.05, 0.06, 0.14), "mid": Color(0.2, 0.25, 0.38), "light": Color(0.46, 0.54, 0.68), "hi": Color(0.86, 0.92, 1), "rim": Color(0.18, 0.3, 0.5), "brush": 0.16, "inner": 0.2},
	"P_Steel": {"shadow": Color(0.08, 0.1, 0.2), "mid": Color(0.3, 0.36, 0.5), "light": Color(0.56, 0.64, 0.76), "hi": Color(0.8, 0.86, 0.92), "rim": Color(0.26, 0.36, 0.5), "brush": 0.16, "inner": 0.1},
	"P_Coat": {"shadow": Color(0.05, 0.06, 0.36), "mid": Color(0.1, 0.15, 0.62), "light": Color(0.22, 0.32, 0.92), "hi": Color(0.52, 0.64, 1), "rim": Color(0.2, 0.16, 0.6), "brush": 0.16, "spot": 0.02},
	"P_Hat": {"shadow": Color(0.1, 0.05, 0.4), "mid": Color(0.2, 0.11, 0.68), "light": Color(0.36, 0.24, 0.95), "hi": Color(0.66, 0.52, 1), "rim": Color(0.32, 0.14, 0.62), "brush": 0.18, "spot": 0.02},
	"P_Wrap": {"shadow": Color(0.1, 0.02, 0.14), "mid": Color(0.32, 0.07, 0.28), "light": Color(0.58, 0.16, 0.4), "hi": Color(0.8, 0.34, 0.52), "rim": Color(0.26, 0.08, 0.24), "brush": 0.26, "inner": 0.14},
	"P_Forest": {"shadow": Color(0.03, 0.16, 0.1), "mid": Color(0.07, 0.36, 0.16), "light": Color(0.17, 0.6, 0.22), "hi": Color(0.48, 0.86, 0.38), "rim": Color(0.1, 0.3, 0.12), "brush": 0.2, "spot": 0.02},
	# the training dummy (enemy_dummy.py): pale canvas, red straps and gloves, straw rope, grey boots
	"P_Canvas": {"shadow": Color(0.44, 0.24, 0.2), "mid": Color(0.86, 0.7, 0.48), "light": Color(1, 0.92, 0.72), "hi": Color(1, 0.98, 0.86), "rim": Color(0.5, 0.3, 0.2), "brush": 0.22},
	"P_BagRed": {"shadow": Color(0.26, 0.02, 0.07), "mid": Color(0.7, 0.08, 0.09), "light": Color(0.96, 0.22, 0.13), "hi": Color(1, 0.5, 0.32), "rim": Color(0.32, 0.04, 0.06), "brush": 0.16},
	"P_Rope": {"shadow": Color(0.3, 0.14, 0.05), "mid": Color(0.72, 0.5, 0.2), "light": Color(0.96, 0.8, 0.4), "rim": Color(0.3, 0.16, 0.05), "brush": 0.24},
	"P_Boot": {"shadow": Color(0.12, 0.07, 0.1), "mid": Color(0.38, 0.27, 0.3), "light": Color(0.62, 0.5, 0.48), "rim": Color(0.2, 0.12, 0.14), "brush": 0.2},
	"P_Lining": {"shadow": Color(0.08, 0.01, 0.14), "mid": Color(0.28, 0.05, 0.34), "light": Color(0.5, 0.12, 0.5), "rim": Color(0.2, 0.05, 0.2), "brush": 0.2},
}
## Material name -> flat stepped colour [low, high, mid] (comic_lib.emit, sRGB). Without a mid it sits between them.
const EMITS := {
	"P_Fire": [Color(0.95, 0.1, 0.02), Color(1, 0.9, 0.2)],
	"P_Lava": [Color(1, 0.28, 0.02), Color(1, 0.86, 0.2)],
	"P_Bolt": [Color(0.2, 0.55, 1), Color(0.98, 1, 0.92)],
	"P_Wind": [Color(0.2, 0.85, 0.5), Color(0.9, 1, 0.8)],
	"P_Spirit": [Color(0.05, 0.75, 0.72), Color(0.86, 1, 0.86)],
	# the hero's own: the darkness in him is violet, and his elements fall to it in their lowest tone
	"P_Fracture": [Color(0.34, 0.1, 0.62), Color(0.82, 0.55, 1)],
	"P_LavaDark": [Color(0.2, 0.04, 0.28), Color(1, 0.86, 0.2), Color(1, 0.28, 0.02)],
	"P_StormGreen": [Color(0.02, 0.25, 0.16), Color(0.86, 1, 0.72), Color(0.16, 0.85, 0.38)],
	"P_EyeWhite": [Color(0.965, 0.93, 0.82), Color(0.965, 0.93, 0.82)],
	"P_EyeBlue": [Color(0.1, 0.45, 1), Color(0.7, 0.95, 1)],
	"P_Pupil": [Color(0.012, 0.01, 0.02), Color(0.012, 0.01, 0.02)],
	"P_Necro": [Color(0.2, 0.85, 0.3), Color(0.9, 1, 0.55)],
	"P_Hot": [Color(1, 0.72, 0.12), Color(1, 1, 0.78)],
	"P_Arcane": [Color(0.55, 0.16, 1), Color(0.96, 0.86, 1)],
	"P_Ember": [Color(1, 0.42, 0.05), Color(1, 0.93, 0.55)],
	# comic_lib.flat: one colour
	"P_String": [Color(0.96, 0.92, 0.74), Color(0.96, 0.92, 0.74)],
	"P_Under": [Color(0.13, 0.05, 0.3), Color(0.13, 0.05, 0.3)],
	"comic_fire": [Color(0.95, 0.16, 0.03), Color(1, 0.88, 0.28)],
	"comic_ink": [Color(0.035, 0.032, 0.07), Color(0.035, 0.032, 0.07)],
	"comic_wash": [Color(0.028, 0.027, 0.06), Color(0.028, 0.027, 0.06)],
}
## A kind whose script defines a shared material name differently.
const KIND_TONES := {
	"rogue": {"P_Steel": {"shadow": Color(0.08, 0.1, 0.2), "mid": Color(0.32, 0.38, 0.52), "light": Color(0.62, 0.7, 0.82), "hi": Color(0.88, 0.93, 1), "rim": Color(0.26, 0.36, 0.5), "brush": 0.12, "inner": 0.08}},
	# His weapons grow out of the limb, so they carry its painted magenta, not the old hero's violet.
	"heretic": {
		"P_Tendril": {"shadow": Color(0.12, 0.012, 0.16), "mid": Color(0.44, 0.07, 0.4), "light": Color(0.68, 0.15, 0.58), "rim": Color(0.62, 0.2, 0.62), "brush": 0.14},
		"P_VoidHard": {"shadow": Color(0.05, 0.01, 0.07), "mid": Color(0.2, 0.04, 0.2), "light": Color(0.4, 0.1, 0.38), "rim": Color(0.62, 0.2, 0.62), "brush": 0.14},
	},
}
## Model name -> clip the game asks for -> clip it has ("" = keep what's playing,
## the clip already covers that beat). Only consulted when the model lacks the clip
## asked for, so a re-export that adds one wins by itself.
const CLIPS := {
	"heretic": {"Throw": "Ab_L2"},
	"necromancer": {"Running_A": "Walking_D_Skeletons", "Spawn_Ground_Skeletons": "Idle_Combat"},
	"warden": {
		"Spawn_Ground_Skeletons": "Idle_Combat",
		"Hit_B": "Hit_A",
		"Lie_StandUp": "Idle_Combat",
		# boss.gd's beats inside Attack_Slam / Attack_Nova / Attack_Cage
		"Jump_Idle": "",
		"Jump_Land": "",
		"Spellcast_Shoot": "",
	},
}
## The hero: the Meshy heretic (assets/comic/heretic.glb), one painted texture.
const HERETIC := "heretic"
## Game.hero_model -> the GLB the HERETIC kind loads (assets/comic/<file>.glb). Every model
## keeps the same rig contract, clips and material name, so everything keyed by HERETIC
## (tones, clips, heretic_rig.gd) works for each. Default: Game.HERO_DEFAULT ("chibi").
const HERETIC_MODELS := {"heretic": "heretic", "chibi": "heretic_chibi"}
## Materials drawn from their own texture through the cut tones, not from a TONES palette.
const PAINTED := {"P_HereticPaint": {"shadow": Color(0.42, 0.38, 0.56), "mid": Color(0.8, 0.77, 0.86), "light": Color(1.0, 1.0, 1.0), "brush": 0.12}}
## How much further one axis must lead before the run changes clip: on a diagonal a cursor
## nudge would otherwise flip between two clips every frame.
const RUN_STICK := 1.25
## id in player.MOVES -> its Ab_ clip. `frames` is the heretic's clip length in HERO_CLIP_FPS
## frames (length = frames / HERO_CLIP_FPS) and `hit` its contact frame: the last frame his
## weapon hand still moves at HERO_CONTACT_SPEED of the swing's peak, where the swing arrives
## (measured off the tracks by tests/comic_check.gd). old is the KayKit clip's length in s, the
## time base MOVES' fractions were tuned against.
const HERO_CLIP_FPS := 30.0  # heretic_bake.py resampled the shaman's 24 fps keys to 30, one hold frame first
const HERO_CONTACT_SPEED := 0.4
const HERO_MOVES := {
	"L1": {"clip": "Ab_L1", "hit": 11, "frames": 31, "old": 1.0},
	"L2": {"clip": "Ab_L2", "hit": 12, "frames": 33, "old": 1.3667},
	"L3": {"clip": "Ab_L3", "hit": 24, "frames": 56, "old": 1.2667},
	"DL": {"clip": "Ab_DL", "hit": 12, "frames": 61, "old": 1.6},
	"AL1": {"clip": "Ab_AL1", "hit": 11, "frames": 30, "old": 1.0},
}
## Hand bone -> the piece of the hero's axe at its head. His axes are skinned into one
## rig, so weapon trails need something that follows the hand (hero_blades).
## The void arm's shapes: the meshes each shows, the axe's and the others' own element on the arm with them.
const HERO_FORMS := {
	"axe": ["axe_void_haft", "axe_void_blade", "axe_void_edge", "axe_void_core"],
	"hammer": ["hammer_void_haft", "hammer_void_head", "hammer_void_rock", "hammer_void_lava"],
	"spear": ["spear_void_haft", "spear_void_collar", "spear_void_ice"],
	"hand": [],
}
## The shape each move asks for; anything not here is the axe.
const HERO_MOVE_FORMS := {"L2": "spear", "DL": "spear", "L3": "hammer", "CH": "hammer", "GR": "hand", "VS": "hand",
	"EF": "spear", "IP": "spear", "IJ": "hand", "IS": "hand", "EA": "hand", "EM": "hand", "EV": "hand", "EC": "hand", "EE": "hand", "EW": "hand",
	"VR": "hand", "VD": "hand", "OW": "hand", "TW": "hand"}
const VOID_COLOR := Color(0.62, 0.34, 0.92)
const HERO_AXES := {"hand.r": "axe_void_blade"}
const HERO_AXE_EDGES := {"hand.r": "axe_void_edge"}
## His spirit axe is the storm: its aura and floor mark are wind's, in its own materials.
const HERO_AURA_AS := {"spirit": "wind"}
## Element -> the blade and edge materials both axes take (infuse_axes).
const AXE_INFUSIONS := {
	"spirit": ["P_VoidHard", "P_StormGreen"],
	"wind": ["P_AxeWind", "P_Wind"],
	"earth": ["P_Rock", "P_Lava"],
	"water": ["P_Ice", "P_Bolt"],
}
const AXE_AURA := preload("res://scripts/comic_axe_aura.gd")
## Fidgets he plays in turn when left standing, and the stance a fight keeps him in.
const HERO_FIDGETS := ["Idle_Heft", "Idle_Listen", "Idle_Swing"]
const HERO_READY := "Idle_Ready"
## Of the motes circling him: at full size they outshine the veins they should echo.
const HERO_ORBIT_SIZE := 0.5
const READY_HOLD := 3.0  # s in the guard after his last attack or hit
const FIDGET_EVERY := 8.0  # s standing relaxed between fidgets
## Dungeon materials that get an ink hull, and how wide in px (env_kit.HULL, scaled so
## stone is 1.5 px). Floors and seam-core materials have none: their ink is geometry.
const PIECE_INK_PX := {"comic_stone": 1.5, "comic_cap": 1.5, "comic_wood": 1.2, "comic_banner": 1.2,
	"comic_gold": 1.2, "comic_iron": 1.0, "comic_bone": 1.0, "comic_fire": 1.0}
const PIECE_INK_PUSH := 0.04  # m, as Fx.COMIC_INK_PUSH
## On every table's `inner`. The POC's values were chosen for close-up renders; at the game's
## camera the same facing ratio covers most of a small model in ink.
const INNER_SCALE := 0.5
## Model name -> scale on its rig node. enemy.gd's model_scale also sizes collision, so
## it stays as tuned; the Warden is modelled at full size (3.2 m) where the KayKit boss
## relied on model_scale 1.8. The others match KayKit's height (~2.2 m bounds) as built.
const RIG_SCALE := {"warden": 1.0 / 1.8}
## Foes in the hero's hand (round 29): the chibi hero's shadow is his paint times
## PAINTED's shadow, a cool lilac at about half value, while the kit's foe tables shade
## into deep warm browns. Every foe toon material (any kind but HERETIC) moves its shadow
## FOE_SHADE_MATCH of the way to mid * that tint, so both sides of a fight step into the
## same shadow. Emits and dungeon pieces are left alone. 0.8 (was 0.5): side-lit from 90 degrees
## off the sun (`foe_shots.gd -- --side`), bone's shadow/mid ratio comes to (0.43, 0.36, 0.50)
## against the hero's (0.42, 0.38, 0.56); at 0.5 it was (0.43, 0.33, 0.42) and still read brown.
const FOE_SHADE_MATCH := 0.8
## Used (with a warning) for a material the tables don't know yet.
const FALLBACK_TONE := "P_Trousers"
## Every line and solid black. Near the floor's own shadow tone rather than true black:
## at the game's camera black lines read as heavy and clunky.
const INK := Color(0.035, 0.032, 0.07)

# comic_lib.comic_scene, converted: Blender energy / PI (a sun of strength E gives
# E / PI radiance), directions from its Euler angles, Blender (x, y, z) -> Godot
# (x, z, -y), so shadows fall up and right on screen as in the renders.
const BACKGROUND := Color(0.05, 0.05, 0.1)
const AMBIENT := Color(0.3, 0.3, 0.5)
const AMBIENT_ENERGY := 0.5
const KEY_DIR := Vector3(0.291, -0.754, -0.589)
const KEY_ENERGY := 1.146
const KEY_COLOR := Color(1.0, 0.97, 0.9)  # linear, as Blender's
const FILL_DIR := Vector3(-0.476, -0.309, 0.824)
const FILL_ENERGY := 0.3  # the POC's 0.134 drops under `spot` in Godot: shadow sides went solid black
const FILL_COLOR := Color(0.55, 0.62, 1.0)  # linear

static var _mats := {}  # material name -> shared ShaderMaterial, so every enemy batches
static var _warned := {}
static var _scenes := {}
static var _pieces := {}
static var _piece_ink := {}  # width -> shared outline ShaderMaterial


## The comic model for `kind`, or null (flag off, or no GLB yet: caller keeps KayKit).
static func scene(kind: String) -> PackedScene:
	if not Game.comic_style:
		return null
	var file := kind
	if kind == HERETIC:
		file = HERETIC_MODELS.get(Game.hero_model, HERETIC)
	if not _scenes.has(file):
		var path := MODEL_PATH % file
		_scenes[file] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[file]


## A new comic dungeon piece, or null (flag off, or no GLB: caller keeps KayKit).
static func comic_piece(piece_name: String) -> Node3D:
	if not Game.comic_style:
		return null
	if not _pieces.has(piece_name):
		var path := PIECE_PATH % piece_name
		_pieces[piece_name] = load(path) if ResourceLoader.exists(path) else null
	if _pieces[piece_name] == null:
		return null
	var n: Node3D = _pieces[piece_name].instantiate()
	apply(n)
	return n


## A new dungeon piece: comic when flagged and present, else KayKit's. Same names,
## sizes and pivots, so callers don't care which.
static func piece(piece_name: String) -> Node3D:
	var n := comic_piece(piece_name)
	return n if n != null else load(KAYKIT_PIECE_PATH % piece_name).instantiate()


## The clip to play on this model for a clip name the game asks for.
static func hero_kind() -> String:
	return HERETIC


## A PAINTED material: the GLB's texture lit through comic_toon's cut tones.
static func painted(src: BaseMaterial3D) -> ShaderMaterial:
	# per texture too: the heretic models share a material name but not their paint
	var key := "painted/%s/%s" % [src.resource_name, src.albedo_texture.resource_path if src.albedo_texture else ""]
	if _mats.has(key):
		return _mats[key]
	var t: Dictionary = PAINTED[src.resource_name]
	var m := ShaderMaterial.new()
	m.shader = load(TOON_SHADER)
	m.set_shader_parameter("paint", src.albedo_texture)
	m.set_shader_parameter("ink_color", INK)
	m.set_shader_parameter("shadow_color", t.shadow)
	m.set_shader_parameter("mid_color", t.mid)
	m.set_shader_parameter("light_color", t.light)
	m.set_shader_parameter("hi_color", t.light)
	m.set_shader_parameter("brush", t.brush)
	m.set_shader_parameter("inner", 0.17 * INNER_SCALE)
	m.set_shader_parameter("receive_shadow", 0.0)
	_mats[key] = m
	return m


static func clip(player: AnimationPlayer, kind: String, wanted: String) -> String:
	if player.has_animation(wanted):
		return wanted
	return CLIPS.get(kind, {}).get(wanted, wanted)


## The hero's run for travelling along `dir` while facing `facing`. `playing` is kept near a diagonal.
static func run_clip(dir: Vector3, facing: Vector3, playing: String) -> String:
	var ahead := dir.dot(facing)
	var left := dir.dot(Vector3.UP.cross(facing))
	var along := absf(ahead) > absf(left)
	if playing in ["Run_F", "Run_B"]:
		along = absf(ahead) * RUN_STICK > absf(left)
	elif playing in ["Strafe_L", "Strafe_R"]:
		along = absf(ahead) > absf(left) * RUN_STICK
	if along:
		return "Run_F" if ahead >= 0.0 else "Run_B"
	return "Strafe_L" if left >= 0.0 else "Strafe_R"


static func is_run_clip(clip: String) -> bool:
	return clip in ["Run_F", "Run_B", "Strafe_L", "Strafe_R"]


## A MOVES entry moved onto its Ab_ clip, `length` s long: the first hit lands on the
## hit frame, and everything after it (more hits, cancel, end) keeps its time after the
## hit; whatever's before it stretches with the wind-up. `base_hit` is MOVES' own first
## hit. `leap` (VOID_ELEMENT.BREAKERS) lands in move.leap.
static func retime(id: String, move: Dictionary, length: float, base_hit: float, leap := -1.0) -> void:
	var h: Dictionary = HERO_MOVES[id]
	var hit: float = float(h.hit) / h.frames
	var at := func(x: float) -> float:
		if x <= base_hit:
			return x * hit / base_hit
		return hit + (x - base_hit) * h.old / length
	move.anim = h.clip
	move.hits = move.hits.map(at)
	move.cancel = at.call(move.cancel)
	move.end = at.call(move.end)
	if move.has("hop"):
		move.hop = [at.call(move.hop[0]), at.call(move.hop[1]), move.hop[2]]
	if leap >= 0.0:
		move.leap = at.call(leap)


## Invisible stand-ins riding the hero's hands, from the grip to the axe head, for
## weapon_trail.gd (its longest axis is the blade). Never drawn: layers 0.
static func hero_blades(model: Node3D) -> Array[MeshInstance3D]:
	var made: Array[MeshInstance3D] = []
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for bone: String in HERO_AXES:
		var i := skel.find_bone(bone)
		var head: MeshInstance3D = model.find_child(HERO_AXES[bone], true, false)
		if i < 0 or head == null:
			continue
		var tip: Vector3 = skel.get_bone_global_rest(i).affine_inverse() * head.mesh.get_aabb().get_center()
		var blade := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.02, tip.length(), 0.02)
		blade.mesh = box
		blade.layers = 0
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blade.set_meta("no_ghost", true)
		blade.position = tip * 0.5
		blade.basis = Basis(Quaternion(Vector3.UP, tip.normalized()))
		var hand := BoneAttachment3D.new()
		hand.bone_name = bone
		skel.add_child(hand)
		hand.add_child(blade)
		made.append(blade)
	return made


## The element on the hero's axe: blade and edge recoloured, tongues along the edge, motes
## behind the swing and a mark where the blade scrapes the floor. Returns the auras so the caller can
## free them.
static func infuse_axes(model: Node3D, element: String) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var aura_as: String = HERO_AURA_AS.get(element, element)
	var meshes := AXE_AURA.build_meshes(aura_as)
	for bone: String in HERO_AXES:
		var i := skel.find_bone(bone)
		var bit: MeshInstance3D = model.find_child(HERO_AXES[bone], true, false)
		var edge: MeshInstance3D = model.find_child(HERO_AXE_EDGES[bone], true, false)
		if i < 0 or bit == null or edge == null:
			continue
		_axe_material(bit, AXE_INFUSIONS[element][0])
		_axe_material(edge, AXE_INFUSIONS[element][1])
		var to_hand := skel.get_bone_global_rest(i).affine_inverse()
		var aura: BoneAttachment3D = AXE_AURA.new()
		aura.bone_name = bone
		skel.add_child(aura)
		aura.setup(aura_as, meshes, _along_edge(edge.mesh, to_hand), to_hand * bit.mesh.get_aabb().get_center(), model)
		made.append(aura)
	return made


## A skinned mesh's vertices in the hand's space, ordered along the edge.
static func _along_edge(mesh: Mesh, to_hand: Transform3D) -> PackedVector3Array:
	var verts: Array = Array(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var axis := mesh.get_aabb().get_longest_axis_index()
	verts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a[axis] < b[axis])
	var out := PackedVector3Array()
	for v: Vector3 in verts:
		out.append(to_hand * v)
	return out


## Swap a surface's comic material, keeping its ink hull. Headless has neither (see apply).
static func _axe_material(mi: MeshInstance3D, mat_name: String) -> void:
	var was := mi.get_surface_override_material(0)
	if was == null:
		return
	var mat: ShaderMaterial = material(mat_name).duplicate()
	mat.next_pass = was.next_pass
	mi.set_surface_override_material(0, mat)


## Scale the rig under the model's root (the root belongs to model_scale and _squash).
static func fit(model: Node3D, kind: String) -> void:
	if RIG_SCALE.has(kind):
		for child in model.get_children():
			if child is Node3D:
				child.scale *= RIG_SCALE[kind]


## The shared comic material for a GLB material name.
static func material(mat_name: String, kind := "") -> ShaderMaterial:
	var override: Dictionary = KIND_TONES.get(kind, {})
	var foe := kind != "" and kind != HERETIC and not EMITS.has(mat_name)
	var key := kind + "/" + mat_name if override.has(mat_name) else ("foe/" + mat_name if foe else mat_name)
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	if EMITS.has(mat_name):
		var c: Array = EMITS[mat_name]
		m.shader = load(EMIT_SHADER)
		m.set_shader_parameter("low_color", c[0])
		m.set_shader_parameter("mid_color", c[2] if c.size() > 2 else (c[0] as Color).lerp(c[1], 0.55))
		m.set_shader_parameter("high_color", c[1])
	else:
		if not known_material(mat_name) and not _warned.has(mat_name):
			_warned[mat_name] = true
			push_warning("ComicLook: no tones for material %s" % mat_name)
		var t: Dictionary = override.get(mat_name, TONES.get(mat_name, TONES[FALLBACK_TONE]))
		m.shader = load(TOON_SHADER)
		m.set_shader_parameter("ink_color", INK)
		m.set_shader_parameter("shadow_color", foe_shadow(t) if foe else t.shadow)
		m.set_shader_parameter("mid_color", t.mid)
		m.set_shader_parameter("light_color", t.light)
		m.set_shader_parameter("hi_color", t.get("hi", t.light))
		m.set_shader_parameter("rim_color", t.get("rim", Color.BLACK))
		m.set_shader_parameter("brush", t.brush)
		m.set_shader_parameter("spot", t.get("spot", 0.075))
		m.set_shader_parameter("inner", t.get("inner", 0.17) * INNER_SCALE)
		var is_piece := mat_name.begins_with("comic_")
		m.set_shader_parameter("tone_by_g", 1.0 if is_piece else 0.0)
		m.set_shader_parameter("receive_shadow", 1.0 if is_piece else 0.0)
	if PIECE_INK_PX.has(mat_name):
		m.next_pass = _piece_outline(PIECE_INK_PX[mat_name])
	_mats[key] = m
	return m


## A foe tone's shadow moved FOE_SHADE_MATCH towards the hero's (see FOE_SHADE_MATCH).
static func foe_shadow(t: Dictionary) -> Color:
	var hero: Color = PAINTED.P_HereticPaint.shadow
	var like_hero := Color(t.mid.r * hero.r, t.mid.g * hero.g, t.mid.b * hero.b)
	return (t.shadow as Color).lerp(like_hero, FOE_SHADE_MATCH)


static func _piece_outline(width: float) -> ShaderMaterial:
	if not _piece_ink.has(width):
		var o := ShaderMaterial.new()
		o.shader = load(OUTLINE_SHADER)
		o.set_shader_parameter("width_px", width)
		o.set_shader_parameter("outline_color", INK)
		o.set_shader_parameter("depth_push", PIECE_INK_PUSH)
		_piece_ink[width] = o
	return _piece_ink[width]


## Swap every surface under `root` to its comic material. Call before Fx.outline,
## which adds the ink hull to whatever is active.
static func apply(root: Node, kind := "") -> void:
	if DisplayServer.get_name() == "headless":
		return  # like Fx.outline: the dummy renderer errors on shared override materials at exit
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null:
				var look: Material = painted(src) if PAINTED.has(src.resource_name) else material(src.resource_name, kind)
				mi.set_surface_override_material(i, look)


## Every GLB material name under `root` (imported names, works headless).
static func material_names(root: Node) -> Array:
	var names := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name not in names:
				names.append(src.resource_name)
	return names


static func known_material(mat_name: String) -> bool:
	return TONES.has(mat_name) or EMITS.has(mat_name) or PAINTED.has(mat_name)


## comic_lib.comic_scene: flat dark indigo, untonemapped, one hard sun with real
## cast shadows and a weak blue fill. No glow: glow is drawn, not lit. Toon materials
## ignore the ambient; it's only there so KayKit pieces under the flag stay readable.
static func build_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	var key := DirectionalLight3D.new()
	key.basis = Basis.looking_at(KEY_DIR, Vector3.UP)
	key.light_energy = KEY_ENERGY
	key.light_color = KEY_COLOR.linear_to_srgb()
	key.shadow_enabled = true
	key.shadow_blur = 0.0
	key.directional_shadow_max_distance = 40.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.basis = Basis.looking_at(FILL_DIR, Vector3.UP)
	fill.light_energy = FILL_ENERGY
	fill.light_color = FILL_COLOR.linear_to_srgb()
	parent.add_child(fill)


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_mats.clear()
	_scenes.clear()
	_pieces.clear()
	_piece_ink.clear()
