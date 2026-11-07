extends RefCounted
## Right click on the void arm: L picks the element (axe storm, spear ice, hammer magma), right click
## has the tentacle do that element's thing, and right click in the slow-motion window is the breaker.
## See docs/features/void-element.md.
## player.gd routes (void_route) and calls fire() on a move's first hit; void_grab.gd holds the seized
## foes and calls zap() and breaker_impact().

const FOES := preload("res://scripts/foes.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const COMIC_FIST := preload("res://scripts/comic_fist.gd")
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const THROWN := preload("res://scripts/thrown_foe.gd")
const BIND := preload("res://scripts/floor_bind.gd")
const SPEAR := preload("res://scripts/frost_spear.gd")
const DARK := preload("res://scripts/dark_fx.gd")
const COMIC_BOULDER := preload("res://scripts/comic_boulder.gd")  # crossover looks (round 37)
const COMIC_FAULT := preload("res://scripts/comic_fault.gd")
const COMIC_STEAM := preload("res://scripts/comic_steam.gd")
const COMIC_FREEZE := preload("res://scripts/comic_freeze_over.gd")
const COMIC_ARC := preload("res://scripts/comic_arc.gd")
const LIVE_CURRENT := preload("res://scripts/live_current.gd")
const COMIC_BOLT := preload("res://scripts/comic_bolt.gd")
const COMIC_HAIL := preload("res://scripts/comic_hail.gd")  # three-element looks (round 37, second pass)
const COMIC_MELT := preload("res://scripts/comic_melt.gd")
const COMIC_ERUPT := preload("res://scripts/comic_erupt.gd")
const COMIC_IMPALE := preload("res://scripts/comic_impale.gd")
const COMIC_BACKDRAFT := preload("res://scripts/comic_backdraft.gd")
const COMIC_ANVIL := preload("res://scripts/comic_anvil.gd")
const COMIC_RIP := preload("res://scripts/comic_rip.gd")
const COMIC_IMPROV := preload("res://scripts/comic_improv.gd")  # the element matrix's tells (round 37, third pass)
const HARPOON_GATHER := preload("res://scripts/harpoon_gather.gd")  # Harpoon's tentacles (round 47)
const SLAPSHOT_FX := preload("res://scripts/slapshot_fx.gd")
const ALT_FX := preload("res://scripts/breaker_alt_fx.gd")  # the breaker pairs' second endings (breaker-pairs lane)
const LAVA_LEASH := preload("res://scripts/lava_leash.gd")  # Lava Leash's tentacles and seams (dark-magma lane)
const ENV := preload("res://scripts/env_target.gd")  # the room's walls and pillars, and the one the player picked (round 50)
const ENV_PIECE := preload("res://scripts/env_piece.gd")  # the room's pieces (round 51, env-pieces lane)
const COLLAPSE_SPIT := preload("res://scripts/collapse_spit.gd")  # round 51 cool pass: Collapse's swallow and spit
const AVALANCHE_TOPPLE := preload("res://scripts/avalanche_topple.gd")  # round 51 cool pass: Avalanche's tower
const ABYSS_RISE := preload("res://scripts/abyss_rise.gd")  # round 51 cool pass: Abyss's column up and slam down
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const ERUPTION_HURL := preload("res://scripts/eruption_hurl.gd")  # round 52 cool pass: Eruption's fuse, heave and hurl
const FROST_SHELL := preload("res://scripts/frost_shell.gd")  # round 52 cool pass: Flash Freeze's steam, shells and break

## Contact frames of the tentacle clips (30 fps, the chibi's keys; `tests/contact_frames.gd` measures them,
## `comic_check` fails when a move's first hit isn't on its clip's): the void moves hit on the keyed contact
## as a fraction of the clip, and their cancel / end / breaker leap keep the time after the hit they had.
const GR_HIT := 7.0 / 31.0  # Ab_GR: the claws snap shut on f7 (hand arrives f5, held to f12). Was 0.24 (f7.4)
const VS_HIT := 17.0 / 46.0  # Ab_VS: the slam lands on f17 (held to f23). Was 0.39 (f17.9, a frame late)
const LH_HIT := 14.0 / 51.0  # Ab_LH: the rake arrives on f14. Was 0.29 (f14.8)
const H_HIT := 15.0 / 63.0  # Ab_H: the crescent arrives on f15. Was 0.24 (f15.1)
const LLH_HIT := 20.0 / 59.0  # Ab_LLH: the spear drives in on f20. Was 0.34 (f20.1)
const AF_HIT := 32.0 / 81.0  # Ab_AF: the palm lands on f32 of 81 (round 51 fluidity re-key: the coil was f1-f50 of 99,
# 350 ms at EM_SPEED and four held frames on film; tools/meshy_rig/clip_warp.py). Was 50 / 99
const AF_K := 99.0 / 81.0  # the old clip over the new: offsets after the palm (fractions of the clip) x this keep their ms
## A breaker's leap comes this long (clip fraction) after the ender's hit, as round 30 had it.
const LEAP_AFTER_GRAB := 0.02  # Grounded / Worldbreaker / Meteor Fall off a grab-clip ender (was 0.26 - 0.24)
const LEAP_AFTER_SLAM := 0.11  # Collapse / Abyss off the slam clip (0.5 - 0.39)
const LEAP_AFTER_TIDE := 0.26  # Maw off Black Tide's grab clip (0.5 - 0.24)
const LEAP_AFTER_RAKE := 0.05  # Cataclysm off Fault Line's rake clip: once the gale has them up
const LEAP_AFTER_PALM := 0.05 * AF_K  # Flash Freeze off Steam Burst's palm clip
const LEAP_AFTER_SWING := 0.1  # Anvil off Backdraft's crescent clip: once the gale has them coming back
const ANVIL_REEL := 0.65  # of the way to him Anvil's tentacles haul what they seize (void_grab `reel`): the leap comes
# before the gale's knockback has moved anyone (their hit freeze), so the kebab's pull-back is the tentacles' to show
const ANVIL_REEL_GAP := 1.4  # m in front of him they're hauled to
const ANVIL_SPREAD := 1.5  # m between neighbours across his aim, held and landed: the reel fans them out so each gets
# its own crater (comic_anvil's dent is 0.62 m round; all hauled to one point they landed in one pile)

## The move right click plays off each move. From nothing, the grab.
const AFTER := {"L1": "EC", "L2": "IP", "L3": "EM", "EC": "EE", "AL1": "EW", "DL": "EF", "EF": "EA", "IP": "IJ", "IJ": "IS", "EM": "EV", "GR": "VS", "VR": "VD",
	"XR": "XF", "EA": "XG", "TW": "XK"}
const NEUTRAL := "GR"
const CHARGED := "OW"  # holding right click
const DASH_MOVE := "TW"  # right click off a dash or a swing
## L off these moves goes somewhere else than on down the string. The X* moves are the crossovers (round 34):
## a string that changes element on the way, with a payoff only the two together give.
const LIGHT_AFTER := {"EC": "AL1", "GR": "VR", "IP": "IJ", "AL1": "XR", "EA": "XS", "TW": "XT", "VR": "XC",
	"XG": "XM", "XK": "XW", "EM": "XL"}  # (EM: Lava Leash, dark-magma lane)
const CHAIN := {"EF": 2}
const ELEMENT_OF := {"EC": "wind", "EE": "wind", "EW": "wind", "EF": "water", "EA": "water", "IP": "water", "IJ": "water", "IS": "water", "EM": "earth", "EV": "earth",
	"VS": "void", "VR": "void", "VD": "void", "OW": "void", "TW": "void",
	"XR": "earth", "XF": "wind", "XS": "earth", "XT": "wind", "XC": "wind",
	"XG": "wind", "XM": "earth", "XK": "water", "XW": "wind", "XL": "void"}
## The arm's shape for the crossovers (ComicLook.HERO_MOVE_FORMS has the rest; void_grab.on_move reads this first).
const FORM_OF := {"EF": "hand", "XC": "hand", "XR": "hammer", "XF": "hand", "XS": "hand", "XT": "axe", "XG": "hand", "XM": "hammer", "XK": "hand", "XW": "axe", "XL": "hand"}
const NO_CAST := ["AL1", "L3"]  # their giant axes stood in front of the tentacle move that follows
const SPEAR_RUN := ["IJ", "IS"]  # moves that take him to the planted spear
## Presses off these go on down their own string, not up the spear (Impale's string plants one first).
const NO_VAULT := ["TW", "XK", "XW", "XT"]

const _WINDOW := {"rise": 0.2, "height": 1.8, "back": 0.6, "spikes": 0, "zone": 1.5, "spread": 0.0, "spike_damage": 0.0,
	"detonate": 0.0, "throw": 0.04, "cue": 0.08, "open": 0.3, "sweet": 0.44, "close": 0.62, "perfect": 0.06, "dive": 0.12,
	"radius": 0.0, "launch": 0.0, "perfect_mult": 1.5, "fall": 0.22, "tentacle": true}
const BREAKER_HANG := 0.1  # s from the top of the rise to the window opening: the beat to see the cue
const BREAKER_TO_SWEET := 0.14  # s from open to the rings meeting
const BREAKER_TO_CLOSE := 0.32  # s from open to close
## The breakers: `erupt` is what the slam lands in, under each foe. `wire` runs lightning along the
## tentacles through the hang. `alt` is what L in the window changes it to, instead of right click.
## Copies of _WINDOW in effect (entry()).
const BREAKERS := {
	"EE": {"erupt": "wind", "wire": true, "damage": 28.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "awaken": 8.0, "awaken_perfect": 16.0,
		"names": {"spirit": "Grounded"},
		# L in the window (round 44 b): the charge the hang put in them goes out to everyone the tentacles didn't hold.
		"alt": {"short_circuit": true, "damage": 22.0, "names": {"spirit": "Short Circuit"}}},
	"EW": {"erupt": "earth", "wire": true, "damage": 36.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "height": 2.6, "awaken": 12.0, "awaken_perfect": 22.0,
		"names": {"spirit": "Worldbreaker"},
		"alt": {"erupt": "water", "cubes": true, "damage": 40.0, "names": {"spirit": "Cold Front"}}},
	"IS": {"erupt": "water", "press": true, "at_spot": true, "short": 3.0, "dive": 0.3, "damage": 34.0, "leap": 0.5, "awaken": 12.0, "awaken_perfect": 22.0,
		"height": 1.2, "names": {"spirit": "Avalanche"}},
	# Meteor Fall (round 42, meteor dive): no tentacle hold; the press dive-bombs the biggest group in reach
	# (meteor_target: the ones Molten Palm just splatted on a wall count more) and the landing takes everyone in
	# METEOR_PILE_R (_meteor_landing). Undertow keeps them pinned in the lava until he lands.
	"EV": {"erupt": "earth", "meteor": true, "no_hold": true, "damage": 60.0, "leap": GR_HIT + LEAP_AFTER_GRAB, "awaken": 10.0, "awaken_perfect": 20.0,
		"height": 3.6, "back": 0.0, "rise": 0.28, "dive": 0.3, "fall": 0.4, "names": {"spirit": "Meteor Fall"},
		# LMB Meteor Shower (breaker-pairs): he stays over his own spot and calls a fireball down on every foe the palm
		# hit, wherever it is (SHOWER_*). Best when the palm scattered them; Meteor Fall wins on a pile at the wall.
		"alt": {"shower": true, "damage": SHOWER_DAMAGE, "dive": 0.2, "names": {"spirit": "Meteor Shower"}}},
	# Dark: he comes down at dark_spot, where the string gathered them (`at_spot`, `short` m this side of it).
	"VS": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 1.6, "collapse": true, "damage": 44.0, "leap": VS_HIT + LEAP_AFTER_SLAM,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Collapse"}},
	"VD": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 4.6, "maw": true, "damage": 52.0, "leap": GR_HIT + LEAP_AFTER_TIDE,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Maw"},
		# L in the window (dark into ice): the pool freezes with them in it, and his landing shatters it.
		"alt": {"erupt": "water", "black_ice": true, "short": 2.0, "damage": 46.0, "names": {"spirit": "Black Ice"}}},
	"OW": {"erupt": "void", "no_hold": true, "at_spot": true, "short": 2.2, "abyss": true, "damage": 40.0, "leap": VS_HIT + LEAP_AFTER_SLAM,
		"awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Abyss"},
		# LMB Uproot (round 51, env-pieces): the tentacle tears the pillar nearest the pinned foe out of the floor and
		# clubs the foe with it along the line pillar -> foe; the pillar is rubble for the room (UPROOT_*, _uproot).
		# Best: a big foe by a pillar; in the open there is nothing to tear and a short slam is all it does.
		"alt": {"uproot": true, "damage": UPROOT_DAMAGE, "names": {"spirit": "Uproot"}}},
	# Crossovers. Cataclysm: Fault Line's gale has them up again and the landing brings them down into the floor. No
	# `wire` (Live Wire's bolts and binds on every foe in the hang made it the busiest breaker; damage 40 -> 46 for the
	# jolts it lost) (`cataclysm`: a crater on each, a strike and earth under each).
	"XF": {"erupt": "earth", "cataclysm": true, "damage": 46.0, "leap": LH_HIT + LEAP_AFTER_RAKE, "height": 2.4,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Cataclysm"},
		# LMB Tempest (breaker-pairs): a twister goes up where they land and takes everyone near up its column; lightning
		# blasts each out of it in turn, harder the more it holds (TEMPEST_*). A crowd: Tempest; a few: Cataclysm.
		"alt": {"erupt": "wind", "tempest": true, "damage": TEMPEST_DAMAGE, "names": {"spirit": "Tempest"}}},
	# Flash Freeze: Steam Burst's steam freezes on them as he dives (`refreeze`), and the landing shatters it again.
	"XS": {"erupt": "water", "refreeze": true, "damage": 30.0, "leap": AF_HIT + LEAP_AFTER_PALM,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Flash Freeze"}},
	# Round 34, second pass: the three-element strings. Eruption ends Meltdown in the air (he rises from the height
	# the air string has him at, `_brk_y0`): the molten come down into the floor and it erupts round them.
	"XM": {"erupt": "earth", "eruption": true, "damage": 42.0, "leap": VS_HIT + LEAP_AFTER_SLAM, "height": 3.0,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Eruption"}},
	# Anvil ends Backdraft: the gale brought the kebab back up to him, and the hammer drives it into the floor.
	"XW": {"erupt": "earth", "anvil": true, "reel": ANVIL_REEL, "damage": 44.0, "leap": H_HIT + LEAP_AFTER_SWING, "height": 2.2,
		"awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Anvil"},
		# LMB Pinwheel (breaker-pairs): the tentacles whirl the kebab round him in a twister and hurl it into the
		# nearest wall or pillar within PINWHEEL_REACH (PINWHEEL_*). Best by a wall or pillar; Anvil wins in the open.
		"alt": {"erupt": "wind", "pinwheel": true, "damage": PINWHEEL_DAMAGE, "dive": PINWHEEL_DIVE, "names": {"spirit": "Pinwheel"}}},
	# Round 50 (environment): Impale's own window, after a pause (a press by its cancel is still Backdraft, Dash H H L),
	# so the skewer reaches Pinwheel in three presses: Dash H H, then L. The kebab is stuck frozen round the spear; the
	# tentacles take it up (`reel` brings it back to him, Anvil's hold). RMB Anvil drives it into the floor, LMB Pinwheel
	# whirls it into the wall or pillar the indicator marks (env_target.gd).
	"XK": {"erupt": "earth", "anvil": true, "reel": ANVIL_REEL, "pause": true, "damage": 44.0, "leap": GR_HIT + LEAP_AFTER_IMPALE,
		"height": 2.2, "awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Anvil"},
		"alt": {"erupt": "wind", "pinwheel": true, "damage": PINWHEEL_DAMAGE, "dive": PINWHEEL_DIVE, "names": {"spirit": "Pinwheel"}}},
	# Round 47: Harpoon's row of cubes. A pause after Dash L H (no press by its cancel: a press there is still Ice Cube,
	# Dash L H H) and he leaps with a tentacle on each cube (`hold_cubes`), landing just behind the row (`zone`).
	# RMB Shatterstorm: thunder on every cube where it stands, reliable anywhere. LMB Slapshot: a molten fist punches the
	# row along his aim; a cube that reaches a wall shatters on it for the most, one that doesn't slides to a stop.
	"EF": {"erupt": "wind", "hold_cubes": true, "pause": true, "thunder": true, "damage": SHATTER_DAMAGE, "leap": LLH_HIT + LEAP_AFTER_HARPOON,
		"zone": 0.6, "awaken": 10.0, "awaken_perfect": 20.0, "names": {"spirit": "Shatterstorm"},
		"alt": {"erupt": "earth", "slapshot": true, "damage": SLIDE_DAMAGE * SLIDE_WALL_MULT, "names": {"spirit": "Slapshot"}}},
	# The dash counter's window (kit slot 9, counter.gd): a perfect Backlash leaps with the tentacle on the attacker
	# alone (`only`, set by counter.gd) and the press hurls it into the nearest foe or wall, bound where it lands.
	"CB": {"erupt": "void", "counter": true, "damage": 30.0, "height": 1.6, "awaken": 10.0, "awaken_perfect": 20.0,
		"names": {"spirit": "Ricochet"}},
	# Lava Leash (dark-magma lane): the leash piled them at his feet, bound in the erupted seam; no tentacle hold (the
	# leash's own keep them through the hang), he dives on the pile (`at_spot`, dark_spot) and the seams go up (HELLSEAM_*).
	"XL": {"erupt": "earth", "hellseam": true, "no_hold": true, "at_spot": true, "short": 1.3, "damage": HELLSEAM_DAMAGE,
		"leap": GR_HIT + LEAP_AFTER_LEASH, "height": 2.4, "awaken": 12.0, "awaken_perfect": 22.0, "names": {"spirit": "Hellseam"}},
}

const CUTTER_AHEAD := 3.5  # m: where the gale throws them up from
const CUTTER_RADIUS := 4.5
const CUTTER_PILLAR_HIGH := 3.5  # m: it must not bury Live Wire, which follows while it's still up
const CUTTER_PILLAR_R := 1.3
const CUTTER_DAMAGE := 10.0
const CUTTER_PULL := 7.0
const CUTTER_LAUNCH := 9.5
const WIRE_DAMAGE := 4.5  # each jolt, each foe (round 44: 3.5 at a 0.09 s step; the pulses come every 0.1 s and later)
const HARPOON_STEPS := 8  # (Molten Palm's lava seam steps)
## Harpoon (round 47, harpoon_gather.gd): a tentacle to every foe this near him, all round (Galvanize's GALV_REACH),
## nearest first and HARPOON_MAX at most, set down frozen in a rank across his aim HARPOON_SET m ahead, each
## HARPOON_GAP clear of the next, short of walls (harpoon_slots). Big ones freeze where they stand.
const HARPOON_REACH := 8.0
const HARPOON_MAX := 5
const HARPOON_DAMAGE := 10.0
## Feel audit 4: the gather's latches (10 each) landed at x1.00, contacts with no stop, on the same frame as the
## Ice Cube press. The first latch of a gather takes LATCH_STOP ("it connected"); the rest stay quiet, so Harpoon
## stays a quick mid (EA -> XG / XS were 200 ms; a stop on every latch made them ~260).
const LATCH_STOP := 0.035
const HARPOON_SET := 2.6  # m ahead of him, the rank
const HARPOON_SET_MIN := 1.5  # m: never closer (a wall right ahead squeezes it to this)
const HARPOON_GAP := 0.15  # m between neighbouring cubes' ice (their fitted width: ice_radius())
const HARPOON_WALL := 0.7  # m a slot keeps off a wall
const ICE_CORNER := 0.93  # of a hex block's corner radius a neighbour is spaced by: between its flat (0.87) and its
# corner (1.0), since each block turns at random (fit_block): two corners may just touch, two flats leave a gap
const LEAP_AFTER_IMPALE := 0.3  # Anvil / Pinwheel off Impale (round 50): after XK's cancel (GR_HIT + 0.18), before its end (+ 0.36)
const LEAP_AFTER_HARPOON := 0.36  # Shatterstorm / Slapshot: the leap, after EF's cancel (LLH_HIT + 0.16) so a press is Ice Cube
## Shatterstorm (RMB): a sky strike on each held cube in turn, SHATTER_STEP apart after SHATTER_DELAY (past the
## landing's impact frame), SHATTER_DAMAGE each (x FREEZE_BREAK on the ice), and the storm stays in them (charged).
const SHATTER_DAMAGE := 30.0
const SHATTER_DELAY := 0.12  # s (game)
const SHATTER_STEP := 0.06  # s (game)
## Slapshot (LMB): the molten fist goes out to the row and punches every cube along his aim at SLIDE_SPEED. One
## that reaches a wall within SLIDE_REACH shatters on it for SLIDE_DAMAGE x SLIDE_WALL_MULT; one that doesn't
## slides to a stop and bursts for SLIDE_DAMAGE. So: wall 63 > thunder 30 > no wall 14 (x FREEZE_BREAK on all three).
const SLIDE_REACH := 10.0  # m
const SLIDE_SPEED := 20.0  # m/s off the fist (slowing to thrown_foe.SLIDE_END of it short of a wall)
const SLIDE_DAMAGE := 14.0
const SLIDE_WALL_MULT := 4.5
const SLIDE_SPIN := 2.0  # radians/s: a slide, not a throw
const SLIDE_FIST_PAST := 0.4  # m the fist reaches past the row's near face
const SLIDE_CUE_MS := 1400  # real ms the sliding cubes count for the camera's framing (camera_rig.FRAME_CUE)
const CAMERA_CUE := &"frame_cue_ms"  # (camera_rig.FRAME_CUE)
## Meteor Shower (Meteor Fall's LMB, breaker-pairs): he comes down where he hangs and a fireball falls out of the sky
## onto each foe Molten Palm hit (palm_fresh, within METEOR_SPLAT_REACH, nearest first, SHOWER_MAX), SHOWER_STEP apart
## after SHOWER_DELAY, each SHOWER_DAMAGE into the floor on its foe alone, which it leaves molten. So: four scattered
## foes 4 x 30 = 120 vs Meteor Fall's 60 on the one it dives on; three piled at a wall 3 x 30 vs 3 x 60 x 1.3.
const SHOWER_DAMAGE := 30.0
const SHOWER_MAX := 6
const SHOWER_DELAY := 0.12  # real s past the landing (the impact frame), real time so its freeze doesn't hold them
const SHOWER_STEP := 0.08  # real s
const SHOWER_FALL := 0.24  # real s each fireball takes from the sky
const SHOWER_CUE_MS := 1500  # real ms its targets count for the camera's framing (camera_rig.FRAME_CUE)
## Pinwheel (Anvil's LMB, breaker-pairs): the dive is a whirl in place (PINWHEEL_DIVE s, PINWHEEL_TURNS round him at
## PINWHEEL_R, a twister round them), then each held foe is hurled at the nearest wall or pillar within PINWHEEL_REACH
## of him (PINWHEEL_RAYS rays) at PINWHEEL_SPEED: PINWHEEL_DAMAGE x PINWHEEL_WALL_MULT on it. No wall in reach: they
## fly PINWHEEL_OPEN m out and land for PINWHEEL_DAMAGE. Anyone else in the whirl takes PINWHEEL_SWEEP of it.
## So: 80 a foe at a wall vs Anvil's 44 x 1.4 = 62; 20 in the open.
const PINWHEEL_DAMAGE := 20.0
const PINWHEEL_WALL_MULT := 4.0
const PINWHEEL_REACH := 10.0  # m round him (the room's pillars stand ~11 m from its middle: there it is the open)
const PINWHEEL_RAYS := 32
const PINWHEEL_R := 2.3  # m round him they whirl
const PINWHEEL_TURNS := 1.25
const PINWHEEL_Y := 1.3  # m up they whirl (his chest as he lands: a hammer throw)
const PINWHEEL_DIVE := 0.42  # s
const PINWHEEL_SPEED := 24.0  # m/s
const PINWHEEL_OPEN := 7.0  # m
const PINWHEEL_SWEEP := 0.5
const PINWHEEL_CUE_MS := 1400  # real ms the thrown count for the camera's framing
## Tempest (Cataclysm's LMB, breaker-pairs): where they land (the held pile's middle) a twister takes everyone not big
## within TEMPEST_REACH up its column (TEMPEST_MAX at most), spiralling in to TEMPEST_R and up; from TEMPEST_FIRST s
## a bolt out of the sky blasts each out of it in turn (TEMPEST_STEP apart), TEMPEST_DAMAGE x (1 + TEMPEST_PER per other
## foe in the column), charged and thrown clear. Big ones stay on the floor and take TEMPEST_BIG of one blast.
## So: one foe 20 vs Cataclysm's 46; two 2 x 30 vs 92; four 4 x 50 = 200 vs 184; five 5 x 60 vs 230.
const TEMPEST_DAMAGE := 20.0
const TEMPEST_PER := 0.5
const TEMPEST_REACH := 7.0  # m round the pile
const TEMPEST_MAX := 8
const TEMPEST_R := 1.1  # m round the column's middle they ride
const TEMPEST_HIGH := 2.4  # m up they ride (TEMPEST_HIGH_STEP more for every other one, so they stack)
const TEMPEST_HIGH_STEP := 0.55
const TEMPEST_SPIN := 9.0  # rad/s round the column
const TEMPEST_FIRST := 0.42  # s (game) from the landing to the first bolt: they are up by then
const TEMPEST_STEP := 0.09  # s (game) between bolts
const TEMPEST_FREEZE := 0.35  # real s the landing's stop holds the game before the ride plays (the twister runs on real time)
const TEMPEST_THROW := 7.0  # m/s out of the column
const TEMPEST_LAUNCH := 6.0
const TEMPEST_BIG := 0.6
const TEMPEST_COLUMN := 5.5  # m: the twister's height
const TEMPEST_OUT := 1.4  # m past the held pile's middle, along his aim, the column stands
const TEMPEST_CUE_MS := 1600
## Feel audit 3 item 6: a foe Molten Palm carries to a wall is cued for the framing this long (real ms), through
## Undertow and Meteor Fall's hang (camera_rig frames cued foes in a hang), so the splat and the dive stay on screen.
const PALM_CUE_MS := 2600
const CUBE_DAMAGE := 22.0
const BOWL_REACH := 7.0  # m: how far it'll take a foe from
const BOWL_LENGTH := 12.0  # m it flies
const SPEAR_AHEAD := 2.6  # m in front of him it goes in
const SPEAR_GAP := 0.7  # m short of it he stops
## Feel audit 3: the vault (IJ) was the only contact with no stop (x1.00 on its HIT frame). His push-off on the
## spear takes a light freeze, between Frost Spear's plant (IP 0.07) and Deep Freeze (IS 0.1), and a small shake.
const VAULT_STOP := 0.06  # real s, at Game.hitstop's freeze scale (eased tail)
const VAULT_SHAKE := 0.2
const SPEAR_RUN_SPEED := 16.0  # m/s
const DEEP_FREEZE_RADIUS := 6.5  # m round the spear
const DEEP_FREEZE_DAMAGE := 16.0
const DEEP_FREEZE_SPIKES := 6
const DEEP_FREEZE_SPIKE_OUT := 1.8  # m from the spear: further out they hid the cubes
const DEEP_FREEZE_DOWN := 6.0  # m/s into the floor on its hit: enemy._is_spike craters them before the cube
const PRESS_REACH := 10.0  # m: how far the tentacles go for a cube
const CRUSH_HIGH := 2.5  # m the cubes go up
const CRUSH_RADIUS := 3.2  # m round the pile that anyone else gets caught
const CRUSH_RING := 5.0  # m the frost goes out from it
const CRUSH_CUBE_WIDTH := 1.3  # m: how much room each takes in the pile
const PRESS_NO_CUBE := 0.5  # of the damage, to those not in a cube
const PALM_LENGTH := 6.5
const PALM_HALF_WIDTH := 2.6
const PALM_DAMAGE := 14.0
const PALM_SHOVE := 6.0  # m
## Round 42 e: a wall this close behind a foe (m, along the punch) and the palm carries it all the way there and
## splats it (PALM_WALL_MULT), so the wall payoff is there whenever a wall is near, not only at 6 m. The training
## room's back wall is ~9-10 m behind the dummies after L L L. Past it: the plain PALM_SHOVE.
const PALM_WALL_REACH := 10.5
const PALM_SPEED := 24.0
const PALM_WALL_MULT := 2.5  # the splat, on the damage below
const PALM_SPLAT := 12.0
const FIST_RADIUS := 1.15
const FIST_TIME := 0.2  # s out
const UNDERTOW_RADIUS := 7.0
const UNDERTOW_TIME := 1.6  # s
const UNDERTOW_SINK := 0.9  # m
const UNDERTOW_TICK := 3.5
const METEOR_DOWN := 6.0  # m/s into the floor on Meteor Fall's landing: it craters (enemy._is_spike)
const UNDERTOW_CHASE := 18.0  # m it'll follow those Molten Palm just shoved
const METEOR_GEYSERS := 3  # thin rim geysers (round 33, sleek 5: five full ones walled the pile in)
const METEOR_GEYSER_OUT := 2.8  # m round where he lands
const METEOR_R := 0.8  # m
const METEOR_TAIL := 3.0  # m
const METEOR_TONGUES := 5  # the tail is flames, not one long cone
const METEOR_TONGUE_R := 0.42  # m
const METEOR_COLOR := Color(1.0, 0.36, 0.08, 0.72)
const METEOR_HOT := Color(1.0, 0.82, 0.25, 0.9)
const REAP_REACH := 6.5  # m
const REAP_HALF_ANGLE := 1.35  # radians either side of his aim
const REAP_DAMAGE := 14.0
const TIDE_AHEAD := 4.0  # m: where it drags them to
const TIDE_NEAR := 6.0  # m: who it takes with nobody marked
const TIDE_REACH := 20.0  # m: how far it'll go for a mark
const TIDE_DAMAGE := 10.0
const TIDE_SPEED := 22.0
const TIDE_ARRIVE := 0.4  # s at most on the way in, however far: Maw's earliest bite mustn't beat them to the pool
const TIDE_RING := 0.8  # m apart they fetch up
const TIDE_TIME := 1.8  # s they're stuck
const TIDE_POOL_R := 3.4
const COLLAPSE_RADIUS := 6.5  # m
const COLLAPSE_THROW := 9.0
## Round 50: with a wall or pillar within env_target.COLLAPSE_REACH of the hole (the one the indicator marks; the
## cursor's pick), Collapse hurls everyone it throws into it at COLLAPSE_WALL_SPEED: its damage x COLLAPSE_WALL_MULT
## on the structure. Big ones and an open room: the throw clear, as before.
const COLLAPSE_WALL_MULT := 1.6
const COLLAPSE_WALL_SPEED := 22.0
const COLLAPSE_CUE_MS := 1400
## Round 51 cool pass: the hole swallows each foe (a tentacle out of it, collapse_spit.gd) for COLLAPSE_SWALLOW_MULT of the
## damage, then spits it out: into the structure (x COLLAPSE_WALL_MULT), or up out of the floor (COLLAPSE_SPIT_UP).
## So: 0.3 + 1.6 = 1.9 x 44 = 84 a foe by a wall or pillar, 0.3 + 1 = 57 in the open (it was 70 / 44).
const COLLAPSE_SWALLOW_MULT := 0.3
const COLLAPSE_SPIT_UP := 10.0
const COLLAPSE_WORD := "GLLRK-PTOOO!"
const COLLAPSE_SPIT_WORDS := ["PTOO!", "PTOOIE!", "PTAH!"]  # round 52: the spits after the first
## Round 51 cool pass, Avalanche: the dive stacks the cubes into a tower (aim_crush's stack slots), the landing crushes
## it (AVALANCHE_CRUSH of the damage each) and the tentacles push it over toward the structure the indicator marks
## within AVALANCHE_REACH of its foot (env_target "avalanche"), else away from him: each cube slides on off the falling
## tower (avalanche_topple.gd) into the structure for x AVALANCHE_WALL_MULT, or out AVALANCHE_OPEN m to a stop and bursts.
## Anyone else in the fall's strip (AVALANCHE_STRIP m either side) is caught: PRESS_NO_CUBE of it and frozen.
## The open slide bursts for AVALANCHE_OPEN_MULT. So: 0.3 + 3 = 3.3 x 34 = 112 a cube by a wall or pillar, 0.3 + 0.75 =
## 36 in the open (it was 34 everywhere; void_arm_check measures it with the perfect and the ice's shatter on top).
const AVALANCHE_REACH := 9.0
const AVALANCHE_CRUSH := 0.3
const AVALANCHE_WALL_MULT := 3.0
const AVALANCHE_OPEN_MULT := 0.75
const AVALANCHE_OPEN := 6.0
const AVALANCHE_SPEED := 18.0
const AVALANCHE_STRIP := 1.4
const AVALANCHE_SPREAD := 0.7  # m apart the cubes hit the structure, across it
const AVALANCHE_CUE_MS := 1600
const AVALANCHE_WORD := "KRA-KRA-KRASH!"
const MAW_RADIUS := 3.4  # m
const MAW_DOWN := 6.0  # m/s into the floor as the jaws shut: the swallowed crater (enemy._is_spike)
const ABYSS_RADIUS := 4.2  # m
const ABYSS_SINK := 2.6  # m they go down while he's on his way
const ABYSS_LAUNCH := 11.0
const ABYSS_RISE_MULT := 0.3  # round 51: of the damage as the column takes it up (abyss_rise.on_rise)
const ABYSS_SLAM_MULT := 1.0  # and as it drives it back down
const ABYSS_BIG_MULT := 1.6  # on a big one's slam: one heavy foe is Abyss's best (Collapse only coils them)
const ABYSS_SHARE := 0.3  # per foe after the first when it gives back more than one (a crowd is Collapse's; a big foe by a pillar Uproot's)
const ABYSS_CUE_MS := 1200
const ABYSS_WORD := "SHLUUUK-WHAM!"
const OVERWHELM_RADIUS := 3.6
## Uproot (Abyss's LMB, round 51 env-pieces): the pillar nearest the pinned foe within UPROOT_REACH (the indicator's
## pick, env_target CTX "uproot") is torn out as he dives and comes down along the line pillar -> foe, UPROOT_LENGTH m
## (carried closer when the foe stands further off), UPROOT_FALL real s after the landing: UPROOT_DAMAGE into the floor
## on the foe (buried; x UPROOT_HEAVY on a big one), UPROOT_LINE of it on everyone else within UPROOT_LINE_R of the
## fall line (buried). The pillar is rubble for the room (env_piece.topple). No pillar in reach: the tentacle slams the
## foe from the sky for UPROOT_OPEN alone. So, a big foe 4 m from a pillar and one more on the line:
## (70 x 1.25 + 42) x 1.5 = 194 vs Abyss's (40 + 40) x 1.5 = 120; in the open 22 x 1.5 = 33 vs Abyss's 60.
const UPROOT_REACH := 6.0  # m from the pinned foe to the pillar
const UPROOT_DAMAGE := 70.0
const UPROOT_HEAVY := 1.25
const UPROOT_LINE := 0.6
const UPROOT_LINE_R := 1.5  # m either side of the fall line
const UPROOT_LENGTH := 4.0  # m: the pillar's height, the fall line
const UPROOT_REACH_IN := 0.6  # m short of the foe's middle the pillar's head comes down
const UPROOT_FALL := 0.16  # real s from the landing to the club's hit (the swing)
const UPROOT_DOWN := 7.0  # m/s into the floor: it craters (enemy._is_spike)
const UPROOT_OPEN := 22.0
const UPROOT_META := &"uproot_pillar"  # on the hero from the dive to the hit: the pillar it tore out
const OVERWHELM_REACH := 10.0
const OVERWHELM_AHEAD := 5.0  # m, with nobody to aim at
const OVERWHELM_TIME := 2.2  # s
const OVERWHELM_TICK := 4.0
const TOW_HALF_WIDTH := 2.6
const TOW_NEAR := 5.0  # m round him, if nobody's on the line
const TOW_AHEAD := 2.2  # m: where they're yanked to
const TOW_DAMAGE := 18.0
const TOW_SPEED := 26.0
## Round 52 cool pass: Tow Line's snare picks. The bracket goes on the foe nearest where they're yanked to (the auto pick,
## the default throw); the cursor on another foe within TOW_PICK_REACH makes it the anchor: it is snared where it
## stands (TOW_ANCHOR_MULT) and everyone on the line is yanked into it.
const TOW_PICK_REACH := 7.0
const TOW_ANCHOR_MULT := 0.6
const CARRY_DAMAGE := 22.0
const CARRY_LENGTH := 9.0  # m it flies off a swing
const FREEZE_TIME := ELEMENT_HOLD  # s (was 1.8): long enough for a dash and a magma move after it to steam them
const FREEZE_BREAK := 1.6  # the next hit's damage: Frostline into the hammer shatters them
const BOSS_CHILL := 0.5  # bosses never freeze: they slow
const MAGMA_RADIUS := 4.5
const MAGMA_DAMAGE := 14.0
const MAGMA_LAUNCH := 8.0
const MAGMA_WELLS := 3
const MAGMA_WELL_R := 2.6
const GEYSER_RADIUS := 0.9
const GEYSER_HIGH := 3.2  # m: taller hid the hero and blew out at the game's camera
const BREAK_AREA := 4.5  # m round the landing, beyond whoever was seized
const BREAK_LAUNCH := 7.0
## Short Circuit (Grounded's L ending, round 44 b): he lands and the charge in the held goes out. They take only
## SC_HELD_MULT and stay down (no launch); arcs jump, chained from the nearest held, to everyone NOT held within
## SC_REACH (nearest first, SC_ARCS at most), each a real hit for SC_ARC_MULT of the damage x (1 + SC_PER_HELD per
## other held foe: the more it held, the more charge it spends), a stagger, and the charge moves into them. Grounded
## bursts the held group; Short Circuit is for a room full beyond the tentacles' reach.
const SC_HELD_MULT := 0.5
const SC_REACH := 12.0
const SC_ARCS := 8
const SC_ARC_MULT := 0.75
const SC_PER_HELD := 0.15
const SC_STUN := 0.5
const SC_DELAY := 0.12  # s (game) after the landing before the first arc: past the impact frame, which hid them
const SC_STEP := 0.06  # s between the arcs, each link's hit stop a step longer (SC_STOP + SC_STOP_PER per link)
const SC_STOP := 0.02
const SC_STOP_PER := 0.008
const SC_CUE_MS := 900  # real ms the arcs' targets count for the camera's framing before they're struck (camera_rig.FRAME_CUE)
const CRYSTAL_SIZE := 1.5
const CUBE_STAGGER := 0.05  # s between the cubes leaving
const CUBE_SEEK := 14.0  # m: how far a cube looks for someone to hit
const CUBE_REACH := 8.0  # m it flies with nobody to hit
const CUBE_FOE_GAP := 0.6
# Crossovers (round 34).
const ROCKSLIDE_AHEAD := 1.6  # m: where the hammer comes down
const ROCKSLIDE_RADIUS := 5.0  # m round it
const ROCKSLIDE_DAMAGE := 12.0
const ROCKSLIDE_AIR_MULT := 2.0  # on a foe the gale had up: wind lifts, earth brings it down
const ROCKSLIDE_DOWN := 6.0  # m/s into the floor (enemy._is_spike): the whole group craters
const ROCKSLIDE_IN := 3.0  # m/s of it towards the hammer, so they come down together
const FAULT_REACH := 7.0  # m: how far the cracks run
const FAULT_DAMAGE := 8.0
const FAULT_BURIED_MULT := 2.0  # on those Rockslide just put in the floor: the gale throws back what it buried
const FAULT_LAUNCH := 9.0
const STEAM_REACH := 12.0  # m: every frozen foe this close goes off (the bowled one too)
const STEAM_DAMAGE := 18.0  # times the ice's FREEZE_BREAK on the frozen
const STEAM_LAUNCH := 8.0
const STEAM_SPLASH := 2.6  # m round each burst that the steam scalds
const STEAM_SPLASH_DAMAGE := 6.0
const STEAM_FIST := 4.0  # m the fist goes out, with nobody frozen
const PITCH_AHEAD := 1.8  # m: where Tow Line bunched them
const PITCH_GRAB := 3.4  # m round that spot it takes them from
const PITCH_LENGTH := 9.0  # m they fly
const PITCH_SPREAD := 0.35  # radians between them
const PITCH_DAMAGE := 16.0
const PITCH_SPEED := 26.0
## Galvanize (H L L, round 44): Reap marked them where they stand; a tentacle goes out to each and the storm runs
## down them (live_current.gd), then arcs on. Its place: a spread-out crowd, which Updraft Lash and Molten Palm
## need bunched. More linked, harder each zap; Black Tide (H L H) is the other answer off Reap, gathering them.
## Round 44 b: an event in three beats (live_current stagger / hold / together). Reach out: a tentacle whips out to
## every foe in GALV_REACH round him, nearest first, GALV_STAGGER apart; Reap's mark only reaches further
## (GALV_MARK_REACH) and hits harder (GALV_MARK_MULT), and the marked are taken first past GALV_LINKS. Charge:
## GALV_HOLD s held in slow motion, the claw crackling and the tentacles lighting out from it. Discharge: one fat
## pulse lands on all of them on the same frame (GALV_TOGETHER), a real hit each (star, flash, stagger), a hit stop
## and the word on that frame, both bigger the more are linked; the arcs chain on; the tentacles snap back.
const GALV_REACH := 8.0  # m round him: a tentacle goes to everyone this near...
const GALV_MARK_REACH := 11.0  # ...and to the Reap marked this near
const GALV_LINKS := 6  # tentacles at most
const GALV_DAMAGE := 7.0  # each linked foe's zap with one linked...
const GALV_LINK_BONUS := 0.3  # ...and this much more per other foe linked (5 linked: x2.2, 15.4 each, 77 in all)
const GALV_MARK_MULT := 1.25  # a Reap-marked foe's zap
const GALV_STAGGER := 0.035  # s between the tentacles leaving his claw
const GALV_HOLD := 0.07  # s (game; x2 in the slow) the charge holds
const GALV_TOGETHER := 0.07  # s the pulse takes down every tentacle
const GALV_FAT := 1.8  # the pulse's width (Live Wire's is 1)
const GALV_STUN := 0.45  # s each linked foe staggers (the jolt)
const GALV_STOP := 0.045  # s hit stop on the burst...
const GALV_STOP_PER := 0.015  # ...and this much more per other foe linked (max GALV_STOP_MAX)
const GALV_STOP_MAX := 0.13
const GALV_WORD := 0.4  # the word's size (ComicFx WORD_SCALE units) with one linked...
const GALV_WORD_PER := 0.05  # ...and this much bigger per other
const GALV_JUMP := 3.5  # m an arc jumps from a zapped foe to one no tentacle holds (and on from that one)
const GALV_JUMP_DAMAGE := 6.0
const GALV_JUMPS := 4  # arcs at most
## Lava Leash (L L L H L, dark-magma lane): magma into dark, the sixth crossover. Molten Palm shoved them along its
## lava line; a tentacle goes out to every foe that palm hit (palm_fresh, within LEASH_REACH: the wall it carried them
## to too), latches (LEASH_DAMAGE) and drags it back along the floor through the lava (lava_leash.gd) into a pile at his
## feet, LEASH_PILE m ahead: each pays LEASH_PER_M a metre dragged (to LEASH_DRAG_CAP), x LEASH_WALL_MULT on that part
## when it is torn off a wall (wall_fresh). When the last one lands the seam erupts under the pile: LEASH_ERUPT each x
## (1 + LEASH_PILE_PER per other in it), molten and bound (floor_bind, no ropes: the leash's own tentacles hold them).
## Best situation: the palm's foes at mixed ranges, one splatted on a wall (the far ones pay most); Galvanize wants a
## spread crowd round him (it hits where they stand), Black Tide marked foes anywhere (it drags flat damage to a pool).
## Nobody the palm hit: those in its strip ahead (PALM_LENGTH x PALM_HALF_WIDTH). Big ones are latched where they stand.
const LEASH_REACH := 17.0  # m round him (METEOR_SPLAT_REACH: the palm's line + PALM_WALL_REACH)
const LEASH_MAX := 6
const LEASH_DAMAGE := 6.0  # the latch
const LEASH_PER_M := 1.8  # a metre dragged...
const LEASH_DRAG_CAP := 12.0  # ...counted to this far
const LEASH_WALL_MULT := 1.6  # on the drag, torn off a wall it was splatted on
const LEASH_ERUPT := 8.0  # the seam erupting under the pile, each...
const LEASH_PILE_PER := 0.2  # ...and this much more per other foe in the pile
const LEASH_PILE := 2.1  # m ahead of him the pile is (clear of his body on the game camera)
const LEASH_RING := 0.62  # m round the pile's middle they land
const LEASH_BIND_TIME := 1.6  # s the pile is held (bound) in the erupted seam: through the window
const LEASH_TICK := 1.5  # its burn a tick (floor_bind step 0.25)
const LEASH_SINK := 0.3  # m they go down in it
const LEASH_STOP := 0.05  # s hit stop on the eruption...
const LEASH_STOP_PER := 0.012  # ...and this much more per other foe in the pile
const LEASH_WORD := 0.42  # the word's size with one in the pile, LEASH_WORD_PER bigger per other
const LEASH_WORD_PER := 0.05
const LEASH_CUE_MS := 1600  # real ms the leashed count for the camera's framing (camera_rig.FRAME_CUE): the far one stays in
const LEASH_META := "leash_m"  # meta: the metres the leash dragged it (Hellseam reads it)
const LEAP_AFTER_LEASH := 0.76  # (clip fraction, near its end) Hellseam's leap: after the last drag lands and the pile's burst has peaked (it hid under his leap at 0.56)
## Hellseam (Lava Leash's breaker, H): he dives onto the pile and the seam goes up its whole length. The held pile is
## driven into the floor (a crater) for the breaker's damage x (1 + HELLSEAM_PER_M a metre each was dragged, to
## LEASH_DRAG_CAP); then the eruption races back out along every seam a foe was dragged down, from the pile to where it
## was taken from (HELLSEAM_STEP m between geysers, HELLSEAM_DELAY past the impact frame, HELLSEAM_RUN s a metre), and
## anyone standing on a seam takes HELLSEAM_SEAM of it. So it pays the same thing the leash does: far drags.
const HELLSEAM_DAMAGE := 40.0
const HELLSEAM_PER_M := 0.04  # (a foe dragged 10 m: x1.4)
const HELLSEAM_PILE_R := 2.6  # m round the landing that is the pile
const HELLSEAM_DOWN := 6.0  # m/s into the floor (enemy._is_spike)
const HELLSEAM_STEP := 1.5  # m between the seam's geysers
const HELLSEAM_DELAY := 0.12  # s (game) past the landing: the impact frame hides anything sooner
const HELLSEAM_RUN := 0.025  # s (game) a metre: the eruption runs out along the seam
const HELLSEAM_SEAM := 0.5  # of the damage, to anyone else on a seam
const HELLSEAM_SEAM_R := 1.1  # m either side of a geyser
const HELLSEAM_GEYSER := 3.0  # m tall
const HELLSEAM_CUE_MS := 1400
const BLACK_ICE_DOWN := 6.0  # m/s into the floor as the ice gives (enemy._is_spike)
const CATACLYSM_DOWN := 6.0  # m/s
# Round 34, second pass: three elements in one string, and states that outlive it so a dash can improvise.
const CHARGED_HOLD := 3.0  # s the charged state lasts (Galvanize's event, a wait and L L L H fit in it; 2 s didn't)
const ELEMENT_HOLD := 2.0  # s a crossover's state (frozen, buried, molten, skewered) lasts: a dash and the next move
const HAIL_REACH := 7.0  # m: Hailstorm lifts every frozen foe this close
const HAIL_DAMAGE := 8.0  # (x FREEZE_BREAK: the ice gives as the gale takes it)
const HAIL_LAUNCH := 9.0  # m/s up (was 12: a foe peaked at 5.3 m and was still flying up past him at 7 m/s as Meltdown
# hit; his climb stops at 2.8): now ~3 m, into its apex hang by the slam, so Meltdown meets them at the top of his climb
const HAIL_WARM_LAUNCH := 6.0  # those not frozen only stagger up
const HAIL_WARM_REACH := 4.0
const MELT_REACH := 6.0  # m round him: Meltdown takes whoever's up there with him, and the frozen
const MELT_DAMAGE := 14.0
const MELT_AIR_MULT := 1.5  # storm into magma: those the gale had up take it worst (x FREEZE_BREAK on the ice too)
const MELT_DOWN := 6.0  # m/s into the floor (enemy._is_spike): they come down burning and crater
const ERUPT_MOLTEN_MULT := 1.4  # Eruption on those Meltdown set alight
const ERUPT_RING := 3.5  # m round the landing the floor goes up
const ERUPT_LAUNCH := 9.0
## Round 52 cool pass (eruption_hurl.gd): a fuse to each, a geyser heaves it up (ERUPT_HEAVE_MULT), then it is hurled
## into the structure the indicator marks (env_target "eruption", within ERUPT_REACH of the landing: x ERUPT_HURL_MULT,
## its wall splat x ERUPT_WALL_MULT) and slides down it burning (ERUPT_SLIDE_MULT), or in the open dropped back into
## the floor (ERUPT_DROP_MULT). Every beat x ERUPT_MOLTEN_MULT on those Meltdown lit, x ERUPT_COLD_MULT on the rest.
const ERUPT_REACH := 9.0
const ERUPT_COLD_MULT := 0.7
const ERUPT_HEAVE_MULT := 0.35
const ERUPT_HURL_MULT := 0.8
const ERUPT_WALL_MULT := 1.6
const ERUPT_WALL_SPEED := 20.0
const ERUPT_SLIDE_MULT := 0.45
const ERUPT_DROP_MULT := 0.45
const ERUPT_WALL_WORD := "SPLURCH!"
const ERUPT_CUE_MS := 1300
## Round 52 cool pass, Flash Freeze (frost_shell.gd): on the dive the steam rolls over everyone within FF_CLOUD_R of the
## landing and sets into a shell on each (FF_SET_MULT as it sets); the landing breaks the picked one (env_target
## "flash_freeze") and the break runs shell to shell, each link FF_LINK_PER more than the last. A crowd: Flash Freeze.
const FF_CLOUD_R := 5.5
const FF_SET_MULT := 0.3
const FF_LINK_PER := 0.6
const FF_DOWN := 3.0
const FF_META := &"frost_shell"
const IMPALE_GRAB := 4.0  # m round where Tow Line bunched them
const IMPALE_DAMAGE := 12.0
const IMPALE_SPEAR_MULT := 1.5  # dark into ice: onto a spear that was already standing, frost and all
const IMPALE_RING := 0.9  # m round the spear they're stuck
const IMPALE_SPEED := 26.0
const BACKDRAFT_REACH := 5.0  # m round the spear (or him) the gale takes them from
const BACKDRAFT_DAMAGE := 12.0  # (x FREEZE_BREAK: the skewered are still frozen)
const BACKDRAFT_PULL := 7.0  # m/s back towards him
const BACKDRAFT_LAUNCH := 10.0
const ANVIL_DOWN := 6.0  # m/s into the floor
const ANVIL_AIR_MULT := 1.4  # storm into earth: those the gale had up come down hardest
const TOW_AIR_MULT := 1.5  # airborne into dark: Tow Line rips foes out of the air harder (a dash out of any launcher)
# Meteor Fall (round 42, meteor dive): he dives onto the best group in reach (meteor_target). Molten Palm (L L L H)
# punches a group into a wall; Meteor Fall (its breaker, L L L H H + H) drops on that group.
const METEOR_REACH := 12.0  # m round him that he'll dive to (Molten Palm's 6.5 m lava line + its 6 m shove)
const METEOR_SPLAT_REACH := 17.0  # m to a group round a fresh wall splat (the lava line + PALM_WALL_REACH)
const METEOR_PILE_R := 3.0  # m round the landing that the meteor takes, and the size of a group he picks
const METEOR_HEAVY_MULT := 1.5  # big ones still take it worst
const METEOR_WALL_WEIGHT := 1.5  # a foe splatted on a wall in the last METEOR_SPLAT_FRESH_MS counts this much in a group
const METEOR_SPLAT_FRESH_MS := 3000  # real ms: palm -> Undertow -> the window's press is ~1.5-2 s
const METEOR_SPLAT_MULT := 1.3  # of the landing's damage on a foe still fresh off a wall splat
const PALM_META := "last_palm_ms"  # meta: Time.get_ticks_msec() of Molten Palm's hit on it
const METEOR_PALM_FRESH_MS := 4000  # real ms the palm's mark lasts: Meteor Fall only dives on the foes its palm hit
const METEOR_DIVE_SPEED := 30.0  # m/s flat at most: a far group stretches the 0.3 s dive (12 m: 0.4 s)


static func heavy_after(from: String, attacking: bool) -> String:
	return AFTER.get(from, NEUTRAL) if attacking else NEUTRAL


## While the spear stands, either button takes him up over it, however long he's watched the frost spread:
## the plant's own animation is over well before the frost is. Not once he's on his way down onto it.
static func vaults(tree: SceneTree, from: String, attacking: bool, post_dash: bool) -> bool:
	if post_dash or from == "IS" or (from == "IJ" and attacking) or (attacking and from in NO_VAULT):
		return false
	return SPEAR.current(tree) != null


static func is_element_move(id: String) -> bool:
	return ELEMENT_OF.has(id)


## The breaker entry for a key in BREAKERS. Its window keeps one rhythm whatever the element (round 30): it
## opens BREAKER_HANG s after the rise tops out, the sweet spot BREAKER_TO_SWEET later and it closes
## BREAKER_TO_CLOSE after opening, unless the breaker sets `open` itself. With the default rise (0.2)
## that's _WINDOW's 0.3 / 0.44 / 0.62; Meteor Fall's longer rise (0.28) used to open 0.02 s after the top.
static func entry(key: String) -> Dictionary:
	var made: Dictionary = _WINDOW.duplicate()
	made.merge(BREAKERS[key], true)
	if not BREAKERS[key].has("open"):
		made.open = made.rise + BREAKER_HANG
		made.sweet = made.open + BREAKER_TO_SWEET
		made.close = made.open + BREAKER_TO_CLOSE
	return made


## The colour for this move's shared effects. Otherwise they come out in his axe's teal.
static func color_of(id: String, fallback: Color) -> Color:
	return ELEMENTS.LOOK[ELEMENT_OF[id]].color if ELEMENT_OF.has(id) else fallback


## Freezes a foe and puts it in a cube. Bosses only slow, with no cube.
static func encase(e: Variant) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	chill_or_freeze(e)
	if not e.has_method("is_boss"):
		THROWN.cube_on(e)


## What a breaker lands in, as an element the shared effects understand.
static func breaker_element(b: Dictionary) -> String:
	return b.erupt


## The move's first hit. Returns how many foes it reached, so a whiff stays quiet. A base element move first cashes
## in whatever state its element pays on the foes near him (improvise(), the element matrix), then does its own thing.
static func fire(hero: CharacterBody3D, id: String, fwd: Vector3) -> int:
	var paid := improvise(hero, id, _flat(hero.global_position), hero._dmg_mult * hero._cast_power(), fwd)
	return maxi(_fire(hero, id, fwd), paid)


static func _fire(hero: CharacterBody3D, id: String, fwd: Vector3) -> int:
	var parent: Node = hero.get_parent()
	var at := _flat(hero.global_position)
	var power: float = hero._dmg_mult * hero._cast_power()
	var grow: float = hero._cast_grow()
	Game.sfx(ELEMENTS.LOOK[ELEMENT_OF[id]].sfx, -2.0, 0.1)
	match id:
		"EC":
			var eye: Vector3 = at + fwd * minf(CUTTER_AHEAD, hero._clear_ahead(fwd, CUTTER_AHEAD))
			_pop(parent, eye, "axe")
			ELEMENTS.pillar(parent, eye, "wind", CUTTER_PILLAR_HIGH, CUTTER_PILLAR_R * grow)
			_cash_buried(hero, eye, CUTTER_RADIUS * grow, CUTTER_DAMAGE * power, FAULT_LAUNCH)  # (buried into storm)
			return _pull(hero, eye, CUTTER_RADIUS * grow, CUTTER_DAMAGE * power, CUTTER_PULL, CUTTER_LAUNCH)
		"EE", "EW":
			var n: int = hero._void.reachable().size()
			if n == 0:  # nobody to latch onto: it crackles out ahead
				var from := at + Vector3.UP * 1.3 + fwd * 0.6
				for k: float in [3.0, 6.0]:
					ELEMENTS.arc(parent, from, at + fwd * k + Vector3.UP, ELEMENTS.LOOK.wind.color)
			return n
		"EF":
			return _harpoon(hero, at, fwd, HARPOON_REACH * grow, HARPOON_DAMAGE * power)
		"IP":
			return _plant(hero, at, fwd)
		"IJ":  # (no hit: the push-off on the spear is the contact)
			if SPEAR.current(hero.get_tree()) != null:
				Game.hitstop(VAULT_STOP)
				Game.shake(VAULT_SHAKE)
			return 0
		"IS":
			return _deep_freeze(hero, at, DEEP_FREEZE_DAMAGE * power)
		"EA":
			return _ice_cube(hero, at, fwd, CUBE_DAMAGE * power)
		"EM":
			if _frozen_ahead(hero, at, fwd, PALM_LENGTH * grow):  # frozen into magma, whatever the route: steam
				return _steam_burst(hero, at, fwd, power)
			return _palm(hero, at, fwd, grow, power)
		"EV":
			return _undertow(hero, at, power)
		"VS":
			return _singularity(hero, power)
		"VR":
			return _reap(hero, at, fwd, REAP_DAMAGE * power)
		"VD":
			return _black_tide(hero, at, fwd, power)
		"OW":
			return _overwhelm(hero, at, fwd, power)
		"TW":
			for e: Node3D in _tow_line(hero, at):  # airborne into dark: ripped out of the air
				if e.is_airborne() and not hero._void.is_heavy(e):
					e.take_hit(TOW_DAMAGE * power * (TOW_AIR_MULT - 1.0), Vector3.ZERO, 0.0, true)
					Game.register_hit("cast")
					COMIC_RIP.spawn(hero.get_parent(), e, at)  # (a void tear across it as it's ripped down)
			return _tow(hero, at, fwd, TOW_DAMAGE * power)
		"XR":
			var n := _rockslide(hero, at, fwd, power * hero.HERO_MOVES.plunge_mult(hero))
			for e: Variant in hero._void.buried:
				mark(e, "buried")
			return n
		"XF":
			return _fault_line(hero, at, fwd, power)
		"XS":
			return _steam_burst(hero, at, fwd, power)
		"XT":
			_cash_buried(hero, at + fwd * PITCH_AHEAD, PITCH_GRAB, PITCH_DAMAGE * power, 0.0)  # (buried into storm)
			return _pitch(hero, at, fwd, power)
		"XC":
			return _galvanize(hero, at, fwd, power)
		"XG":
			return _hailstorm(hero, at, power)
		"XM":
			return _meltdown(hero, at, power)
		"XK":
			return _impale(hero, at, fwd, power)
		"XW":
			return _backdraft(hero, at, fwd, power)
		"XL":
			return _lava_leash(hero, at, fwd, power)
	return 0


# --- The moves ----------------------------------------------------------------

## One of Live Wire's jolts reaching a foe: a pulse down its tentacle, or an arc on to one no tentacle holds
## (void_grab.seize's live_current calls it as the pulse arrives).
static func jolt(hero: CharacterBody3D, e: Node3D, charge := true) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	zap_hit(e, WIRE_DAMAGE * hero._dmg_mult * hero._cast_power())
	if charge:  # (round 44: the lightning stays in them, the element matrix's charged state; Live Wire marks after the hang)
		mark(e, "charged")
	Game.register_hit("cast")
	Game.sfx("hit_big", -8.0, 0.15)


## A hit carried by a current (Live Wire, Galvanize, the charged cells): the number and a flash, without the hit
## star and speed strokes a blow draws (live_current's pop is the zap's look; per jolt on five foes the stars and
## strokes were a green thicket over the tentacles).
static func zap_hit(e: Node3D, damage: float, launch := 0.0) -> void:
	if e.has_method("burn_hit") and launch <= 0.0:
		e.burn_hit(damage, false)
		if is_instance_valid(e.get("model")):
			Fx.flash(e.model)
	else:
		e.take_hit(damage, Vector3.ZERO, launch, false)


## The spear goes in the ground ahead of him. All the frost does is slow them (frost_spear.gd).
static func _plant(hero: CharacterBody3D, at: Vector3, fwd: Vector3) -> int:
	var spot: Vector3 = at + fwd * minf(SPEAR_AHEAD, hero._clear_ahead(fwd, SPEAR_AHEAD))
	SPEAR.plant(hero.get_parent(), spot)
	_pop(hero.get_parent(), spot, "spear")
	return FOES.near(hero.get_tree(), spot, SPEAR.RADIUS).size()


## Takes him to the spear while a SPEAR_RUN move plays. With none standing he stays on his line.
static func run_to_spear(hero: CharacterBody3D, delta: float) -> void:
	var s: Node3D = SPEAR.current(hero.get_tree())
	if s == null:
		return
	var to := _flat(s.global_position - hero.global_position)
	if to.length() <= SPEAR_GAP:
		hero.velocity.x = 0.0
		hero.velocity.z = 0.0
		return
	hero._face(to)
	var speed := minf(SPEAR_RUN_SPEED, (to.length() - SPEAR_GAP) / maxf(delta, 0.001))
	hero.velocity.x = to.normalized().x * speed
	hero.velocity.z = to.normalized().z * speed


## He comes down on the spear and it goes off: everyone on the frost freezes into a cube. With no spear
## left, it goes off where he lands.
static func _deep_freeze(hero: CharacterBody3D, at: Vector3, damage: float) -> int:
	var parent: Node = hero.get_parent()
	var s: Node3D = SPEAR.current(hero.get_tree())
	var spot: Vector3 = _flat(s.global_position) if s != null else at
	if s != null:
		s.shatter()
	SPEAR.frost_ring(parent, spot, DEEP_FREEZE_RADIUS, 0.3)
	under(parent, spot, "water")
	for i in DEEP_FREEZE_SPIKES:
		var a := TAU * i / DEEP_FREEZE_SPIKES
		ELEMENTS.spikes(parent, spot + Vector3(sin(a), 0.0, cos(a)) * DEEP_FREEZE_SPIKE_OUT, "water", 1.0, 2)
	Game.shake(0.5)
	var foes: Array = FOES.near(hero.get_tree(), spot, DEEP_FREEZE_RADIUS)
	for e: Node3D in foes:
		e.take_hit(damage, Vector3.DOWN * DEEP_FREEZE_DOWN, 0.0, true)
		Game.register_hit("cast")
		encase(e)
	return foes.size()


## Round 47: a tentacle goes out to everyone near him, all round, latches on, and carries each in a quick curve to a
## slot in a rank in front of him, where it freezes in a cube (harpoon_gather.gd). Big ones freeze where they stand.
## The row is what the pause after it leaps on (BREAKERS.EF: Shatterstorm / Slapshot) and what Ice Cube bowls.
static func _harpoon(hero: CharacterBody3D, at: Vector3, fwd: Vector3, reach: float, damage: float) -> int:
	var foes := harpoon_targets(hero, at, reach)
	hero._void.harpooned = foes.duplicate()
	if foes.is_empty():
		return 0
	var light: Array = foes.filter(func(e: Node3D) -> bool: return not hero._void.is_heavy(e))
	var slots := harpoon_slots(hero, at, fwd, light)
	var grabs := []
	for e: Node3D in foes:  # (nearest first: they latch in that order)
		grabs.append({"foe": e, "heavy": hero._void.is_heavy(e), "to": slots.get(e, _flat(e.global_position))})
	var g: Node3D = HARPOON_GATHER.start(hero, grabs)
	hero._void.gather = g
	var latched := [0]  # (only the first latch of this gather stops)
	g.on_latch = func(e: Node3D) -> void:
		e.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		if latched[0] == 0:
			Game.hitstop(LATCH_STOP)
		latched[0] += 1
		if e.has_method("stagger") and not hero._void.is_heavy(e):
			e.stagger(1.0)
	g.on_set = func(e: Node3D) -> void:
		encase(e)
		if Fx.DESIGNED.on():  # fx-ice3: frost cracks under the block, not ice chips (Zak: no crystals)
			preload("res://scripts/designed_elements.gd").frost_mark(hero.get_parent(), _flat(e.global_position), 0.7, 0.5)
		else:
			Fx.shards(hero.get_parent(), e.global_position + Vector3.UP * 0.4, Color(0.88, 0.97, 1.0), 6, Vector3.UP, 4.0, 0.12, 0.4)
	return foes.size()


## Who Harpoon takes: every living foe within `reach` of him, nearest first, HARPOON_MAX at most.
static func harpoon_targets(hero: CharacterBody3D, at: Vector3, reach: float) -> Array:
	var foes: Array = FOES.near(hero.get_tree(), at, reach).filter(func(e: Node3D) -> bool: return not THROWN.flying(e))
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	return foes.slice(0, HARPOON_MAX)


## Each foe's slot in the rank: across his aim HARPOON_SET m ahead (closer when a wall is nearer), side by side in
## the order they stand across his aim (so no two tentacles cross), each one's ice HARPOON_GAP clear of the next.
## A slot a wall would cut is drawn in towards him along its line.
static func harpoon_slots(hero: CharacterBody3D, at: Vector3, fwd: Vector3, foes: Array) -> Dictionary:
	var out := {}
	if foes.is_empty():
		return out
	var side := fwd.cross(Vector3.UP).normalized()
	var order := foes.duplicate()
	order.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return (a.global_position - at).dot(side) < (b.global_position - at).dot(side))
	var radii := order.map(func(e: Node3D) -> float: return ice_radius(e))
	var widths := radii.map(func(r: float) -> float: return r * 2.0)
	var total := 0.0
	for w: float in widths:
		total += w
	total += HARPOON_GAP * (order.size() - 1)
	var r_max := 0.0
	for r: float in radii:
		r_max = maxf(r_max, r)
	var ahead: float = clampf(hero._clear_ahead(fwd, HARPOON_SET + r_max + HARPOON_WALL) - r_max - HARPOON_WALL, HARPOON_SET_MIN, HARPOON_SET)
	var x := -total * 0.5
	for i in order.size():
		var e: Node3D = order[i]
		var half: float = widths[i] * 0.5
		var spot: Vector3 = at + fwd * ahead + side * (x + half)
		x += widths[i] + HARPOON_GAP
		var line := _flat(spot - at)
		var reach: float = line.length()
		if reach > 0.01:  # (a wall across a slot's line pulls it in)
			var clear: float = hero._clear_ahead(line / reach, reach + half + HARPOON_WALL) - half - HARPOON_WALL
			if clear < reach:
				spot = at + line / reach * maxf(clear, HARPOON_SET_MIN * 0.6)
		out[e] = _flat(spot)
	return out


## How far round `e` its ice reaches on the floor, from its feet: the cube it's in (fx-ice2 fits it to the model,
## a dummy's ~1.05 m flat, its corners ~15% more as it turns) or, before it has one, the block that would fit it
## now. The plain cube (r + 0.1) without designed ice. Harpoon spaces its row by it and Slapshot stops it off a wall.
static func ice_radius(e: Node3D) -> float:
	var cube: Node = e.get_node_or_null(THROWN.CUBE_NAME)
	if cube is MeshInstance3D and cube.mesh != null:
		var box: AABB = cube.mesh.get_aabb()
		var flat := Vector2(cube.position.x, cube.position.z).length()
		return maxf(box.size.x, box.size.z) * 0.5 * ICE_CORNER + flat
	if Game.comic_style and DESIGNED.on() and e.get("model") is Node3D:
		var fit: Dictionary = ELEMENTS.DESIGNED_EL.block_fit(ELEMENTS.DESIGNED_EL.model_points(e), -0.08 - e.global_position.y)
		return float(fit.r) / cos(PI / 6.0) * ICE_CORNER + Vector2(fit.centre.x, fit.centre.z).length()
	return float(e.get("radius")) + 0.1


## Freezes the nearest foe, the frozen first, and bowls it along his aim. Everyone it passes freezes.
static func _ice_cube(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	# Round 51 (fluidity): Ice Cube pressed while Harpoon's tentacles still carried the row found nobody (all of them
	# flying) and played at x1.00 (feel audit 4, left open); the carries land in their slots now and it bowls the row.
	if is_instance_valid(hero._void.gather) and not hero._void.gather.done():
		hero._void.gather.finish_now()
	var foes: Array = hero._void.reachable().filter(func(e: Node3D) -> bool:
		return not hero._void.is_heavy(e) and not THROWN.flying(e) and _flat(e.global_position - at).length() <= BOWL_REACH)
	if foes.is_empty():
		return 0
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var fa: bool = float(a.get("frozen_t") if a.get("frozen_t") != null else 0.0) > 0.0
		var fb: bool = float(b.get("frozen_t") if b.get("frozen_t") != null else 0.0) > 0.0
		if fa != fb:
			return fa
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var e: Node3D = foes[0]
	encase(e)
	_pop(hero.get_parent(), e.global_position, "spear")
	THROWN.launch(hero, e, e.global_position + fwd * BOWL_LENGTH, damage, {"pierce": true})
	return 1


## The arm swells into a fist and shoves everything in front of him along a line of lava. Whoever hits a
## wall takes it hard. Big foes don't move.
static func _palm(hero: CharacterBody3D, at: Vector3, fwd: Vector3, grow: float, power: float) -> int:
	var parent: Node = hero.get_parent()
	var length: float = minf(PALM_LENGTH * grow, hero._clear_ahead(fwd, PALM_LENGTH * grow) + 0.5)
	hero._void.fist = _fist(parent, at, fwd, length)
	ELEMENTS.fissure(parent, at, fwd, length, HARPOON_STEPS, "earth", 1.0)
	if not DESIGNED.on(): Fx.scorch(parent, at + fwd * length * 0.5, ELEMENTS.LOOK.earth.color, length * 0.5, 1.4)  # (designed: the fissure's seam is the mark)
	var foes := _ahead(hero, at, fwd, length, PALM_HALF_WIDTH)
	hero._void.shoved = foes
	for e: Node3D in foes:
		e.take_hit(PALM_DAMAGE * power, fwd * 4.0, 0.0, true)
		e.set_meta(PALM_META, Time.get_ticks_msec())  # (Meteor Fall only dives on these: meteor_spot)
		Game.register_hit("cast")
		if not hero._void.is_heavy(e) and e.is_alive():
			var walled: bool = THROWN.clear_from(hero, e, e.global_position, fwd, PALM_WALL_REACH) < PALM_WALL_REACH
			if walled:
				e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + PALM_CUE_MS)
			THROWN.launch(hero, e, e.global_position + fwd * (PALM_WALL_REACH if walled else PALM_SHOVE), PALM_SPLAT * power,
				{"quiet": true, "solid": false, "el": "earth", "speed": PALM_SPEED, "land_y": 0.0, "wall_mult": PALM_WALL_MULT})
	return foes.size()


## A fist of the arm's own stuff, flying out along `fwd`.
static func _fist(parent: Node, at: Vector3, fwd: Vector3, length: float) -> Node3D:
	if Game.comic_style: return COMIC_FIST.spawn(parent, at, fwd, length, FIST_TIME)  # the flat inked fist
	var root := Node3D.new()
	parent.add_child(root)
	var from := at + fwd * 1.0 + Vector3.UP * 1.0
	root.global_position = from
	root.look_at(from + fwd, Vector3.UP)
	var mat: Material = null
	if DisplayServer.get_name() != "headless":
		mat = ComicLook.material("P_Tendril", ComicLook.hero_kind()).duplicate()
		mat.next_pass = Fx.ink_material()
	var parts := [[Vector3.ZERO, FIST_RADIUS]]
	for i in 4:  # knuckles, along the front
		parts.append([Vector3((i - 1.5) * FIST_RADIUS * 0.5, FIST_RADIUS * 0.35, -FIST_RADIUS * 0.8), FIST_RADIUS * 0.34])
	for p: Array in parts:
		var ball := SphereMesh.new()
		ball.radius = p[1]
		ball.height = p[1] * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("no_ghost", true)
		mi.position = p[0]
		root.add_child(mi)
	root.scale = Vector3.ONE * 0.4
	var tw := root.create_tween()
	tw.set_parallel()
	tw.tween_property(root, "global_position", at + fwd * length + Vector3.UP * 1.0, FIST_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(root, "scale", Vector3.ONE, FIST_TIME * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(root, "scale", Vector3.ONE * 0.1, 0.12).set_delay(0.08)
	tw.chain().tween_callback(root.queue_free)
	return root


## Tendrils up through the floor take everyone near him down into lava, where they stay and burn.
static func _undertow(hero: CharacterBody3D, at: Vector3, power: float) -> int:
	var foes: Array = FOES.near(hero.get_tree(), at, UNDERTOW_RADIUS)
	for e: Variant in hero._void.shoved:  # (it follows them, however far they went)
		if is_instance_valid(e) and e.is_alive() and not e in foes and _flat(e.global_position - at).length() <= UNDERTOW_CHASE:
			foes.append(e)
	hero._void.shoved = []
	hero._void.bound = foes
	if not foes.is_empty():
		hero._void.undertow = BIND.bind(hero, foes, {"time": UNDERTOW_TIME, "sink": UNDERTOW_SINK, "tick_damage": UNDERTOW_TICK * power, "ropes": 2,
			"color": ELEMENTS.LOOK.earth.color, "wells": true})
	return foes.size()


## What he comes down inside on Meteor Fall: a ball of fire with flames streaming back up the way he came.
static func meteor_shell(parent: Node, travel: Vector3) -> Node3D:
	if DESIGNED.on(): return ELEMENTS.DESIGNED_EL.meteor_shell(parent, travel)  # (designed: the drawn fireball)
	var root := Node3D.new()
	parent.add_child(root)
	root.look_at_from_position(Vector3.ZERO, travel.normalized(), Vector3.RIGHT if absf(travel.normalized().y) > 0.95 else Vector3.UP)
	var outer := _meteor_mat(METEOR_COLOR, true)
	var hot := _meteor_mat(METEOR_HOT, false)
	_meteor_part(root, _meteor_ball(METEOR_R), outer, Vector3.ZERO)
	_meteor_part(root, _meteor_ball(METEOR_R * 0.6), hot, Vector3.ZERO)
	for i in METEOR_TONGUES:
		var a := TAU * i / METEOR_TONGUES
		var side := Vector3(cos(a), sin(a), 0.0) * METEOR_R * 0.55
		var long := METEOR_TAIL * (1.0 if i % 2 == 0 else 0.65)
		var cone := CylinderMesh.new()
		cone.top_radius = METEOR_TONGUE_R
		cone.bottom_radius = 0.0
		cone.height = long
		cone.radial_segments = 6
		var flame := _meteor_part(root, cone, outer if i % 2 == 0 else hot, side + Vector3(0.0, 0.0, long * 0.5))
		flame.rotation.x = -PI * 0.5  # the wide end at the ball, the point behind it (+Z, away from where it faces)
	return root


static func _meteor_mat(color: Color, ink: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	if ink and DisplayServer.get_name() != "headless":
		mat.next_pass = Fx.ink_material()
	return mat


static func _meteor_ball(r: float) -> SphereMesh:
	var ball := SphereMesh.new()
	ball.radius = r
	ball.height = r * 2.0
	ball.radial_segments = 10
	ball.rings = 5
	return ball


static func _meteor_part(root: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.position = at
	return m


## A black pool opens under whoever he's aiming at, and tendrils come up out of it and pile on. Big foes
## too: they can't be pinned, but it drags on them, and the damage is the same.
static func _overwhelm(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(OVERWHELM_AHEAD, hero._clear_ahead(fwd, OVERWHELM_AHEAD))
	var aim: Node3D = ENV.picked_foe(hero, "overwhelm")  # (round 51: the charge's bracket, the cursor's or the auto one)
	if aim == null or _flat(aim.global_position - at).length() > OVERWHELM_REACH + 1.0:
		aim = overwhelm_aim(hero, at, fwd)
	if aim != null:
		spot = _flat(aim.global_position)
	hero._void.dark_spot = spot
	DARK.pool(parent, spot, OVERWHELM_RADIUS, OVERWHELM_TIME)
	DARK.burst(parent, spot, 1.4)
	var foes: Array = FOES.near(hero.get_tree(), spot, OVERWHELM_RADIUS).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	hero._void.dark_bind = null
	if not foes.is_empty():
		hero._void.dark_bind = BIND.bind(hero, foes, {"time": OVERWHELM_TIME, "tick_damage": OVERWHELM_TICK * power, "step": 0.2, "ropes": 2,
			"sink": 0.4, "color": DARK.VIOLET})
	return foes.size()


## Who Overwhelm pins by default: the nearest foe in his aim cone within OVERWHELM_REACH, or null.
static func overwhelm_aim(hero: CharacterBody3D, at: Vector3, fwd: Vector3) -> Node3D:
	var aim: Node3D = null
	var best := INF
	for e: Node3D in FOES.near(hero.get_tree(), at, OVERWHELM_REACH):
		var to := _flat(e.global_position - at)
		if to.length() > 0.01 and rad_to_deg(fwd.angle_to(to.normalized())) > hero._void.CONE:
			continue
		if to.length() < best:
			best = to.length()
			aim = e
	return aim


## H H: what it holds comes down, and a black hole tears open where it hits (dark_fx.Hole).
static func _singularity(hero: CharacterBody3D, power: float) -> int:
	var spot: Vector3 = _flat(hero._void._aim_at)
	hero._void.dark_spot = spot
	var hole := DARK.Hole.new()
	hole.hero = hero
	hole.power = power
	hero.get_parent().add_child(hole)
	hole.global_position = spot + Vector3.UP * 0.05
	hero._void.hole = hole
	return FOES.near(hero.get_tree(), spot, DARK.Hole.RADIUS).size()


## H L: a crescent of darkness through everyone in front of him, and it leaves a mark on them.
static func _reap(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	DARK.reap(hero.get_parent(), at, fwd, REAP_REACH, REAP_HALF_ANGLE)
	var n := 0
	for e: Node3D in FOES.near(hero.get_tree(), at, REAP_REACH):
		var to := _flat(e.global_position - at)
		if to.length() > 0.3 and fwd.angle_to(to.normalized()) > REAP_HALF_ANGLE:
			continue
		e.take_hit(damage, to.normalized() * 3.0 if to.length() > 0.01 else Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		DARK.mark(e)
		n += 1
	return n


## H L H: a pool opens in front of him and everyone marked is dragged across the floor into it, however
## far off they are. With nobody marked, it takes who's near. Big foes hold their ground and take the hit.
static func _black_tide(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(TIDE_AHEAD, hero._clear_ahead(fwd, TIDE_AHEAD))
	var foes: Array = FOES.near(hero.get_tree(), at, TIDE_REACH).filter(func(e: Node3D) -> bool:
		return DARK.marked(e) and not THROWN.flying(e))
	if foes.is_empty():
		foes = FOES.near(hero.get_tree(), at, TIDE_NEAR).filter(func(e: Node3D) -> bool:
			return not THROWN.flying(e))
	hero._void.dark_spot = spot
	DARK.pool(parent, spot, TIDE_POOL_R, TIDE_TIME)
	for i in foes.size():
		var e: Node3D = foes[i]
		DARK.unmark(e)
		e.take_hit(TIDE_DAMAGE * power, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		if hero._void.is_heavy(e):
			continue
		var a := TAU * i / maxf(foes.size(), 1.0)
		var to: Vector3 = spot + Vector3(sin(a), 0.0, cos(a)) * TIDE_RING
		var speed: float = maxf(TIDE_SPEED, e.global_position.distance_to(to) / TIDE_ARRIVE)
		THROWN.launch(hero, e, to, 0.0, {"quiet": true, "solid": false, "el": "void", "speed": speed, "land_y": 0.0})
	if not foes.is_empty():
		BIND.bind(hero, foes, {"time": TIDE_TIME, "tick_damage": 2.0 * power, "ropes": 0, "sink": 0.5, "color": DARK.VIOLET})
	return foes.size()


## Whoever's on the line he just dashed or swung along is yanked together in front of him.
static func _tow(hero: CharacterBody3D, at: Vector3, fwd: Vector3, damage: float) -> int:
	var foes: Array = _tow_line(hero, at)
	var to := at + fwd * minf(TOW_AHEAD, hero._clear_ahead(fwd, TOW_AHEAD))
	var n := 0
	var anchor: Node3D = ENV.foe_chosen(hero, "tow")  # (round 52: the cursor's foe: they're yanked into it)
	if anchor != null and _flat(anchor.global_position - at).length() <= TOW_PICK_REACH + 0.5 and not THROWN.flying(anchor):
		foes.erase(anchor)
		to = _flat(anchor.global_position)
		anchor.take_hit(damage * TOW_ANCHOR_MULT, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		anchor.set_meta(CAMERA_CUE, Time.get_ticks_msec() + 700)
		n += 1
	for e: Node3D in foes:
		if hero._void.is_heavy(e):
			e.take_hit(damage * 0.5, Vector3.ZERO, 0.0, true)
			Game.register_hit("cast")
		else:
			THROWN.launch(hero, e, to, damage, {"el": "void", "tether": true, "speed": TOW_SPEED, "land_y": 0.0})
		n += 1
	return n


## Tow Line's snare candidates (round 52): who it takes, and anyone else the cursor may make the anchor.
static func tow_candidates(hero: CharacterBody3D, at: Vector3) -> Array:
	var out: Array = _tow_line(hero, at)
	for e: Node3D in FOES.near(hero.get_tree(), at, TOW_PICK_REACH):
		if not out.has(e) and not THROWN.flying(e):
			out.append(e)
	return out


## The auto pick: of `snare`, the one nearest where Tow Line yanks them to.
static func tow_auto(hero: CharacterBody3D, at: Vector3, snare: Array) -> Node3D:
	var fwd: Vector3 = hero._facing()
	var to := at + fwd * minf(TOW_AHEAD, hero._clear_ahead(fwd, TOW_AHEAD))
	var best: Node3D = null
	for e: Node3D in snare:
		if best == null or _flat(e.global_position).distance_to(to) < _flat(best.global_position).distance_to(to):
			best = e
	return best


## Who Tow Line takes: whoever's on the line he just dashed along, or near him if nobody is.
static func _tow_line(hero: CharacterBody3D, at: Vector3) -> Array:
	var from: Vector3 = _flat(hero._dash_from)
	var line := at - from
	var foes: Array = []
	if line.length() > 0.5:
		foes = _ahead(hero, from, line.normalized(), line.length() + 1.5, TOW_HALF_WIDTH)
	if foes.is_empty():
		foes = FOES.near(hero.get_tree(), at, TOW_NEAR)
	return foes


# --- Crossovers (round 34): a string that changes element, with a payoff only the pair gives --------------------
# Looks (round 37): comic_boulder (Rockslide), comic_fault (Fault Line, Cataclysm), comic_steam (Steam Burst),
# comic_freeze_over (Flash Freeze, Black Ice), comic_arc (Storm Pitch); words in
# ComicFx.MOVE_WORDS / BREAKER_WORDS. See docs/features/void-element.md "Crossover looks".
# Second pass looks (the three-element strings below `_cataclysm`): comic_hail (Hailstorm), comic_melt (Meltdown),
# comic_erupt (Eruption), comic_impale (Impale), comic_backdraft (Backdraft), comic_anvil (Anvil), comic_rip (Tow
# Line's rip out of the air); the states' tells are comic_state_tell (enemy.gd syncs it). The improvised payoffs
# (`_cash_buried`, Molten Palm's steam) reuse their crossover's look.

## L H L L: wind into earth. The hammer comes down off the air string and everyone near the blow is driven into
## the floor together; the ones Updraft Lash had in the air take double.
static func _rockslide(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * minf(ROCKSLIDE_AHEAD, hero._clear_ahead(fwd, ROCKSLIDE_AHEAD))
	var foes: Array = FOES.near(hero.get_tree(), spot, ROCKSLIDE_RADIUS * hero._cast_grow()).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	hero._void.buried = []
	COMIC_BOULDER.spawn(parent, spot, foes.map(func(e: Node3D) -> Vector3: return _flat(e.global_position)))
	Fx.scorch(parent, spot, ELEMENTS.LOOK.earth.color, 2.2, 0.6)
	for e: Node3D in foes:
		var up: bool = e.is_airborne()
		var to := _flat(spot - e.global_position)
		var kb: Vector3 = (to.normalized() * ROCKSLIDE_IN if to.length() > 0.6 else Vector3.ZERO) + Vector3.DOWN * ROCKSLIDE_DOWN
		e.take_hit(ROCKSLIDE_DAMAGE * power * (ROCKSLIDE_AIR_MULT if up else 1.0), kb, 0.0, true)
		Game.register_hit("cast")
		if up:
			hero._void.buried.append(e)
	Game.shake(0.5)
	return foes.size()


## L H L L H: earth into wind. Cracks run from him to everyone near, and the gale comes up out of each one and
## throws them back into the air, Rockslide's buried twice as hard. The window opens (Cataclysm).
static func _fault_line(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var foes: Array = FOES.near(hero.get_tree(), at, FAULT_REACH * hero._cast_grow()).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e))
	if foes.is_empty():
		COMIC_FAULT.spawn(parent, at, [at + fwd * 4.0])
		return 0
	COMIC_FAULT.spawn(parent, at, foes.map(func(e: Node3D) -> Vector3: return _flat(e.global_position)))
	for e: Node3D in foes:
		var buried: bool = e in hero._void.buried
		e.take_hit(FAULT_DAMAGE * power * (FAULT_BURIED_MULT if buried else 1.0), Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else FAULT_LAUNCH, true)
		mark(e, "charged")  # (the storm came up out of the crack with it)
		Game.register_hit("cast")
	hero._void.buried = []
	return foes.size()


## Dash L H H L: ice into magma. The fist drives lava into the ice: every frozen foe near him goes off in
## steam (the ice's FREEZE_BREAK on top), up into the air, and the steam scalds whoever's beside it. With
## nobody frozen it's only a shove of molten fist. The window opens (Flash Freeze).
static func _steam_burst(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	# (a cube Ice Cube is still bowling counts: Dash L H H L fires while it's in flight, so it's cut out of its roll)
	var frozen: Array = FOES.near(hero.get_tree(), at, STEAM_REACH).filter(func(e: Node3D) -> bool: return is_frozen(e))
	for e: Node3D in frozen:
		THROWN.cut(e)
	var reach := STEAM_FIST
	if not frozen.is_empty():
		var mid := Vector3.ZERO
		for e: Node3D in frozen:
			mid += _flat(e.global_position)
		mid /= float(frozen.size())
		reach = clampf(_flat(mid - at).length(), 2.0, PALM_LENGTH)
		var to := _flat(mid - at)
		if to.length() > 0.5:
			hero._face(to)
			fwd = to.normalized()
	hero._void.fist = _fist(parent, at, fwd, minf(reach, hero._clear_ahead(fwd, reach) + 0.5))
	if frozen.is_empty():
		var near := _ahead(hero, at, fwd, STEAM_FIST, PALM_HALF_WIDTH)
		for e: Node3D in near:
			e.take_hit(PALM_DAMAGE * power * 0.5, fwd * 4.0, 0.0, true)
			Game.register_hit("cast")
		return near.size()
	var scalded := {}
	for e: Node3D in frozen:
		var spot := _flat(e.global_position)
		THROWN.remove_cube(e)
		e.take_hit(STEAM_DAMAGE * power, Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else STEAM_LAUNCH, true)  # (frozen: x FREEZE_BREAK)
		Game.register_hit("cast")
		Fx.shards(parent, spot + Vector3.UP * 0.9, THROWN.CUBE_COLOR, 6, Vector3.UP, 9.0, 0.16, 0.5)
		COMIC_STEAM.spawn(parent, spot)
		for o: Node3D in FOES.near(hero.get_tree(), spot, STEAM_SPLASH):
			if o in frozen or scalded.has(o):
				continue
			scalded[o] = true
			var out := _flat(o.global_position - spot)
			o.take_hit(STEAM_SPLASH_DAMAGE * power, (out.normalized() if out.length() > 0.01 else fwd) * 4.0, 0.0, false)
			Game.register_hit("cast")
	Game.shake(0.55)
	return frozen.size() + scalded.size()


## Dash H L: dark into storm. Whoever Tow Line bunched in front of him is hurled on by the axe, crackling: each
## one flies along his aim with lightning jumping from it to anyone it passes (thrown_foe `zap`), and bursts in
## wind where it lands. Big ones stay and take the jolt.
static func _pitch(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = at + fwd * PITCH_AHEAD
	var foes: Array = FOES.near(hero.get_tree(), spot, PITCH_GRAB)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var hand := at + Vector3.UP * 1.3 + fwd * 0.6
	var last := hand
	for i in foes.size():
		var e: Node3D = foes[i]
		COMIC_ARC.jump(parent, last, e.global_position + Vector3.UP)
		last = e.global_position + Vector3.UP
		if hero._void.is_heavy(e):
			e.take_hit(PITCH_DAMAGE * power * 0.6, Vector3.ZERO, 0.0, true)
			Game.register_hit("cast")
			continue
		THROWN.cut(e)  # (still on Tow Line's tether: the axe takes it from there)
		mark(e, "charged")
		var side := (float(i) - (foes.size() - 1) * 0.5) * PITCH_SPREAD
		var dir := fwd.rotated(Vector3.UP, side)
		var flight: Node = THROWN.launch(hero, e, _flat(e.global_position) + dir * PITCH_LENGTH, PITCH_DAMAGE * power,
			{"el": "wind", "solid": true, "speed": PITCH_SPEED, "zap": true})
		COMIC_ARC.ride(parent, e, flight)  # (the storm rides it for the flight)
	return foes.size()


## H L L: dark into storm (round 44). A tentacle goes out to each foe Reap marked, wherever it stands (the nearest
## GALV_LINKS within GALV_REACH; nobody marked: those in front within GALV_NEAR), the charge gathers at his claw and
## runs down every tentacle (live_current.gd): each linked foe is zapped as it arrives, GALV_DAMAGE x (1 +
## GALV_LINK_BONUS per other link), then arcs jump on to the foes near them no tentacle reached (GALV_JUMP, chained).
static func _galvanize(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var tree := hero.get_tree()
	var linked: Array = FOES.near(tree, at, GALV_MARK_REACH).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e) and (DARK.marked(e) or _flat(e.global_position - at).length() <= GALV_REACH))
	linked.sort_custom(func(a: Node3D, b: Node3D) -> bool:  # (the marked first past the cap)
		var ma: bool = DARK.marked(a)
		if ma != DARK.marked(b):
			return ma
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	linked = linked.slice(0, GALV_LINKS)
	linked.sort_custom(func(a: Node3D, b: Node3D) -> bool:  # (nearest first: they latch in that order)
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	var marked := {}
	for e: Node3D in linked:
		if DARK.marked(e):
			marked[e] = true
	if linked.is_empty():  # nobody to latch onto: it crackles out ahead
		var from := at + Vector3.UP * 1.3 + fwd * 0.6
		for k: float in [3.0, 6.0]:
			ELEMENTS.arc(hero.get_parent(), from, at + fwd * k + Vector3.UP, ELEMENTS.LOOK.wind.color)
		return 0
	var each: float = GALV_DAMAGE * power * (1.0 + GALV_LINK_BONUS * (linked.size() - 1))
	var c: Node3D = LIVE_CURRENT.start(hero, linked.map(func(e: Node3D) -> Dictionary: return {"foe": e}), true)
	c.stagger = GALV_STAGGER
	c.hold = GALV_HOLD
	c.together = GALV_TOGETHER
	c.fat = GALV_FAT
	c.on_zap = func(e: Node3D, _p: int) -> void:  # a real hit: star, flash, number, and the jolt (a stagger)
		var out := _flat(e.global_position - hero.global_position)
		e.take_hit(each * (GALV_MARK_MULT if marked.has(e) else 1.0), (out.normalized() if out.length() > 0.01 else fwd) * 2.0, 0.0, true)
		if not hero._void.is_heavy(e) and e.has_method("stagger"):
			e.stagger(GALV_STUN)
		mark(e, "charged")
		Game.register_hit("cast")
	c.on_burst = func(foes: Array) -> void:  # all at once: the hit stop and the word, bigger the more linked
		var n := linked.size()
		Game.hitstop(minf(GALV_STOP + GALV_STOP_PER * (n - 1), GALV_STOP_MAX))
		Game.shake(0.25 + 0.06 * n)
		var mid := Vector3.ZERO
		for e: Variant in foes:
			if is_instance_valid(e):
				mid += (e as Node3D).global_position
		ComicFx.say(ComicFx.MOVE_WORDS["XC"], mid / maxf(foes.size(), 1), GALV_WORD + GALV_WORD_PER * (n - 1))
	c.on_jump = func(e: Node3D, _from: Variant) -> void:
		zap_hit(e, GALV_JUMP_DAMAGE * power)
		mark(e, "charged")
		Game.register_hit("cast")
	c.find_jumps = func() -> Array: return _jumps(tree, linked, GALV_JUMP, GALV_JUMPS)
	c.pulse()
	return linked.size()


# --- Lava Leash (L L L H L, dark-magma lane): magma into dark, the sixth crossover ------------------------------

## L L L H L: magma into dark. A tentacle goes out to every foe this string's Molten Palm hit, wherever the palm sent
## it (the wall too), latches, and drags it back along the floor through the lava into a pile LEASH_PILE m in front of
## him (lava_leash.gd); the far ones pay most, torn off a wall more. When the last lands, the seam erupts under the
## pile: molten and bound. Its breaker is Hellseam.
static func _lava_leash(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var foes := leash_targets(hero, at, fwd)
	var pile: Vector3 = at + fwd * minf(LEASH_PILE, hero._clear_ahead(fwd, LEASH_PILE))
	hero._void.dark_spot = pile
	if foes.is_empty():  # nobody to latch onto: the tentacle cracks the floor ahead and a little lava comes up
		ELEMENTS.fissure(parent, at, fwd, 3.5, 3, "earth", 0.8)
		return 0
	var light: Array = foes.filter(func(e: Node3D) -> bool: return not hero._void.is_heavy(e))
	var slots := leash_slots(pile, fwd, light)
	var grabs := []
	var now := Time.get_ticks_msec()
	for e: Node3D in foes:  # (nearest first: they latch in that order)
		e.set_meta(CAMERA_CUE, now + LEASH_CUE_MS)  # (the far one, at the wall, stays in the framing)
		grabs.append({"foe": e, "heavy": hero._void.is_heavy(e), "to": slots.get(e, _flat(e.global_position))})
	var g: Node3D = LAVA_LEASH.start(hero, grabs, pile)
	var latched := [0]  # (only the first latch stops)
	g.on_latch = func(e: Node3D) -> void:
		THROWN.cut(e)  # (still on the palm's shove: the leash takes it from here)
		e.take_hit(LEASH_DAMAGE * power, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		if latched[0] == 0:
			Game.hitstop(LATCH_STOP)
		latched[0] += 1
		if e.has_method("stagger") and not hero._void.is_heavy(e):
			e.stagger(1.0)
	g.on_arrive = func(e: Node3D, metres: float) -> void:
		e.set_meta(LEASH_META, metres)
		var d: float = leash_drag_damage(metres, wall_fresh(e)) * power  # (torn off the wall the palm splatted it on)
		if d > 0.0:
			var into := _flat(pile - e.global_position)
			e.take_hit(d, (into.normalized() if into.length() > 0.01 else fwd) * 1.5, 0.0, true)
			Game.register_hit("cast")
	g.on_erupt = func(piled: Array) -> void:
		var n := piled.size()
		var each: float = leash_erupt_damage(n) * power
		for e: Node3D in piled:
			e.take_hit(each, Vector3.ZERO, 0.0, true)
			mark(e, "molten")
			Game.register_hit("cast")
		g.bind = BIND.bind(hero, piled, {"time": LEASH_BIND_TIME, "tick_damage": LEASH_TICK * power, "ropes": 0, "sink": LEASH_SINK,
			"color": ELEMENTS.LOOK.earth.color})
		Game.hitstop(LEASH_STOP + LEASH_STOP_PER * (n - 1))
		Game.shake(0.3 + 0.05 * n)
		ComicFx.say(ComicFx.MOVE_WORDS["XL"], pile + Vector3.UP * 0.6, LEASH_WORD + LEASH_WORD_PER * (n - 1))
	return foes.size()


## Who Lava Leash takes: every living foe Molten Palm hit (palm_fresh) within LEASH_REACH of him, nearest first,
## LEASH_MAX at most (in flight on the palm's shove too: the latch cuts it). Nobody the palm hit: whoever is in the
## palm's strip ahead of him.
static func leash_targets(hero: CharacterBody3D, at: Vector3, fwd: Vector3) -> Array:
	var foes: Array = FOES.near(hero.get_tree(), at, LEASH_REACH).filter(func(e: Node3D) -> bool: return palm_fresh(e))
	if foes.is_empty():
		foes = _ahead(hero, at, fwd, PALM_LENGTH, PALM_HALF_WIDTH).filter(func(e: Node3D) -> bool: return not THROWN.flying(e))
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
	return foes.slice(0, LEASH_MAX)


## Where each lands in the pile: round its middle LEASH_RING m out, in the order they stand across his aim, so no two
## drags cross; one alone lands on the middle. Pure, so the check can walk it.
static func leash_slots(pile: Vector3, fwd: Vector3, foes: Array) -> Dictionary:
	var out := {}
	if foes.is_empty():
		return out
	if foes.size() == 1:
		out[foes[0]] = _flat(pile)
		return out
	var side := fwd.cross(Vector3.UP).normalized()
	var order := foes.duplicate()
	order.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return (a.global_position - pile).dot(side) < (b.global_position - pile).dot(side))
	for i in order.size():  # an arc on the far side of the pile, from one side of his aim round to the other
		var a := lerpf(-PI * 0.8, PI * 0.8, float(i) / (order.size() - 1))
		out[order[i]] = _flat(pile + (fwd * cos(a) + side * sin(a)) * LEASH_RING)
	return out


## The drag's damage for `metres` dragged (to LEASH_DRAG_CAP), x LEASH_WALL_MULT torn off a wall.
static func leash_drag_damage(metres: float, walled: bool) -> float:
	return LEASH_PER_M * minf(metres, LEASH_DRAG_CAP) * (LEASH_WALL_MULT if walled else 1.0)


## The seam's eruption under a pile of `n`, each.
static func leash_erupt_damage(n: int) -> float:
	return LEASH_ERUPT * (1.0 + LEASH_PILE_PER * maxi(n - 1, 0))


## Hellseam (Lava Leash's breaker) lands: the pile is driven into the floor, each harder the further the leash dragged
## it; then the eruption runs back out along every seam a foe was dragged down (lava_leash.seams()), a geyser every
## HELLSEAM_STEP m, and anyone else standing on one takes HELLSEAM_SEAM of it.
static func _hellseam(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var tree := hero.get_tree()
	var spot: Vector3 = hero._void.dark_spot
	var seams: Array = LAVA_LEASH.seams(hero)
	LAVA_LEASH.let_go(hero)  # (the leash's tentacles and its bind: the landing takes them)
	var struck := {}
	for e: Node3D in FOES.near(tree, spot, HELLSEAM_PILE_R):
		var metres := minf(float(e.get_meta(LEASH_META, 0.0)), LEASH_DRAG_CAP)
		e.take_hit(damage * (1.0 + HELLSEAM_PER_M * metres), Vector3.DOWN * HELLSEAM_DOWN, 0.0, true)
		mark(e, "molten")
		Game.register_hit("breaker")
		if e.has_meta(LEASH_META):
			e.remove_meta(LEASH_META)
		struck[e] = true
	if seams.is_empty():  # (no leash to run down: one seam straight out ahead of the landing)
		var fwd: Vector3 = hero._facing()
		seams = [[_flat(spot + fwd * 5.0), _flat(spot)]]
	var now := Time.get_ticks_msec()
	for s: Array in seams:
		var from: Vector3 = s[1]  # the pile end
		var run := _flat(s[0] - from)  # out to where it was taken from
		var steps := maxi(1, int(run.length() / HELLSEAM_STEP))
		for k in range(1, steps + 1):
			var p: Vector3 = from + run * (float(k) / steps)
			for e: Node3D in FOES.near(tree, p, HELLSEAM_SEAM_R):
				e.set_meta(CAMERA_CUE, now + HELLSEAM_CUE_MS)
			var delay: float = HELLSEAM_DELAY + run.length() * float(k) / steps * HELLSEAM_RUN
			tree.create_timer(delay, false).timeout.connect(_seam_geyser.bind(hero, p, damage * HELLSEAM_SEAM, struck))
	Game.shake(0.6)


static func _seam_geyser(hero: Variant, p: Vector3, damage: float, struck: Dictionary) -> void:
	if not is_instance_valid(hero) or not hero.is_inside_tree():
		return
	var parent: Node = hero.get_parent()
	if Game.comic_style and DESIGNED.on():
		ELEMENTS.DESIGNED_EL.geyser(parent, p, HELLSEAM_GEYSER)
	else:
		ELEMENTS.geyser(parent, p, 0.6, HELLSEAM_GEYSER)
	for e: Node3D in FOES.near(hero.get_tree(), p, HELLSEAM_SEAM_R):
		if struck.has(e):
			continue
		struck[e] = true
		e.take_hit(damage, Vector3.ZERO, BREAK_LAUNCH, true)
		mark(e, "molten")
		Game.register_hit("breaker")


## Who an arc reaches from `from`: foes within `reach` of one of them, then of those, and so on (nearest first),
## none of `from` itself, at most `most`.
static func _jumps(tree: SceneTree, from: Array, reach: float, most: int) -> Array:
	var out := []
	var front: Array = from.filter(func(e: Variant) -> bool: return is_instance_valid(e))
	while not front.is_empty() and out.size() < most:
		var nxt := []
		for f: Node3D in front:
			for o: Node3D in FOES.near(tree, f.global_position, reach):
				if not o in from and not o in out and not o in nxt and not THROWN.flying(o):
					nxt.append(o)
		for o: Node3D in nxt.slice(0, most - out.size()):
			out.append(o)
		front = nxt
	return out


## Black Ice's press (hero_leap._start_dive): the pool freezes, with everyone in it.
static func freeze_pool(hero: CharacterBody3D) -> void:
	var parent: Node = hero.get_parent()
	var spot: Vector3 = hero._void.dark_spot
	COMIC_FREEZE.pool(parent, spot, MAW_RADIUS + 0.3)
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS + 0.5):
		encase(e)


## Black Ice lands: the frozen pool gives, and everyone in it shatters down into the floor.
static func _black_ice(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	COMIC_FREEZE.shatter(parent, spot, MAW_RADIUS + 0.3)  # (the frozen pool breaks up: was a splat, spikes and shards each)
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS + 0.5):
		e.take_hit(damage, Vector3.DOWN * BLACK_ICE_DOWN, 0.0, true)  # (frozen: x FREEZE_BREAK, and it shatters)
		Game.register_hit("breaker")
	ComicFx.hit(spot + Vector3.UP * 1.5, true)
	Game.shake(0.6)


## Short Circuit lands (SC_*): the held take a little and are spent; the charge arcs out to everyone else in reach.
static func _short_circuit(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var held: Array = seized.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	for e: Node3D in held:
		e.take_hit(damage * SC_HELD_MULT, Vector3.ZERO, 0.0, true)
		unmark(e, "charged")  # (spent)
		Game.register_hit("breaker")
	var out: Array = FOES.near(hero.get_tree(), at, SC_REACH).filter(func(e: Node3D) -> bool:
		return not e in held and not THROWN.flying(e))
	out.sort_custom(func(a: Node3D, c: Node3D) -> bool:
		return _flat(a.global_position - at).length() < _flat(c.global_position - at).length())
	for g: Node3D in ENV_PIECE.live_grates(hero.get_tree()):  # round 51 (Live Floor): the grate carries it too
		for e: Node3D in FOES.near(hero.get_tree(), _flat(g.global_position), SC_REACH):
			if not e in held and not e in out and not THROWN.flying(e):
				out.append(e)
	for t: Node3D in ENV_PIECE.conducting_torches(hero.get_tree()):  # round 52 (torches conduct): each torch reaches too
		for e: Node3D in FOES.near(hero.get_tree(), _flat(t.global_position), ENV_PIECE.CONDUCT_REACH):
			if not e in held and not e in out and not THROWN.flying(e):
				out.append(e)
	out = out.slice(0, SC_ARCS)
	for e: Node3D in out:  # (feel audit 3: the camera takes them in before the arcs land, not after)
		e.set_meta(&"frame_cue_ms", Time.get_ticks_msec() + SC_CUE_MS)
	var each := damage * SC_ARC_MULT * (1.0 + SC_PER_HELD * maxi(held.size() - 1, 0))
	var from: Array = held.duplicate() if not held.is_empty() else [hero]
	from.append_array(ENV_PIECE.live_grates(hero.get_tree()))  # round 51 (Live Floor): an arc may start from a live grate
	from.append_array(ENV_PIECE.conducting_torches(hero.get_tree()))  # round 52: or from a conducting torch's flame
	for i in out.size():  # one after another, out from the pile: a link further each, a beat harder each
		hero.get_tree().create_timer(SC_DELAY + SC_STEP * i).timeout.connect(_sc_arc.bind(hero, out[i], from, each, i))
	under(parent, at, "wind")
	_pop(parent, at, "axe")


## One of Short Circuit's arcs: from the nearest of `from` (the held and the arcs before) to `e`, the `i`th link.
static func _sc_arc(hero: Variant, e: Variant, from: Array, each: float, i: int) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var src: Variant = null
	for f: Variant in from:
		if is_instance_valid(f) and (src == null or f.global_position.distance_to(e.global_position) < src.global_position.distance_to(e.global_position)):
			src = f
	var a: Vector3 = (src.global_position if src != null else hero.global_position) + Vector3.UP * 0.9
	if src != null and ENV_PIECE.tag_of(src) == "torch":  # (round 52: out of its flame)
		a = src.global_position + Vector3.UP * ENV_PIECE.CONDUCT_FLAME
	COMIC_BOLT.spawn(hero.get_parent(), a, e.global_position + Vector3.UP * 0.9, 0.26 + 0.02 * i, 0.5 + 0.06 * i, 2)
	var away := _flat(e.global_position - a)
	e.take_hit(each, (away.normalized() if away.length() > 0.01 else Vector3.ZERO) * 3.0, 0.0, true)
	if not hero._void.is_heavy(e) and e.has_method("stagger"):
		e.stagger(SC_STUN)
	mark(e, "charged")
	Game.register_hit("breaker")
	Game.hitstop(SC_STOP + SC_STOP_PER * i)
	from.append(e)


## Cataclysm lands: everyone held comes down into the floor (a crater each), with lightning out of the sky and
## the earth up under each one. Anyone else near takes some and is thrown clear.
static func _cataclysm(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var spots := []
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		spots.append(_flat(e.global_position))
		e.take_hit(damage, Vector3.DOWN * CATACLYSM_DOWN, 0.0, true)
		mark(e, "charged")  # (the strike out of the sky stays in them)
		Game.register_hit("breaker")
	COMIC_FAULT.spawn(parent, at, spots, true)  # (a crack to each, a strike where it arrives: was a strike + geyser + spikes each)
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if e in seized:
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
	Game.shake(0.7)


# --- Three-element strings (round 34, second pass) ---------------------------------------------------------------
# Each hands over twice, and each hand-over pays only for what the element before it left: Hailstorm lifts only the
# frozen, Meltdown hits hardest those the gale has up, Eruption those Meltdown set alight; Impale pays more onto a
# spear already standing, Backdraft for the skewered (still frozen), Anvil for what the gale brought up.
# Improvising (the dash routes): a crossover's state outlasts the string by ELEMENT_HOLD (mark(), FREEZE_TIME),
# and every payoff reads the state, not the route, so a dash and any move of the paying element cash it in:
# frozen into magma (Molten Palm steams them, fire() "EM"), buried into storm (Updraft Lash, Storm Pitch:
# _cash_buried), airborne into dark (Tow Line rips them out of the air, fire() "TW").

## A crossover's state on a foe ("buried", "molten", "skewered"), good for ELEMENT_HOLD s of real time.
static func mark(e: Variant, state: String) -> void:
	if is_instance_valid(e):
		var hold := CHARGED_HOLD if state == "charged" else ELEMENT_HOLD  # (round 44 b: the charge outlasts a magma string's three swings)
		e.set_meta("x_" + state, Time.get_ticks_msec() + int(hold * 1000.0 / Game.slow))  # (real ms: longer in training's slow motion)
		ENV_PIECE.marked(e, state)  # (round 51: magma by a barrel, storm on a grate)


static func marked(e: Variant, state: String) -> bool:
	return is_instance_valid(e) and int(e.get_meta("x_" + state, 0)) > Time.get_ticks_msec()


static func unmark(e: Variant, state: String) -> void:
	if is_instance_valid(e) and e.has_meta("x_" + state):
		e.remove_meta("x_" + state)


static func is_frozen(e: Node) -> bool:
	return in_cube(e) or float(e.get("frozen_t") if e.get("frozen_t") != null else 0.0) > 0.0


## Anyone frozen (and not flying) in the strip ahead of him: Molten Palm goes off as a Steam Burst on them.
static func _frozen_ahead(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float) -> bool:
	for e: Node3D in _ahead(hero, at, fwd, length, PALM_HALF_WIDTH):
		if is_frozen(e) and not THROWN.flying(e):
			return true
	return false


## Buried into storm, by any route: whoever Rockslide drove into the floor in the last ELEMENT_HOLD s takes the
## storm move's damage again on top (FAULT_BURIED_MULT in all), thrown up at `launch`. The state's spent.
static func _cash_buried(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, launch: float) -> void:
	for e: Node3D in FOES.near(hero.get_tree(), at, radius):
		if marked(e, "buried") and not THROWN.flying(e):
			unmark(e, "buried")
			e.take_hit(damage * (FAULT_BURIED_MULT - 1.0), Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else launch, true)
			Game.register_hit("cast")


## Ice that stays on a foe in the air: enemy.freeze() staggers, which drops it out of the air, so the ice is set by
## hand (ELEMENT_HOLD, FREEZE_BREAK on the next hit) and the cube put on. Bosses never freeze.
static func freeze_aloft(e: Variant) -> void:
	if not is_instance_valid(e) or not e.is_alive() or e.has_method("is_boss"):
		return
	if e.get("frozen_t") != null:
		e.frozen_t = maxf(float(e.frozen_t), ELEMENT_HOLD)
		e.frozen_mult = FREEZE_BREAK
	var gone: Node = e.get_node_or_null(THROWN.CUBE_NAME)
	if gone != null and gone.is_queued_for_deletion():
		gone.name = "ThrownCubeGone"  # (the hit that just broke it freed it: cube_on() would see it and add none)
	THROWN.cube_on(e)


## Dash L H H H: ice into storm. A whirlwind comes up under every frozen foe near him (the one Ice Cube is bowling
## too) and carries it high, still in its ice (freeze_aloft: the gale breaks it for FREEZE_BREAK and it sets again), and he climbs after them (MOVES
## `air`, `climb`). Those not frozen only stagger up.
static func _hailstorm(hero: CharacterBody3D, at: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var foes: Array = FOES.near(hero.get_tree(), at, HAIL_REACH).filter(func(e: Node3D) -> bool: return is_frozen(e) or not THROWN.flying(e))
	var n := 0
	for e: Node3D in foes:
		var heavy: bool = hero._void.is_heavy(e)
		if is_frozen(e):
			THROWN.cut(e)  # (Ice Cube's bowl too: the gale takes the cube out of its roll)
			COMIC_HAIL.ride(parent, e)  # (a tight whirlwind riding it up: was a full wind pillar each)
			e.take_hit(HAIL_DAMAGE * power, Vector3.ZERO, 0.0 if heavy else HAIL_LAUNCH, true)  # (frozen: x FREEZE_BREAK)
			Game.register_hit("cast")
			freeze_aloft(e)
			n += 1
		elif _flat(e.global_position - at).length() <= HAIL_WARM_REACH:
			e.take_hit(HAIL_DAMAGE * power * 0.5, Vector3.ZERO, 0.0 if heavy else HAIL_WARM_LAUNCH, false)
			Game.register_hit("cast")
			n += 1
	if n == 0:
		ELEMENTS.pillar(parent, at + hero._facing() * 2.0, "wind", 2.4, 0.9)
	return n


## Dash L H H H L, in the air: storm into magma. The molten hammer comes round through everyone up there with him and
## the frozen: the ice bursts off them (x FREEZE_BREAK), those the gale had up take MELT_AIR_MULT, and all come down
## burning into the floor (craters), `molten` for Eruption. The window opens (Eruption).
static func _meltdown(hero: CharacterBody3D, at: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var foes: Array = FOES.near(hero.get_tree(), at, MELT_REACH).filter(func(e: Node3D) -> bool:
		return not THROWN.flying(e) and (e.is_airborne() or is_frozen(e)))
	COMIC_MELT.swing(parent, at + Vector3.UP * (hero.model.position.y + 0.9), hero._facing())  # (the hammer's arc)
	if foes.is_empty():
		return 0
	for e: Node3D in foes:
		var up: bool = e.is_airborne()
		COMIC_MELT.foe(parent, e, is_frozen(e))  # (ice off it, burning down, a hot splat where it lands)
		if is_frozen(e):
			THROWN.remove_cube(e)
		e.take_hit(MELT_DAMAGE * power * (MELT_AIR_MULT if up else 1.0), Vector3.DOWN * MELT_DOWN, 0.0, true)
		Game.register_hit("cast")
		mark(e, "molten")
	Game.shake(0.5)
	return foes.size()


## Dash H H: dark into ice. The tentacles throw whoever Tow Line bunched onto the frost spear, and they freeze stuck
## round it (`skewered`, for Backdraft). Onto a spear that was already standing (L L H first) it's IMPALE_SPEAR_MULT;
## with none, the tentacle drives one in where Tow Line bunched them. Big ones freeze where they stand.
static func _impale(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var s: Node3D = SPEAR.current(hero.get_tree())
	var planted := s != null
	if not planted:
		s = SPEAR.plant(parent, at + fwd * minf(TOW_AHEAD, hero._clear_ahead(fwd, TOW_AHEAD)))
	var spot: Vector3 = _flat(s.global_position) if is_instance_valid(s) else at + fwd * TOW_AHEAD
	COMIC_IMPALE.burst(parent, spot, IMPALE_RING + 1.4)  # (ice racing out of its foot: was frost_ring's torus)
	_pop(parent, spot, "spear")
	var foes: Array = FOES.near(hero.get_tree(), at, IMPALE_GRAB)
	var small: int = foes.filter(func(e: Node3D) -> bool: return not hero._void.is_heavy(e)).size()
	var damage: float = IMPALE_DAMAGE * power * (IMPALE_SPEAR_MULT if planted else 1.0)
	var slot := 0
	for e: Node3D in foes:
		THROWN.cut(e)  # (still on Tow Line's tether: the tentacle takes it from there)
		e.take_hit(damage, Vector3.ZERO, 0.0, true)
		Game.register_hit("cast")
		encase(e)
		mark(e, "skewered")
		if hero._void.is_heavy(e):
			COMIC_IMPALE.stake(parent, spot, e, null)
			continue
		var a := TAU * slot / maxf(small, 1.0)
		var to := spot + Vector3(sin(a), 0.0, cos(a)) * (IMPALE_RING if small > 1 else 0.6)
		var flight: Node = THROWN.launch(hero, e, to, 0.0, {"quiet": true, "solid": false, "tether": true, "el": "water", "speed": IMPALE_SPEED, "land_y": 0.0})
		COMIC_IMPALE.stake(parent, spot, e, flight)  # (the stake through it once it lands on the spear)
		slot += 1
	return foes.size()


## Dash H H L: ice into storm. The axe's gale blows the spear apart and hauls everyone round it back to him and up,
## the ice going as they come (the skewered are still frozen: x FREEZE_BREAK; anyone else takes less). The window
## opens (Anvil).
static func _backdraft(hero: CharacterBody3D, at: Vector3, fwd: Vector3, power: float) -> int:
	var parent: Node = hero.get_parent()
	var s: Node3D = SPEAR.current(hero.get_tree())
	var spot: Vector3 = _flat(s.global_position) if s != null else at + fwd * TOW_AHEAD
	if s != null:
		s.shatter()
	COMIC_BACKDRAFT.blast(parent, spot)  # (was a 2.6 m wind pillar)
	var foes: Array = FOES.near(hero.get_tree(), spot, BACKDRAFT_REACH).filter(func(e: Node3D) -> bool: return not THROWN.flying(e))
	var hand := at + Vector3.UP * 1.3 + fwd * 0.6
	for e: Node3D in foes:
		var back := _flat(at - e.global_position)
		var skewered := marked(e, "skewered")
		unmark(e, "skewered")
		var kb: Vector3 = back.normalized() * BACKDRAFT_PULL if back.length() > 0.6 else Vector3.ZERO
		e.take_hit(BACKDRAFT_DAMAGE * power * (1.0 if skewered else 0.6), kb, 0.0 if hero._void.is_heavy(e) else BACKDRAFT_LAUNCH, true)
		Game.register_hit("cast")
		COMIC_BACKDRAFT.haul(parent, e, hand, skewered)  # (a wind ribbon to his hand: was a lightning arc each)
	return foes.size()


## Eruption lands (round 52 cool pass, eruption_hurl.gd): a lava fuse races out to everyone near, a geyser heaves each
## up, and hurls it into the wall or pillar the indicator marks to slide down it burning; in the open the column gives
## and they drop back into the floor. Meltdown's `molten` take every beat hardest (ERUPT_MOLTEN_MULT).
static func _eruption(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var foes: Array = []
	for e: Variant in seized + FOES.near(hero.get_tree(), at, ERUPT_RING):
		if not foes.has(e) and is_instance_valid(e) and e.is_alive() and not THROWN.flying(e):
			foes.append(e)
	var hot := {}
	for e: Node3D in foes:
		hot[e] = ERUPT_MOLTEN_MULT if marked(e, "molten") else ERUPT_COLD_MULT
		unmark(e, "molten")
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + ERUPT_CUE_MS)
	var wall := pinwheel_target(hero, at, "eruption", ERUPT_REACH)  # (the indicator's pick; a raycast in a bare room)
	var g: Node3D = ERUPTION_HURL.start(hero, at, foes, wall.get("found", false), hero._void.is_heavy)
	g.on_heave = func(e: Node3D, _i: int) -> void:
		e.take_hit(damage * ERUPT_HEAVE_MULT * float(hot.get(e, 1.0)), Vector3.ZERO, 0.0 if hero._void.is_heavy(e) else ERUPT_LAUNCH, true)
		Game.register_hit("breaker")
		Game.sfx("hit_big", -4.0, 0.1)
	g.on_hurl = _eruption_hurl.bind(hero, wall, damage, hot, g)
	g.on_drop = func(e: Node3D, _i: int) -> void:
		e.take_hit(damage * ERUPT_DROP_MULT * float(hot.get(e, 1.0)), Vector3.DOWN * MELT_DOWN, 0.0, true)
		Game.register_hit("breaker")
		under(parent, _flat(e.global_position), "earth")
	g.on_slide = func(e: Node3D, _i: int) -> void:
		e.take_hit(damage * ERUPT_SLIDE_MULT * float(hot.get(e, 1.0)), Vector3.ZERO, 0.0, true)
		mark(e, "molten")  # (it slid down burning: still alight)
		Game.register_hit("breaker")
		if DESIGNED.on():
			DESIGNED_EL.pool(parent, e.global_position, 0.9)
	if not DESIGNED.on():
		COMIC_ERUPT.spawn(parent, at, foes.map(func(e: Node3D) -> Vector3: return _flat(e.global_position)), foes.map(func(e: Node3D) -> bool: return hot[e] > 1.0))
	_pop(parent, at, "hammer")
	Game.shake(0.7)


## One of Eruption's hurls (eruption_hurl.on_hurl): the geyser throws `e` from the top of its column at the structure;
## the splat sticks it up the wall (eruption_hurl.slide) to slide down burning.
static func _eruption_hurl(e: Node3D, _i: int, hero: Variant, wall: Dictionary, damage: float, hot: Dictionary, g: Variant) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var face: Vector3 = ENV.surface(wall.s, e.global_position).at if wall.has("s") else wall.at
	var aim: Vector3 = face - _flat(e.global_position)
	var parent: Node = hero.get_parent()
	THROWN.launch(hero, e, _flat(e.global_position) + aim.normalized() * (aim.length() + 1.5), damage * ERUPT_HURL_MULT * float(hot.get(e, 1.0)),
		{"solid": false, "el": "earth", "speed": ERUPT_WALL_SPEED, "land_y": ERUPTION_HURL.SPLAT_Y, "wall_mult": ERUPT_WALL_MULT,
		"splash": false, "on_burst": _eruption_splat.bind(parent, g)})


## An Eruption hurl stops (thrown_foe's on_burst): on the structure it splats and slides down it; short of one it lands.
static func _eruption_splat(f: Node3D, walled: bool, dir: Vector3, parent: Node, g: Variant) -> void:
	if walled and is_instance_valid(parent):
		ALT_FX.cool_wall(parent, f.global_position, dir, "earth", ERUPT_WALL_WORD)
	if is_instance_valid(g) and walled:
		g.slide(f, -dir)


## Flash Freeze's dive (hero_leap._start_dive, round 52): the steam rolls out from where he will land over everyone
## within FF_CLOUD_R, setting into a shell on each, nearest first (frost_shell.gd). Returns the node (the landing breaks it).
static func flash_freeze_dive(hero: CharacterBody3D) -> Node3D:
	var zone: Vector3 = _flat(hero._brk_zone)
	var foes: Array = []
	for e: Variant in hero._void.held_foes() + FOES.near(hero.get_tree(), zone, FF_CLOUD_R):
		if not foes.has(e) and is_instance_valid(e) and e.is_alive():
			foes.append(e)
	var damage: float = BREAKERS.XS.damage * hero._dmg_mult
	var g: Node3D = FROST_SHELL.start(hero, zone, foes)
	g.on_set = func(e: Node3D, _i: int) -> void:
		e.take_hit(damage * FF_SET_MULT, Vector3.ZERO, 0.0, false)
		Game.register_hit("breaker")
		encase(e)
	hero.set_meta(FF_META, g)
	return g


## Flash Freeze lands (round 52): the shells the steam set break one after another from the picked one (env_target
## "flash_freeze": the cursor's foe, or the one nearest the landing), a beat harder each link (FF_LINK_PER).
static func _flash_freeze(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var g: Variant = hero.get_meta(FF_META) if hero.has_meta(FF_META) else null
	hero.remove_meta(FF_META)
	if not is_instance_valid(g):
		g = flash_freeze_dive(hero)
		hero.remove_meta(FF_META)
	g.on_link = func(e: Node3D, k: int) -> void:
		e.take_hit(damage * (1.0 + FF_LINK_PER * k), Vector3.DOWN * FF_DOWN, 0.0, true)  # (frozen: x FREEZE_BREAK)
		THROWN.remove_cube(e)
		Game.register_hit("breaker")
		Game.hitstop(0.03)
		Game.sfx("hit_big", -3.0, 0.1)
		if DESIGNED.on() and is_instance_valid(parent):
			DESIGNED.ice_shatter(parent, e.global_position + Vector3.UP * 0.9, 1.1 + 0.1 * k)
	for e: Node3D in g.shelled():
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + 900)
	g.shatter(ENV.picked_foe(hero, "flash_freeze"))
	_pop(parent, at, "spear")
	Game.shake(0.6)


## Anvil lands: the hammer drives what the gale brought back (everyone held) into the floor, a crater each, at
## ANVIL_AIR_MULT; anyone else near who's still up comes down with them, the rest are thrown clear.
static func _anvil(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var craters := []
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		e.take_hit(damage * ANVIL_AIR_MULT, Vector3.DOWN * ANVIL_DOWN, 0.0, true)
		Game.register_hit("breaker")
		craters.append(_flat(e.global_position))
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if e in seized:
			continue
		if e.is_airborne():
			e.take_hit(damage * ANVIL_AIR_MULT, Vector3.DOWN * ANVIL_DOWN, 0.0, true)
			craters.append(_flat(e.global_position))
		else:
			var from := _flat(e.global_position - at)
			e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
	COMIC_ANVIL.spawn(parent, at, craters)  # (a crater each, nearest first: was three earth spikes each)
	_pop(parent, at, "hammer")
	Game.shake(0.7)


# --- Meteor Fall's dive (round 42) -----------------------------------------------------------------------

## Where Meteor Fall lands, pure so the check can walk it: of `spots` (flat foe positions) within `reach` of `at`
## (`splat_reach` for a fresh one: he follows the palm's carry to the wall),
## each foe's group is everyone within `radius` of it, worth one a foe (METEOR_WALL_WEIGHT for those `fresh`: off a
## wall splat just now). The best group wins, the nearer on a tie; it lands on the group's middle. Returns
## {"found": false} with nobody in reach (he lands ahead of him, hero_leap.start's zone).
static func meteor_target(at: Vector3, spots: Array, fresh: Array, reach := METEOR_REACH, radius := METEOR_PILE_R,
		splat_reach := METEOR_SPLAT_REACH) -> Dictionary:
	var best := {"found": false}
	var best_score := -1.0
	var best_d := INF
	for i in spots.size():
		var me: Vector3 = _flat(spots[i])
		var r: float = splat_reach if fresh[i] else reach  # (he goes as far as the palm carried them to the wall)
		if _flat(me - at).length() > r:
			continue
		var score := 0.0
		var mid := Vector3.ZERO
		var n := 0
		for j in spots.size():
			var other: Vector3 = _flat(spots[j])
			if other.distance_to(me) <= radius and _flat(other - at).length() <= r + radius:
				score += METEOR_WALL_WEIGHT if fresh[j] else 1.0
				mid += other
				n += 1
		mid /= float(n)
		var d := _flat(mid - at).length()
		if score > best_score + 0.001 or (absf(score - best_score) <= 0.001 and d < best_d):
			best_score = score
			best_d = d
			best = {"found": true, "at": mid, "score": score, "count": n}
	return best


## Was `e` splatted on a wall (thrown_foe `last_wall_ms`) within METEOR_SPLAT_FRESH_MS?
static func wall_fresh(e: Object) -> bool:
	if not is_instance_valid(e) or not e.has_meta(THROWN.WALL_META):  # (get_meta's null default still errors)
		return false
	return Time.get_ticks_msec() - int(e.get_meta(THROWN.WALL_META)) <= METEOR_SPLAT_FRESH_MS / Game.slow


## Did Molten Palm hit `e` within METEOR_PALM_FRESH_MS?
static func palm_fresh(e: Object) -> bool:
	if not is_instance_valid(e) or not e.has_meta(PALM_META):
		return false
	return Time.get_ticks_msec() - int(e.get_meta(PALM_META)) <= METEOR_PALM_FRESH_MS / Game.slow


## meteor_target over the living foes round the hero that this string's Molten Palm hit (the ones it pressed into a
## wall among them, and worth more). Nobody else draws the dive; with none, he lands ahead of him.
static func meteor_spot(hero: CharacterBody3D, use_pick := true) -> Dictionary:
	var at := _flat(hero.global_position)
	var foes: Array = meteor_candidates(hero)
	var picked := ENV.chosen(hero, "meteor") if use_pick else {}  # (round 50: the cursor on a wall or pillar: the pile by it)
	if not picked.is_empty():
		var by: Array = foes.filter(func(e: Node3D) -> bool: return ENV.gap(picked, e.global_position) <= ENV.METEOR_NEAR)
		if not by.is_empty():
			foes = by
	var pf: Node3D = ENV.picked_foe(hero, "meteor") if use_pick else null  # (round 52: the cursor on a foe: the pile it is in)
	if pf != null and foes.has(pf):
		foes = foes.filter(func(e: Node3D) -> bool: return _flat(e.global_position).distance_to(_flat(pf.global_position)) <= METEOR_PILE_R)
	return meteor_target(at, foes.map(func(e: Node3D) -> Vector3: return e.global_position), foes.map(func(e: Node3D) -> bool: return wall_fresh(e)))


## Who Meteor Fall may dive on: the living foes this string's Molten Palm hit, within METEOR_SPLAT_REACH of him.
static func meteor_candidates(hero: CharacterBody3D) -> Array:
	return FOES.near(hero.get_tree(), _flat(hero.global_position), METEOR_SPLAT_REACH).filter(func(e: Node3D) -> bool: return palm_fresh(e))


## How many piles `foes` stand in (each foe within METEOR_PILE_R of a pile's first one is in it): two or more and the
## window's bracket goes on a foe, the pile to dive on (round 52 cool pass), not on the wall.
static func meteor_piles(foes: Array) -> int:
	var seeds: Array = []
	for e: Node3D in foes:
		var p := _flat(e.global_position)
		if not seeds.any(func(s: Vector3) -> bool: return s.distance_to(p) <= METEOR_PILE_R):
			seeds.append(p)
	return seeds.size()


## The meteor lands: everyone within METEOR_PILE_R takes it, a crater under every one of them, more on the big ones
## and on those still fresh off a wall splat (METEOR_SPLAT_MULT). Undertow lets go; shields come off for good.
static func _meteor_landing(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	if is_instance_valid(hero._void.undertow):
		hero._void.undertow._let_go()  # (up out of the lava for the crater)
	for e: Node3D in FOES.near(hero.get_tree(), at, METEOR_PILE_R):
		var spot := _flat(e.global_position)
		THROWN.cut(e)
		var body: Variant = e.get("model")
		if body != null:
			body.position.y = 0.0
		if e.has_method("rip_shield"):
			e.rip_shield()
		var k: float = (METEOR_HEAVY_MULT if hero._void.is_heavy(e) else 1.0) * (METEOR_SPLAT_MULT if wall_fresh(e) else 1.0)
		e.take_hit(damage * k, Vector3.DOWN * METEOR_DOWN, 0.0, true)
		Game.register_hit("breaker")
		if not DESIGNED.on():
			Fx.shards(parent, spot + Vector3.UP * 0.9, ELEMENTS.LOOK.earth.color, 6, Vector3.UP, 10.0, 0.2, 0.7)
			ELEMENTS.spikes(parent, spot, "earth", CRYSTAL_SIZE, 2, 1.0)
	_pop(parent, at, "hammer")
	if DESIGNED.on():  # round 43: the drawn crown burst, lava wave, rim splashes and crust (designed_fx.meteor)
		DESIGNED.meteor(parent, at, METEOR_PILE_R)
		Game.shake(0.8)
		return
	for i in METEOR_GEYSERS:
		var a := TAU * (i + 0.5) / METEOR_GEYSERS  # (one behind the pile, none in front of it)
		ELEMENTS.rim_geyser(parent, at + Vector3(sin(a), 0.0, cos(a)) * METEOR_GEYSER_OUT, GEYSER_RADIUS, GEYSER_HIGH, false)
	Fx.scorch(parent, at, ELEMENTS.LOOK.earth.color, METEOR_GEYSER_OUT * 1.6, 1.6)
	Game.shake(0.8)


# --- Breakers -----------------------------------------------------------------

## The breaker has landed. `seized`: who the tentacles have. Each gets the slam and the element under
## it, then anyone else near the landing takes the element too. Cold Front throws them instead.
static func breaker_impact(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	ENV_PIECE.landing(hero, at)  # (round 51: crates near it break, rubble under it throws chunks)
	if b.has("counter"):  # Ricochet, the dash counter's ending (load: counter.gd preloads this file)
		load("res://scripts/counter.gd").ricochet(hero, b, at, seized, mult)
		return
	if b.has("shower"):
		_meteor_shower(hero, b, at, mult)
		return
	if b.has("hellseam"):
		_hellseam(hero, b, at, mult)
		return
	if b.has("pinwheel"):
		_pinwheel(hero, b, at, seized, mult)
		return
	if b.has("tempest"):
		_tempest(hero, b, at, seized, mult)
		return
	if b.has("slapshot"):
		_slapshot(hero, b, at, seized, mult)
		return
	if b.has("thunder"):
		_shatterstorm(hero, b, at, seized, mult)
		return
	if b.has("cubes"):
		_cold_front(hero, b, at, seized, mult)
		return
	if b.has("refreeze"):  # Flash Freeze (round 52): the shells the dive set break in a chain
		_flash_freeze(hero, b, at, mult)
		return
	if b.has("press"):
		_avalanche(hero, b, seized, mult)
		return
	if b.has("meteor"):
		_meteor_landing(hero, b, at, mult)
		return
	if b.has("cataclysm"):
		_cataclysm(hero, b, at, seized, mult)
		return
	if b.has("short_circuit"):
		_short_circuit(hero, b, at, seized, mult)
		return
	if b.has("black_ice"):
		_black_ice(hero, b, mult)
		return
	if b.has("eruption"):
		_eruption(hero, b, at, seized, mult)
		return
	if b.has("anvil"):
		_anvil(hero, b, at, seized, mult)
		return
	if b.has("collapse"):
		_collapse(hero, b, at, mult)
		return
	if b.has("maw"):
		_maw(hero, b, mult)
		return
	if b.has("uproot"):
		_uproot(hero, b, mult)
		return
	if b.has("abyss"):
		_abyss(hero, b, mult)
		return
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var struck := {}
	for e: Node3D in seized:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		struck[e] = true
		var spot := _flat(e.global_position)
		e.take_hit(damage, Vector3.ZERO, BREAK_LAUNCH, true)
		if b.erupt == "wind":
			mark(e, "charged")  # (Grounded: the storm it lands in stays in them)
		Game.register_hit("breaker")
		under(parent, spot, b.erupt)
	for e: Node3D in FOES.near(hero.get_tree(), at, BREAK_AREA):
		if struck.has(e):
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * 0.6, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 5.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
	under(parent, at, b.erupt)
	_pop(parent, at, {"wind": "axe", "water": "spear", "earth": "hammer"}[b.erupt])


## The foes Meteor Shower calls a fireball down on: every living one Molten Palm hit (palm_fresh) within
## METEOR_SPLAT_REACH of him, nearest first, at most SHOWER_MAX.
static func shower_targets(hero: CharacterBody3D) -> Array:
	var at := _flat(hero.global_position)
	var foes: Array = FOES.near(hero.get_tree(), at, METEOR_SPLAT_REACH).filter(func(e: Node3D) -> bool: return palm_fresh(e))
	foes.sort_custom(func(a: Node3D, c: Node3D) -> bool: return _flat(a.global_position - at).length() < _flat(c.global_position - at).length())
	return foes.slice(0, SHOWER_MAX)


## Meteor Shower (Meteor Fall's LMB ending) has landed: a fireball out of the sky onto each target in turn (ALT_FX.meteor_drop),
## each a crater on its foe alone; the last lets Undertow go. Nobody the palm hit: one onto the floor ahead of him.
static func _meteor_shower(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var foes := shower_targets(hero)
	for e: Node3D in foes:
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + SHOWER_CUE_MS)
	if foes.is_empty():
		var tw0 := parent.create_tween().set_ignore_time_scale(true)
		tw0.tween_interval(SHOWER_DELAY)
		tw0.tween_callback(func() -> void:
			if is_instance_valid(parent) and DESIGNED.on():
				DESIGNED.meteor(parent, at + hero._brk_dir * 3.0, ALT_FX.DROP_SPLASH))
		if is_instance_valid(hero._void.undertow):
			hero._void.undertow._let_go()
		return
	for i in foes.size():
		var tw := parent.create_tween().set_ignore_time_scale(true)  # (real time: the landing's freeze would hold them a second)
		tw.tween_interval(SHOWER_DELAY + i * SHOWER_STEP)
		tw.tween_callback(_shower_call.bind(hero, foes[i], damage, i == foes.size() - 1))


static func _shower_call(hero: Variant, e: Variant, damage: float, last: bool) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var from: Vector3 = (hero as Node3D).global_position
	ALT_FX.meteor_drop(hero.get_parent(), from, e, SHOWER_FALL, _shower_land.bind(hero, e, damage, last))


static func _shower_land(_at: Vector3, hero: Variant, e: Variant, damage: float, last: bool) -> void:
	if not is_instance_valid(hero):
		return
	if last and is_instance_valid(hero._void.undertow):
		hero._void.undertow._let_go()  # (up out of the lava for the last crater)
	if not is_instance_valid(e) or not e.is_alive():
		return
	THROWN.cut(e)
	var body: Variant = e.get("model")
	if body != null:
		body.position.y = 0.0
	e.take_hit(damage, Vector3.DOWN * METEOR_DOWN, 0.0, true)
	mark(e, "molten")  # (it burns on: the matrix's molten row)
	Game.register_hit("breaker")
	Game.hitstop(ALT_FX.DROP_STOP * (1.6 if last else 1.0))
	Game.shake(0.55 if last else 0.35)
	Game.sfx("hit_big", -2.0, 0.12)


## Where Pinwheel throws: the nearest wall or pillar within PINWHEEL_REACH of `at` (PINWHEEL_RAYS flat rays at chest
## height, past the foes), as {"found", "at" (the hit point), "dir", "dist"}.
static func pinwheel_target(hero: CharacterBody3D, at: Vector3, ctx := "pinwheel", reach := PINWHEEL_REACH) -> Dictionary:
	var env := ENV.pick(hero, ctx, at, reach)  # (round 50: the room's structures, the one the indicator marks)
	if not env.has("none"):
		return env
	var start := Vector3(at.x, 0.9, at.z)
	var space := hero.get_world_3d().direct_space_state
	var skip: Array[RID] = [hero.get_rid()]
	for o: Node in hero.get_tree().get_nodes_in_group("enemies"):
		if o is CollisionObject3D:
			skip.append((o as CollisionObject3D).get_rid())
	var best := {"found": false, "dist": INF}
	for i in PINWHEEL_RAYS:
		var a := TAU * i / PINWHEEL_RAYS
		var d := Vector3(sin(a), 0.0, cos(a))
		var q := PhysicsRayQueryParameters3D.create(start, start + d * reach, hero.collision_mask)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var dist: float = start.distance_to(hit.position)
		if dist < best.dist:
			best = {"found": true, "at": _flat(hit.position), "dir": d, "dist": dist}
	return best


## Pinwheel (Anvil's LMB ending) lands: the whirl (void_grab.seized_tick, `pinwheel`) lets go, and each held foe is
## hurled at the nearest wall or pillar in reach, wall-splatting there (x PINWHEEL_WALL_MULT); with none it flies out
## along its swing and lands. Anyone else the whirl passed takes PINWHEEL_SWEEP and is blown clear.
static func _pinwheel(hero: CharacterBody3D, b: Dictionary, at: Vector3, held: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var target := pinwheel_target(hero, at)
	var live: Array = held.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	for e: Node3D in FOES.near(hero.get_tree(), at, PINWHEEL_R + 1.2):
		if e in live:
			continue
		var from := _flat(e.global_position - at)
		e.take_hit(damage * PINWHEEL_SWEEP, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 6.0, BREAK_LAUNCH, true)
		Game.register_hit("breaker")
	_pop(parent, at, "axe")
	Game.shake(0.5)
	for i in live.size():
		var e: Node3D = live[i]
		THROWN.remove_cube(e)
		var out := _flat(e.global_position - at)
		out = out.normalized() if out.length() > 0.05 else hero._facing()
		var to: Vector3 = _flat(e.global_position) + out * PINWHEEL_OPEN
		if target.found:
			var aim: Vector3 = target.at - _flat(e.global_position)
			to = _flat(e.global_position) + aim.normalized() * (aim.length() + 1.5)
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + PINWHEEL_CUE_MS)
		THROWN.launch(hero, e, to, damage, {"solid": false, "el": "wind", "speed": PINWHEEL_SPEED, "land_y": 0.0,
			"wall_mult": PINWHEEL_WALL_MULT, "splash": false, "on_burst": _pinwheel_hit.bind(parent)})
		Game.register_hit("breaker")


static func _pinwheel_hit(f: Node3D, walled: bool, dir: Vector3, parent: Node) -> void:
	if walled and is_instance_valid(parent):
		ALT_FX.pinwheel_wall(parent, f.global_position, dir)


## Who Tempest's column takes from round `mid`: everyone not big within TEMPEST_REACH, not in flight, nearest first,
## TEMPEST_MAX at most; and the big ones it leaves standing. {"ride": [...], "big": [...]}
static func tempest_riders(hero: CharacterBody3D, mid: Vector3) -> Dictionary:
	var ride := []
	var big := []
	for e: Node3D in FOES.near(hero.get_tree(), mid, TEMPEST_REACH):
		if THROWN.flying(e):
			continue
		(big if hero._void.is_heavy(e) else ride).append(e)
	ride.sort_custom(func(a: Node3D, c: Node3D) -> bool: return _flat(a.global_position - mid).length() < _flat(c.global_position - mid).length())
	return {"ride": ride.slice(0, TEMPEST_MAX), "big": big}


## Tempest (Cataclysm's LMB ending) lands: the twister goes up on the pile (ALT_FX.twister) and takes the riders up it
## (a game-time tween drives each, `thrown_foe`'s FLYING meta keeping everything else off them); then a bolt blasts
## each out in turn (_tempest_bolt), each harder for every other one in the column.
static func _tempest(hero: CharacterBody3D, b: Dictionary, at: Vector3, held: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var mid: Vector3 = at + hero._brk_dir * 1.2
	var live: Array = held.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	if not live.is_empty():
		mid = Vector3.ZERO
		for e: Node3D in live:
			mid += _flat(e.global_position)
		mid /= float(live.size())
		mid += hero._brk_dir * TEMPEST_OUT  # (off him: the column stood on him and a rider hid him)
	var who := tempest_riders(hero, mid)
	var riders: Array = who.ride
	var each: float = b.damage * hero._dmg_mult * mult * (1.0 + TEMPEST_PER * maxi(riders.size() - 1, 0))
	var life: float = TEMPEST_FIRST + TEMPEST_STEP * riders.size() + 0.25
	ALT_FX.twister(parent, mid, TEMPEST_COLUMN, TEMPEST_R + 0.5, life + TEMPEST_FREEZE)
	_pop(parent, mid, "axe")
	Game.shake(0.6)
	for e: Node3D in who.big:
		e.take_hit(each * TEMPEST_BIG, Vector3.ZERO, 0.0, true)
		Game.register_hit("breaker")
	for i in riders.size():
		var e: Node3D = riders[i]
		THROWN.cut(e)
		e.set_meta(THROWN.FLYING, true)
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + TEMPEST_CUE_MS)
		if e.has_method("stagger"):
			e.stagger(life + 0.3)
		var off := _flat(e.global_position - mid)
		var a0 := atan2(off.x, off.z)
		var r0 := off.length()
		var y0: float = e.global_position.y
		var high: float = TEMPEST_HIGH + TEMPEST_HIGH_STEP * (i % 3)
		var strike: float = TEMPEST_FIRST + TEMPEST_STEP * i
		var tw := parent.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # (game time: the ride plays after the landing's freeze)
		tw.tween_method(_tempest_ride.bind(e, mid, a0, r0, y0, high, strike), 0.0, strike, strike)
		tw.tween_callback(_tempest_bolt.bind(hero, e, mid, each, i == 0))


## One frame of a rider going up the column (`t` s of `strike`): spiralling in to TEMPEST_R and up to `high`.
static func _tempest_ride(t: float, e: Variant, mid: Vector3, a0: float, r0: float, y0: float, high: float, strike: float) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	var k := clampf(t / maxf(minf(strike, 0.5), 0.01), 0.0, 1.0)
	var ease_k := 1.0 - (1.0 - k) * (1.0 - k)
	var a := a0 + TEMPEST_SPIN * t
	var r := lerpf(r0, TEMPEST_R, ease_k)
	var node: Node3D = e
	node.global_position = Vector3(mid.x + sin(a) * r, lerpf(y0, high, ease_k) + sin(t * 7.0) * 0.08, mid.z + cos(a) * r)
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO


## A bolt out of the sky into a rider, blasting it out of the column: the hit, charged, thrown clear.
static func _tempest_bolt(hero: Variant, e: Variant, mid: Vector3, damage: float, first: bool) -> void:
	if not is_instance_valid(e):
		return
	if e.has_meta(THROWN.FLYING):
		e.remove_meta(THROWN.FLYING)
	if not is_instance_valid(hero) or not e.is_alive():
		return
	var parent: Node = hero.get_parent()
	var at: Vector3 = (e as Node3D).global_position + Vector3.UP * 0.9
	COMIC_BOLT.spawn(parent, at + Vector3(0.6, 9.0, -0.4), at, 0.3, 0.9 if first else 0.6, 2)
	var out := _flat((e as Node3D).global_position - mid)
	out = out.normalized() if out.length() > 0.05 else Vector3.FORWARD
	e.take_hit(damage, out * TEMPEST_THROW, TEMPEST_LAUNCH, true)
	mark(e, "charged")
	Game.register_hit("breaker")
	Game.hitstop(0.05 if first else 0.03)
	Game.shake(0.45 if first else 0.3)
	Game.sfx("hit_big", -3.0, 0.15)


## Shatterstorm (Harpoon's RMB ending): thunder crashes on each cube of the row in turn, where it stands, and shatters
## it: SHATTER_DAMAGE each (x FREEZE_BREAK on the ice), and the storm stays in them (charged). The first waits out the
## landing's impact frame (SHATTER_DELAY), which hid Short Circuit's arcs.
static func _shatterstorm(hero: CharacterBody3D, b: Dictionary, at: Vector3, held: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var row: Array = held.duplicate()
	var mid := Vector3.ZERO
	for e: Node3D in row:
		mid += _flat(e.global_position)
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + SC_CUE_MS)
	if row.is_empty():
		ELEMENTS.storm_strike(parent, at + hero._facing() * 2.0, "wind")
		return
	mid /= float(row.size())
	row.sort_custom(func(a: Node3D, c: Node3D) -> bool:  # (from the middle out: the crash spreads)
		return _flat(a.global_position).distance_to(mid) < _flat(c.global_position).distance_to(mid))
	for i in row.size():
		var tw := parent.create_tween()
		tw.tween_interval(SHATTER_DELAY + i * SHATTER_STEP)
		tw.tween_callback(_thunder_on.bind(hero, row[i], damage, i == 0))


static func _thunder_on(hero: Variant, e: Variant, damage: float, first: bool) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var parent: Node = hero.get_parent()
	var spot := _flat((e as Node3D).global_position)
	ELEMENTS.storm_strike(parent, spot, "wind")
	if DESIGNED.on():
		DESIGNED.ice_shatter(parent, spot + Vector3.UP * 0.9, 1.2)
	THROWN.remove_cube(e)
	e.take_hit(damage, Vector3.ZERO, BREAK_LAUNCH * 0.6, true)
	mark(e, "charged")
	Game.register_hit("breaker")
	Game.hitstop(0.05 if first else 0.025)
	Game.shake(0.45 if first else 0.25)
	Game.sfx("hit_big", -3.0, 0.15)


## Slapshot (Harpoon's LMB ending): the molten fist goes out to the row (Molten Palm's fist and the tentacle behind
## it) and, as it lands, punches every cube along his aim, steam going up where the magma meets the ice. Each slides
## (thrown_foe `slide`, a frost streak behind it): into a wall within SLIDE_REACH it shatters there for x
## SLIDE_WALL_MULT, otherwise it slows, stops and bursts for SLIDE_DAMAGE.
static func _slapshot(hero: CharacterBody3D, _b: Dictionary, at: Vector3, held: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var fwd: Vector3 = hero._brk_dir
	var picked := ENV.chosen(hero, "slapshot")  # (round 50: the wall or pillar the cursor was on at the press)
	if not picked.is_empty():
		var to: Vector3 = ENV.surface(picked, at).at - at
		if to.length() > 0.5:
			fwd = _flat(to).normalized()
			hero._brk_dir = fwd
			hero._face(fwd)
	var base: float = SLIDE_DAMAGE * hero._dmg_mult * mult
	var near := INF
	for e: Node3D in held:
		near = minf(near, _flat(e.global_position - at).dot(fwd) - float(e.radius))
	if held.is_empty():
		near = 1.5
	var length: float = maxf(near + SLIDE_FIST_PAST, 1.2)
	var fist := _fist(parent, at, fwd, length)
	SLAPSHOT_FX.cord(hero, fist, FIST_TIME)
	var tw := parent.create_tween()
	tw.tween_interval(FIST_TIME * 0.75)  # (the fist eases out: it is at the row by then)
	tw.tween_callback(_punch_row.bind(hero, held, fwd, base))


static func _punch_row(hero: Variant, held: Array, fwd: Vector3, damage: float) -> void:
	if not is_instance_valid(hero):
		return
	var parent: Node = hero.get_parent()
	Game.hitstop(0.06)
	Game.shake(0.5)
	Game.sfx("hit_big", -1.0, 0.1)
	var steamed := 0
	for e: Variant in held:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var foe: Node3D = e
		encase(foe)  # (fresh ice for the slide: the hang ran the freeze down)
		if steamed < 3:  # (three clouds read; five over a row was one white wall)
			SLAPSHOT_FX.punch(parent, foe.global_position - fwd * 0.4)
			steamed += 1
		foe.set_meta(CAMERA_CUE, Time.get_ticks_msec() + SLIDE_CUE_MS)
		var t: Node = THROWN.launch(hero, foe, foe.global_position + fwd * SLIDE_REACH, damage,
			{"solid": false, "el": "water", "speed": SLIDE_SPEED, "land_y": 0.0, "wall_mult": SLIDE_WALL_MULT,
			"slide": true, "splash": false, "spin": SLIDE_SPIN, "on_burst": _slid.bind(parent),
			"wall_gap": maxf(ice_radius(foe) - THROWN.WALL_MARGIN, 0.0)})  # (the ice's face meets the wall, not its middle)
		if t != null:
			SLAPSHOT_FX.trail(parent, foe)
		Game.register_hit("breaker")


static func _slid(f: Node3D, walled: bool, dir: Vector3, parent: Node) -> void:
	if walled and is_instance_valid(parent):
		SLAPSHOT_FX.wall(parent, f.global_position, dir)


## Each frozen foe is hurled at someone: anyone it wasn't holding first, then the others it was.
static func _cold_front(hero: CharacterBody3D, b: Dictionary, at: Vector3, seized: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	ELEMENTS.nova(parent, at, "water", 3.0, 8)
	_pop(parent, at, "spear")
	for i in seized.size():
		var e: Node3D = seized[i]
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to := cube_target(e, seized, at, hero.get_tree().get_nodes_in_group("enemies"), hero._facing())
		var tw := parent.create_tween()
		tw.tween_interval(i * CUBE_STAGGER)
		tw.tween_callback(THROWN.launch.bind(hero, e, to, damage))


## Collapse (round 51 cool pass): the hole falls in on itself and swallows everyone near it, a tentacle out of it on
## each (collapse_spit.gd), then spits them back out one at a time: into the wall or pillar the indicator marks
## (env_target "collapse", within COLLAPSE_REACH of the hole), or up out of the floor in the open.
static func _collapse(hero: CharacterBody3D, b: Dictionary, at: Vector3, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	if is_instance_valid(hero._void.hole):
		hero._void.hole.collapse()
	else:
		spot = at
		DARK.burst(hero.get_parent(), spot, 2.0)
	var wall := pinwheel_target(hero, spot, "collapse", ENV.COLLAPSE_REACH)  # (the indicator's pick; a raycast in a bare room)
	var foes: Array = FOES.near(hero.get_tree(), spot, COLLAPSE_RADIUS).filter(func(e: Node3D) -> bool: return not THROWN.flying(e))
	var g: Node3D = COLLAPSE_SPIT.start(hero, spot, foes, hero._void.is_heavy)
	g.on_swallow = func(e: Node3D) -> void:
		DARK.quiet_hit(e, damage * COLLAPSE_SWALLOW_MULT, true)
		Game.register_hit("breaker")
	g.on_spit = _collapse_spit.bind(hero, spot, wall, damage)
	for e: Node3D in foes:
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + COLLAPSE_CUE_MS)
	Game.shake(0.6)


## One of Collapse's spits (collapse_spit.on_spit): `e` comes back up out of the hole and is thrown into the structure,
## or up and clear; a big one is hit where the tentacle holds it.
static func _collapse_spit(e: Node3D, i: int, hero: Variant, spot: Vector3, wall: Dictionary, damage: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	ComicFx.say(COLLAPSE_WORD if i == 0 else COLLAPSE_SPIT_WORDS[i % COLLAPSE_SPIT_WORDS.size()], spot + Vector3.UP * (2.4 + 0.35 * (i % 2)),
		ALT_FX.WALL_WORD_SIZE * (1.0 if i == 0 else 0.8))  # (round 52: a word a spit, each its own beat)
	Game.sfx("hit_big", -3.0, 0.12)
	Game.hitstop(0.03)
	if hero._void.is_heavy(e):
		e.take_hit(damage, Vector3.ZERO, 0.0, true)
		Game.register_hit("breaker")
		return
	if wall.get("found", false):
		var face: Vector3 = ENV.surface(wall.s, e.global_position).at if wall.has("s") else wall.at
		var aim: Vector3 = face - _flat(e.global_position)
		THROWN.launch(hero, e, _flat(e.global_position) + aim.normalized() * (aim.length() + 1.5), damage,
			{"solid": false, "el": "void", "speed": COLLAPSE_WALL_SPEED, "land_y": 0.0, "wall_mult": COLLAPSE_WALL_MULT,
			"splash": false, "on_burst": _cool_wall.bind(hero.get_parent(), "void")})
	else:
		var out := _flat(e.global_position - spot)
		out = out.normalized() if out.length() > 0.05 else Vector3(sin(i * 2.4), 0.0, cos(i * 2.4))
		e.take_hit(damage, out * COLLAPSE_THROW * 0.5, COLLAPSE_SPIT_UP, true)
	Game.register_hit("breaker")


## A rebuilt ending's foe slamming into a wall or pillar (thrown_foe's on_burst): the beat on it (breaker_alt_fx).
static func _cool_wall(f: Node3D, walled: bool, dir: Vector3, parent: Node, el: String) -> void:
	if walled and is_instance_valid(parent):
		ALT_FX.cool_wall(parent, f.global_position, dir, el)


## Jaws of darkness shut on the pool, and on everyone in it.
static func _maw(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	var jaws: Node3D = hero._void.dark_maw
	if not is_instance_valid(jaws):
		jaws = DARK.maw(hero.get_parent(), spot, MAW_RADIUS)
	jaws.bite()
	for e: Node3D in FOES.near(hero.get_tree(), spot, MAW_RADIUS):
		DARK.quiet_hit(e, damage, true, Vector3.DOWN * MAW_DOWN)
		Game.register_hit("breaker")
	ComicFx.hit(spot + Vector3.UP * 1.5, true)  # one word for the one bite
	Game.shake(0.6)


## They've gone down through the floor (hero_leap._start_dive). Round 51 cool pass: the deep gives them back, biggest
## first: a column of tentacles carries each up out of the floor, holds it, and slams it straight back down
## (abyss_rise.gd). One foe takes it all, a big one more (ABYSS_BIG_MULT); a crowd shares it (ABYSS_SHARE).
static func _abyss(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = hero._void.dark_spot
	var foes: Array = []
	if is_instance_valid(hero._void.dark_bind):
		for s: Dictionary in hero._void.dark_bind._held:
			if is_instance_valid(s.foe) and s.foe.is_alive() and not THROWN.flying(s.foe):
				foes.append(s.foe)
		hero._void.dark_bind._let_go()
	for e: Node3D in FOES.near(hero.get_tree(), spot, ABYSS_RADIUS):
		if not foes.has(e) and not THROWN.flying(e):
			foes.append(e)
	var parent: Node = hero.get_parent()
	if foes.is_empty():
		DARK.spout(parent, spot)
		Game.shake(0.6)
		return
	# the one the window's bracket was on (the cursor's, or the biggest) comes back up first and takes it whole
	var first: Node3D = ENV.picked_foe(hero, "abyss")
	if first == null or not foes.has(first):
		first = abyss_first(hero, foes)
	foes.erase(first)
	foes.push_front(first)
	var g: Node3D = ABYSS_RISE.start(hero, foes)
	g.on_rise = func(e: Node3D, i: int) -> void:
		DARK.quiet_hit(e, damage * ABYSS_RISE_MULT * (1.0 if i == 0 else ABYSS_SHARE), true)
		Game.register_hit("breaker")
	g.on_slam = _abyss_slam.bind(hero, damage)
	for e: Node3D in foes:
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + ABYSS_CUE_MS)
	DARK.burst(parent, spot, 1.6)
	Game.shake(0.6)


# --- Uproot (round 51, env-pieces lane: Abyss's LMB) --------------------------------------------------------------

## The pillar Uproot tears out for a foe pinned at `spot`: the one the indicator marks (env_target CTX "uproot", the
## cursor's pick included) within UPROOT_REACH, else the nearest live pillar in reach (rooms without env_target: the
## checks). null in the open.
static func uproot_pillar(hero: CharacterBody3D, spot: Vector3) -> Node3D:
	var env := ENV.pick(hero, "uproot", spot, UPROOT_REACH)
	if not env.has("none"):
		if env.found and env.s.kind == "pillar" and ENV_PIECE.live(env.s.get("node")):
			return env.s.node
		return null
	var near: Array = ENV_PIECE.near(hero.get_tree(), "pillar", spot, UPROOT_REACH)
	return near[0] if not near.is_empty() else null


## The foe Uproot clubs: the nearest living one to Overwhelm's spot.
static func uproot_target(hero: CharacterBody3D, spot: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for e: Node3D in FOES.near(hero.get_tree(), spot, OVERWHELM_RADIUS):
		var d := _flat(e.global_position - spot).length()
		if d < best_d:
			best_d = d
			best = e
	return best


## Who Abyss gives back first by default: the biggest of `foes` (a heavy one before the rest), or null.
static func abyss_first(hero: CharacterBody3D, foes: Array) -> Node3D:
	var best: Node3D = null
	var best_r := -INF
	for e: Variant in foes:
		if not is_instance_valid(e):
			continue
		var r: float = float((e as Node).get("radius")) + (10.0 if hero._void.is_heavy(e) else 0.0)
		if r > best_r:
			best_r = r
			best = e
	return best


## The dive starts (hero_leap._start_dive): no sinking through the floor (Abyss's), and the tentacle takes hold of the
## pillar and tears it out of the floor (ALT_FX.uproot_tear) while he comes down.
static func uproot_dive(hero: CharacterBody3D) -> void:
	if is_instance_valid(hero._void.dark_bind):
		hero._void.dark_bind.sink = 0.0
	var spot: Vector3 = _flat(hero._void.dark_spot)
	var p := uproot_pillar(hero, spot)
	if p == null:
		hero.remove_meta(UPROOT_META)
		return
	hero.set_meta(UPROOT_META, p)
	ENV_PIECE.claim(p)  # (out of the swing anchors and the indicator now: it is coming up)
	ALT_FX.uproot_tear(hero.get_parent(), hero, p)


## Uproot lands: the pillar comes down on the foe along the line pillar -> foe (ALT_FX.uproot_club), the hits on the
## club's arrival; the pillar stays down as rubble. With none torn out, a short slam on the foe alone.
static func _uproot(hero: CharacterBody3D, b: Dictionary, mult: float) -> void:
	var damage: float = b.damage * hero._dmg_mult * mult
	var spot: Vector3 = _flat(hero._void.dark_spot)
	var target := uproot_target(hero, spot)
	if is_instance_valid(hero._void.dark_bind):
		hero._void.dark_bind._let_go()
	var parent: Node = hero.get_parent()
	var p: Variant = hero.get_meta(UPROOT_META) if hero.has_meta(UPROOT_META) else null
	hero.remove_meta(UPROOT_META)
	if not is_instance_valid(p):
		var at: Vector3 = _flat(target.global_position) if target != null else spot
		ALT_FX.uproot_open(parent, at)
		if target != null:
			target.take_hit(UPROOT_OPEN * hero._dmg_mult * mult, Vector3.DOWN * UPROOT_DOWN, 0.0, true)
			Game.register_hit("breaker")
		return
	var pillar: Node3D = p
	var base := _flat(pillar.global_position)
	var head: Vector3 = _flat(target.global_position) if target != null else spot
	var dir := head - base
	dir = dir.normalized() if dir.length() > 0.05 else hero._facing()
	var reach: float = (head - base).length() - UPROOT_REACH_IN
	if reach > UPROOT_LENGTH:  # (far: the tentacle carries the pillar in so its head lands on the foe)
		base += dir * (reach - UPROOT_LENGTH)
	var line_end := base + dir * UPROOT_LENGTH
	for e: Node3D in FOES.near(hero.get_tree(), (base + line_end) * 0.5, UPROOT_LENGTH):
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + 1200)
	ALT_FX.uproot_club(parent, hero, pillar, base, dir, UPROOT_FALL, _uproot_hit.bind(hero, target, base, line_end, damage))
	ENV_PIECE.topple(pillar, base, dir)


## The club arrives: the foe into the floor, everyone else on the fall line takes UPROOT_LINE of it, all buried.
static func _uproot_hit(hero: Variant, target: Variant, base: Vector3, line_end: Vector3, damage: float) -> void:
	if not is_instance_valid(hero):
		return
	var h := hero as CharacterBody3D
	var struck := {}
	if is_instance_valid(target) and target.is_alive():
		struck[target] = true
		target.take_hit(damage * (UPROOT_HEAVY if h._void.is_heavy(target) else 1.0), Vector3.DOWN * UPROOT_DOWN, 0.0, true)
		mark(target, "buried")
		Game.register_hit("breaker")
	for e: Node3D in FOES.near(h.get_tree(), (base + line_end) * 0.5, UPROOT_LENGTH * 0.5 + UPROOT_LINE_R):
		if struck.has(e):
			continue
		var p := _flat(e.global_position)
		var ab := line_end - base
		var k := clampf((p - base).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(base + ab * k) > UPROOT_LINE_R + float(e.radius):
			continue
		e.take_hit(damage * UPROOT_LINE, Vector3.DOWN * UPROOT_DOWN, 0.0, true)
		mark(e, "buried")
		Game.register_hit("breaker")
	ENV_PIECE.played("uproot")


## Abyss's third beat (abyss_rise.on_slam): the column drives `e` down into the floor: the hit, the crater.
static func _abyss_slam(e: Node3D, i: int, hero: Variant, damage: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var big: bool = hero._void.is_heavy(e)
	var share: float = 1.0 if i == 0 else ABYSS_SHARE
	e.take_hit(damage * share * ABYSS_SLAM_MULT * (ABYSS_BIG_MULT if big else 1.0), Vector3.DOWN * MAW_DOWN, 0.0, true)
	Game.register_hit("breaker")
	Game.sfx("hit_big", -2.0, 0.1)
	ALT_FX.cool_wall(hero.get_parent(), e.global_position, Vector3.DOWN, "void", ABYSS_WORD if i == 0 else "")
	DARK.burst(hero.get_parent(), _flat(e.global_position), 1.3 if big else 1.0)


## Where a cube is on its way up and into the pile, `k` 0 to 1 through the dive: up fast and a little way in,
## then down hard onto its place. Round 51: its place may be up the tower (`to.y`, aim_crush's stack slot), so it goes
## up CRUSH_HIGH over that and comes down onto the cube under it.
static func crush_point(from: Vector3, to: Vector3, k: float) -> Vector3:
	const TOP := 0.55
	var above: Vector3 = from.lerp(to, 0.3)
	var high: float = CRUSH_HIGH + maxf(to.y, 0.0)
	if k < TOP:
		var j := k / TOP
		var ease_out := 1.0 - (1.0 - j) * (1.0 - j)
		var at: Vector3 = from.lerp(above, ease_out)
		at.y = high * ease_out
		return at
	var j := (k - TOP) / (1.0 - TOP)
	var down: Vector3 = above.lerp(to, j)
	down.y = lerpf(high, maxf(to.y, 0.0), j * j)
	return down


## Is this foe in one of his cubes?
static func in_cube(e: Node) -> bool:
	return e.get_node_or_null(THROWN.CUBE_NAME) != null


## Avalanche (round 51 cool pass): the dive stacked the cubes into a tower; his landing crushes it, and the tentacles
## push it over (avalanche_topple.gd) toward the wall or pillar the indicator marks, or away from him in the open. Each
## cube comes off the falling tower top first and slides on: into the structure, shattering on it, or out to a stop.
## Anyone else in the fall's strip is caught and frozen.
static func _avalanche(hero: CharacterBody3D, b: Dictionary, cubes: Array, mult: float) -> void:
	var parent: Node = hero.get_parent()
	var damage: float = b.damage * hero._dmg_mult * mult
	var mid: Vector3 = hero._void.dark_spot
	var stack: Array = cubes.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_alive())
	var plan := avalanche_plan(hero, mid)
	_pop(parent, mid, "spear")
	if DESIGNED.on():
		DESIGNED.ice_shatter(parent, mid + Vector3.UP * 0.9, 1.3)
	for e: Node3D in stack:
		DARK.quiet_hit(e, damage * AVALANCHE_CRUSH, true)
		encase(e)  # (the crush mustn't break them out: the cubes are what falls)
		hero.get_tree().create_timer(0.03, true, false, true).timeout.connect(encase.bind(e))  # (again: the crush's shatter lands after)
		e.set_meta(CAMERA_CUE, Time.get_ticks_msec() + AVALANCHE_CUE_MS)
		Game.register_hit("breaker")
	var dir: Vector3 = plan.dir
	var side := dir.cross(Vector3.UP).normalized()
	for e: Node3D in hero.get_tree().get_nodes_in_group("enemies"):
		if e in stack or not e.is_alive():
			continue
		var rel := _flat(e.global_position - mid)
		var along := rel.dot(dir)
		if rel.length() <= CRUSH_RADIUS or (along > 0.0 and along <= float(plan.run) and absf(rel.dot(side)) <= AVALANCHE_STRIP + float(e.radius)):
			DARK.quiet_hit(e, damage * PRESS_NO_CUBE, true)
			chill_or_freeze(e)
			Game.register_hit("breaker")
	if stack.is_empty():
		return
	var g: Node3D = AVALANCHE_TOPPLE.start(hero, mid, stack, dir, float(plan.run))
	g.on_throw = _avalanche_throw.bind(hero, mid, plan, damage, stack.size())
	ComicFx.hit(mid + Vector3.UP * 1.5, true)  # one word for the crash (the wall hits say AVALANCHE_WORD)


## Where Avalanche's tower falls: {dir, run, wall (the env pick or {}), found}. Toward the structure the indicator marks
## within AVALANCHE_REACH of the tower's foot `mid`, else away from him (his dive's line).
static func avalanche_plan(hero: CharacterBody3D, mid: Vector3) -> Dictionary:
	var wall := pinwheel_target(hero, mid, "avalanche", AVALANCHE_REACH)  # (the indicator's pick; a raycast in a bare room)
	if wall.get("found", false):
		var d: Vector3 = _flat(wall.dir)
		return {"found": true, "wall": wall, "dir": d.normalized() if d.length() > 0.01 else hero._facing(), "run": float(wall.dist) + 1.5}
	var away := _flat(mid - hero.global_position)
	if away.length() < 0.3:
		away = _flat(hero._brk_dir) if hero._brk_dir.length() > 0.01 else hero._facing()
	return {"found": false, "wall": {}, "dir": away.normalized(), "run": AVALANCHE_OPEN}


## One cube off the falling tower (avalanche_topple.on_throw, `i` from the foot): it slides on to the structure (spread
## across it) or out along the fall, the top one furthest.
static func _avalanche_throw(e: Node3D, i: int, hero: Variant, mid: Vector3, plan: Dictionary, damage: float, n: int) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(e) or not e.is_alive():
		return
	var dir: Vector3 = plan.dir
	var side := dir.cross(Vector3.UP).normalized()
	var to: Vector3
	if plan.found:
		to = mid + dir * float(plan.run) + side * AVALANCHE_SPREAD * (i - (n - 1) * 0.5)
	else:
		to = mid + dir * float(plan.run) * (0.45 + 0.55 * float(i + 1) / float(n)) + side * AVALANCHE_SPREAD * 0.5 * (i - (n - 1) * 0.5)
	THROWN.launch(hero, e, to, damage * (1.0 if plan.found else AVALANCHE_OPEN_MULT), {"solid": false, "el": "water", "speed": AVALANCHE_SPEED, "land_y": 0.0, "slide": true,
		"wall_mult": AVALANCHE_WALL_MULT, "splash": false, "spin": 3.0, "on_burst": _avalanche_hit.bind(hero.get_parent())})
	Game.register_hit("breaker")


static func _avalanche_hit(f: Node3D, walled: bool, dir: Vector3, parent: Node) -> void:
	if walled and is_instance_valid(parent):
		ALT_FX.cool_wall(parent, f.global_position, dir, "water", AVALANCHE_WORD)


## Where a cube goes. Pure, so the check can walk it.
static func cube_target(e: Node3D, seized: Array, at: Vector3, all: Array, facing: Vector3) -> Vector3:
	var best: Node3D = null
	var best_d := INF
	for pool: Array in [all.filter(func(o: Node3D) -> bool: return not o in seized), seized]:
		for o: Node3D in pool:
			if o == e or not is_instance_valid(o) or not o.is_alive():
				continue
			var d := _flat(o.global_position - e.global_position).length()
			if d < best_d and d <= CUBE_SEEK:
				best = o
				best_d = d
		if best != null:
			return _flat(best.global_position)
	var out := _flat(e.global_position - at)
	return _flat(e.global_position) + (out.normalized() if out.length() > 0.2 else facing) * CUBE_REACH


## The element coming up through the floor at `spot`.
static func under(parent: Node, spot: Vector3, el: String) -> void:
	match el:
		"earth":
			ELEMENTS.rim_geyser(parent, spot, GEYSER_RADIUS, GEYSER_HIGH, false)
			ELEMENTS.spikes(parent, spot, "earth", CRYSTAL_SIZE, 3, 1.0)  # (round 33, sleek 5: a full geyser and five spikes under each foe walled Worldbreaker's pile)
		"water":
			ELEMENTS.spikes(parent, spot, "water", CRYSTAL_SIZE, 6, 1.0)
			Fx.shards(parent, spot + Vector3.UP * 0.6, Color(0.85, 0.96, 1.0), 10, Vector3.UP, 8.0, 0.14, 0.6)
		"wind":
			ELEMENTS.storm_strike(parent, spot, "wind")
		"spirit":
			ELEMENTS.storm_strike(parent, spot, "spirit")
		"void":
			DARK.burst(parent, spot, 1.2)


# --- Helpers ------------------------------------------------------------------

## Living foes in a strip ahead of him.
static func _ahead(hero: CharacterBody3D, at: Vector3, fwd: Vector3, length: float, half_width: float) -> Array:
	return hero.get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e.is_alive() and hero._in_strip(_flat(e.global_position - at), fwd, length, half_width, e.radius))


## Everything near `at` is hit and dragged towards it.
static func _pull(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, strength: float, launch: float) -> int:
	var foes: Array = FOES.near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var to := _flat(at - e.global_position)
		e.take_hit(damage, (to.normalized() if to.length() > 0.01 else Vector3.ZERO) * strength, launch, false)
		Game.register_hit("cast")
	return foes.size()


## Everything near `at` is hit and thrown out from it. Returns who.
static func _strike(hero: CharacterBody3D, at: Vector3, radius: float, damage: float, launch: float, big: bool) -> Array:
	var foes: Array = FOES.near(hero.get_tree(), at, radius)
	for e: Node3D in foes:
		var from := _flat(e.global_position - at)
		e.take_hit(damage, (from.normalized() if from.length() > 0.01 else Vector3.ZERO) * 4.0, launch, big)
		Game.register_hit("cast")
	return foes


static func chill_or_freeze(e: Node3D) -> void:
	if not is_instance_valid(e) or not e.is_alive():
		return
	if e.has_method("is_boss"):
		e.chill(FREEZE_TIME, BOSS_CHILL)
	elif e.has_method("freeze"):
		e.freeze(FREEZE_TIME, FREEZE_BREAK)


static func _pop(parent: Node, at: Vector3, form: String) -> void:
	FORM_FX.spawn(parent, at + Vector3.UP * 0.8, form, Vector3.ZERO, 0.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)



# --- The element matrix (round 34, third pass; round 49: one payoff rule per state; docs/features/element-matrix.md) --
# Kit grammar section 3 (docs/characters/kit-grammar.md): six states, and each has ONE payoff rule (RULES) that any
# element's hit triggers, so a new character or element never adds cells. A character's own element on its own state
# does its move's own thing (RULE_OWN: storm on charged is Live Wire's pulse), and the moves that pay a state in their
# own body keep it (RULE_SELF: Molten Palm's steam on the ice, Updraft Lash digging up the buried, Tow Line's air rip,
# the air string). The old per-cell payoffs (IMPROV) are upgrades now (IMPROV_UPGRADE, Kit.has(): off, the rule plays;
# on, the richer cell plays in its place). Paid by the element's base moves (not the X* crossovers, which read their own)
# through improvise(), at the top of fire(), before the move's own hit, so a payoff never moves a foe the move is about
# to throw. Each rule's look is one tell tinted by the hitting element (comic_improv.gd LOOKS keyed by the state); each
# upgrade cell keeps its own ("<state>_x_<element>"); words ComicFx.IMPROV_WORDS.

## state -> its payoff rule (_pay()'s kind), the same for every element and character.
const RULES := {"bound": "snap", "molten": "burst", "buried": "crater", "frozen": "shatter", "airborne": "juggle", "charged": "arc"}
## The rules' names (the combo guide's "+ name" tag and the MIX ELEMENTS page; the autotest's [improv] keys by state).
const RULE_NAMES := {"bound": "Snap", "molten": "Burst", "buried": "Crater", "frozen": "Shatter", "airborne": "Juggle", "charged": "Arc"}
## The element that leaves the state: on it, its own move's thing plays, never the rule (Abyss off Overwhelm, Live
## Wire's pulse, ice on ice refreezes, Eruption). airborne and buried are element-free.
const RULE_OWN := {"bound": "void", "charged": "wind", "frozen": "water", "molten": "earth"}
## Who pays a state in its own move body (an element, or one move id), so the rule stays out and it doesn't pay twice:
## Molten Palm's steam on the ice (Steam Burst's), Updraft Lash digging up the buried (_cash_buried), the air string's
## juggle (Air Slash, Live Wire), Tow Line's rip out of the air (TOW_AIR_MULT).
const RULE_SELF := {"frozen": ["EM"], "buried": ["EC"], "airborne": ["wind", "TW"]}
const RULE_SHATTER_MULT := 1.6  # frozen: the hit shatters the ice for this (and the ice's FREEZE_BREAK, as any hit on it)
const RULE_ARC_R := 6.0  # m: charged: the hit arcs on from the payer to every other charged foe this near (chained)
const RULE_BURST_R := 2.2  # m: molten: it goes off, and the burn catches everyone this near it
const RULE_JUGGLE_LAUNCH := 7.0  # m/s: airborne: the hit keeps it up there (a juggle, not a fresh launch)
## The old cells, now upgrades: state -> element -> payoff kind (_pay()). Each needs its Kit id on (IMPROV_UPGRADE).
## buried x magma (Aftershock) is the crater rule itself, so it is not here.
const IMPROV := {
	"skewered": {"water": "spread", "void": "tear"},
	"molten": {"wind": "fan", "water": "quench", "earth": "erupt", "void": "smother"},
	"buried": {"water": "encase", "void": "swallow"},
	"bound": {"wind": "loose", "water": "encase"},
	"frozen": {"wind": "lift", "void": "shards"},
	"airborne": {"water": "freeze", "earth": "spike"},
	"charged": {"void": "conduct", "water": "superconduct", "earth": "flash", "wind": "overload"},
}
## Each upgrade cell's Kit id (kit.gd UPGRADES has its doc line).
const IMPROV_UPGRADE := {
	"skewered_x_water": "ice_spreads", "skewered_x_void": "torn_off",
	"molten_x_wind": "firestorm", "molten_x_water": "quench", "molten_x_earth": "flare_up", "molten_x_void": "smother",
	"buried_x_water": "frozen_in", "buried_x_void": "swallowed",
	"bound_x_wind": "torn_loose", "bound_x_water": "frozen_dark",
	"frozen_x_wind": "gale_lift", "frozen_x_void": "shard_cut",
	"airborne_x_water": "freeze_aloft", "airborne_x_earth": "meteor_spike",
	"charged_x_void": "conduct", "charged_x_water": "superconduct", "charged_x_earth": "arc_flash", "charged_x_wind": "overload",
}
## A foe in several states pays the first with a rule or an upgrade cell for the element, in this order (the skewered
## are frozen too: with neither of its upgrades on, a skewered foe pays the frozen rule). Charged is last: the lightning
## goes into nearly everyone (every Live Wire jolt), so it's what pays when nothing rarer is there.
const IMPROV_ORDER := ["skewered", "molten", "buried", "bound", "frozen", "airborne", "charged"]
const IMPROV_REACH := 5.0  # m round him: a move with no hit shape of its own (improv_reach()) reaches this far
const IMPROV_DAMAGE := 8.0  # each payoff's hit (x FREEZE_BREAK on the ice, as any hit on it)
const IMPROV_MULT := 1.5  # the harder payoffs (crater, snap, burst; the cells swallow, smother, spike, tear, loose)
const IMPROV_LAUNCH := 8.0  # m/s up: lift, fan, loose (a fresh launch: at least enemy.RELAUNCH_MIN)
const IMPROV_DOWN := 6.0  # m/s into the floor: crater, swallow, smother, spike (enemy._is_spike craters them)
const IMPROV_CHAIN_R := 2.6  # m round the payer that a chain (shards, fan, spread) jumps to its neighbour
const IMPROV_CHAIN_DAMAGE := 5.0  # (and each link of the arc rule, each foe the burst rule's burn catches)
const IMPROV_PULL := 6.0  # m/s towards him: tear (yanked off the spear)
const IMPROV_STEAM_MULT := 1.6  # quench: water on the molten goes off in steam, like the ice under magma
const IMPROV_HOLD := 0.6  # s swallow keeps them stuck in the floor
## The charged state (round 44): lightning that went into a foe stays in it (mark(e, "charged"): Live Wire's jolts,
## Grounded, Storm Pitch, Galvanize, Fault Line, Cataclysm). Its rule is the arc; these are its four upgrade cells'.
const CONDUCT_R := 3.0  # m: Conduct (dark) carries the charge on to every uncharged foe this near the payer...
const CONDUCT_MOST := 4  # ...this many at most...
const CONDUCT_DAMAGE := 5.0  # ...each zapped for this, and charged; the payer stays charged
const SUPER_R := 7.0  # m: Superconduct (ice) freezes the payer, and the charge runs through every frozen foe this near
const SUPER_DAMAGE := 6.0  # each (x FREEZE_BREAK: it's on the ice), and they're charged
const FLASH_R := 2.8  # m: Arc Flash (magma) blows the foes this near the payer away from it...
const FLASH_THROW := 4.5  # ...this far (thrown_foe: on to a wall short of that, and splatted there)...
const FLASH_DAMAGE := 5.0  # ...for this as it goes off...
const FLASH_SPLAT := 6.0  # ...and this where they land (x PALM_WALL_MULT on a wall)
const FLASH_SPEED := 20.0  # m/s
const OVERLOAD_R := 8.0  # m: Overload (storm) discharges every charged foe this near the move at once...
const OVERLOAD_PER := 0.35  # ...each zap this much harder for every other charged foe in it
static var _overload_n := 1  # (how many were charged as the move fired: read before the first payer discharges them)
static var improv_paid := {}  # rule state ("frozen") or upgrade cell ("frozen_x_wind") -> payoffs so far ([improv])


## What `e` pays when the element `el` (move `id`) hits it: an upgrade cell ("frozen_x_wind") when its Kit id is on, a
## state's rule ("frozen"), or "" (IMPROV_ORDER; the state's own element and RULE_SELF never pay the rule).
static func improv_cell(e: Node, el: String, id := "") -> String:
	for state: String in IMPROV_ORDER:
		if not in_state(e, state):
			continue
		var cell := "%s_x_%s" % [state, el]
		if IMPROV.get(state, {}).has(el) and Kit.has(IMPROV_UPGRADE[cell]):
			return cell
		if RULES.has(state) and RULE_OWN.get(state, "") != el and not _pays_itself(state, el, id):
			return state
	return ""


static func _pays_itself(state: String, el: String, id: String) -> bool:
	var who: Array = RULE_SELF.get(state, [])
	return el in who or (id != "" and id in who)


## The state a cell (improv_cell()) is about: "frozen_x_wind" and "frozen" are both "frozen".
static func cell_state(cell: String) -> String:
	return cell.get_slice("_x_", 0)


## A cell's name: the rule's (RULE_NAMES) or the upgrade cell's (MIX ELEMENTS: move_list.mix_name()).
static func improv_name(cell: String) -> String:
	if RULE_NAMES.has(cell):
		return RULE_NAMES[cell]
	return load("res://scripts/move_list.gd").mix_name(cell_state(cell), cell.get_slice("_x_", 1))  # (load: move_list preloads this)


## The state on `e` the element `el` pays, or "" (improv_cell()'s state).
static func improv_state(e: Node, el: String, id := "") -> String:
	return cell_state(improv_cell(e, el, id))


static func in_state(e: Node, state: String) -> bool:
	match state:
		"frozen":
			return is_frozen(e)
		"airborne":
			return e.is_airborne()
		"bound":
			return BIND.holds(e)
	return marked(e, state)


## A base element move's improvised payoffs on everyone its own hit shape reaches (improv_reach()) in a state: each
## pays its state's rule, or the upgrade cell in its place. Returns how many paid.
static func improvise(hero: CharacterBody3D, id: String, at: Vector3, power: float, fwd := Vector3.ZERO) -> int:
	if id.begins_with("X") or not ELEMENT_OF.has(id):
		return 0
	var el: String = ELEMENT_OF[id]
	var due := []  # (read every state first: a chain sets one on the neighbour, which mustn't pay in the same move)
	var near: Array = improv_reach(hero, id, at, fwd if fwd.length_squared() > 0.001 else hero._facing())
	for e: Node3D in near:
		var cell := "" if THROWN.flying(e) else improv_cell(e, el, id)
		if cell != "":
			due.append([e, cell])
	if el == "wind":
		_overload_n = maxi(1, FOES.near(hero.get_tree(), at, OVERLOAD_R).filter(func(o: Node3D) -> bool: return marked(o, "charged")).size())
	for d: Array in due:
		var cell: String = d[1]
		var state := cell_state(cell)
		if state == "charged" and not marked(d[0], "charged"):
			continue  # (an arc or Overload already discharged it, off another payer)
		if is_instance_valid(d[0]) and d[0].is_alive():
			var kind: String = RULES[state] if cell == state else IMPROV[state][el]
			_pay(hero, d[0], kind, state, at, power, cell, el)
			improv_paid[cell] = int(improv_paid.get(cell, 0)) + 1
	return due.size()


const IMPROV_ROLL_HALF_WIDTH := 1.0  # m either side of Ice Cube's roll: the cube and whoever it passes


## Round 4: who a base move's payoff reaches is who the move itself lands on, the shape you see it hit (was everyone
## IMPROV_REACH round him, so a foe behind him paid for a harpoon thrown ahead). Each shape reads the move body's
## own numbers; read before the move fires, so nobody has been thrown yet. A move with no hit of its own (the vault)
## reaches nobody; an id with no shape here falls back to its MOVES `range` / `arc` / `width`, then IMPROV_REACH.
static func improv_reach(hero: CharacterBody3D, id: String, at: Vector3, fwd: Vector3) -> Array:
	var tree := hero.get_tree()
	var grow: float = hero._cast_grow()
	match id:
		"EC":  # the gale's circle where the sweep throws them up
			var eye: Vector3 = at + fwd * minf(CUTTER_AHEAD, hero._clear_ahead(fwd, CUTTER_AHEAD))
			return FOES.near(tree, eye, CUTTER_RADIUS * grow)
		"EE", "EW":  # the tentacles' reach (Live Wire latches onto whoever they get to)
			return hero._void.reachable()
		"EA":  # the one it bowls, and the line the cube rolls down
			var bowl: Array = hero._void.reachable().filter(func(e: Node3D) -> bool:
				return _flat(e.global_position - at).length() <= BOWL_REACH)
			if bowl.is_empty():
				return []
			bowl.sort_custom(func(a: Node3D, b: Node3D) -> bool:
				return _flat(a.global_position - at).length() < _flat(b.global_position - at).length())
			var from := _flat(bowl[0].global_position)
			var path := _ahead(hero, from, fwd, BOWL_LENGTH, IMPROV_ROLL_HALF_WIDTH)
			return path if bowl[0] in path else [bowl[0]] + path
		"EF":  # the tentacles' reach round him (round 47: everyone near, not a line)
			return harpoon_targets(hero, at, HARPOON_REACH * grow)
		"IP":  # the frost round where the spear goes in
			var spot: Vector3 = at + fwd * minf(SPEAR_AHEAD, hero._clear_ahead(fwd, SPEAR_AHEAD))
			return FOES.near(tree, spot, SPEAR.RADIUS)
		"IJ":  # the vault hits nobody
			return []
		"IS":  # the frost ring round the spear (or him)
			var s: Node3D = SPEAR.current(tree)
			return FOES.near(tree, _flat(s.global_position) if s != null else at, DEEP_FREEZE_RADIUS)
		"EM":  # the fist's lava line
			var length: float = minf(PALM_LENGTH * grow, hero._clear_ahead(fwd, PALM_LENGTH * grow) + 0.5)
			return _ahead(hero, at, fwd, length, PALM_HALF_WIDTH)
		"EV":  # the tendrils round him, and whoever the palm shoved
			var foes: Array = FOES.near(tree, at, UNDERTOW_RADIUS)
			for e: Variant in hero._void.shoved:
				if is_instance_valid(e) and e.is_alive() and not e in foes and _flat(e.global_position - at).length() <= UNDERTOW_CHASE:
					foes.append(e)
			return foes
		"VS":  # the hole where the slam comes down
			return FOES.near(tree, _flat(hero._void._aim_at), DARK.Hole.RADIUS)
		"VR":  # the crescent in front of him
			return FOES.near(tree, at, REAP_REACH).filter(func(e: Node3D) -> bool:
				var to := _flat(e.global_position - at)
				return to.length() <= 0.3 or fwd.angle_to(to.normalized()) <= REAP_HALF_ANGLE)
		"VD":  # whoever the tide drags: the marked, or with none, those near
			var marked_foes: Array = FOES.near(tree, at, TIDE_REACH).filter(func(e: Node3D) -> bool: return DARK.marked(e))
			return marked_foes if not marked_foes.is_empty() else FOES.near(tree, at, TIDE_NEAR)
		"OW":  # the pool under whoever he's aiming at
			return FOES.near(tree, _overwhelm_spot(hero, at, fwd), OVERWHELM_RADIUS)
		"TW":  # the line he just dashed along (near him with nobody on it)
			return _tow_line(hero, at)
	var m: Dictionary = hero.MOVES.get(id, {})
	if float(m.get("range", 0.0)) > 0.0:
		return tree.get_nodes_in_group("enemies").filter(func(e: Node3D) -> bool:
			var to := _flat(e.global_position - at)
			if not e.is_alive():
				return false
			if m.has("width"):
				return hero._in_strip(to, fwd, m.range, m.width, e.radius)
			return to.length() <= m.range + e.radius and (to.length() <= 0.4 or rad_to_deg(fwd.angle_to(to.normalized())) <= m.arc * 0.5))
	return FOES.near(tree, at, IMPROV_REACH)


## Where Overwhelm's pool opens: on the nearest foe in his aim's cone, else ahead (the aim _overwhelm() makes).
static func _overwhelm_spot(hero: CharacterBody3D, at: Vector3, fwd: Vector3) -> Vector3:
	var spot: Vector3 = at + fwd * minf(OVERWHELM_AHEAD, hero._clear_ahead(fwd, OVERWHELM_AHEAD))
	var best := INF
	for e: Node3D in FOES.near(hero.get_tree(), at, OVERWHELM_REACH):
		var to := _flat(e.global_position - at)
		if to.length() > 0.01 and rad_to_deg(fwd.angle_to(to.normalized())) > hero._void.CONE:
			continue
		if to.length() < best:
			best = to.length()
			spot = _flat(e.global_position)
	return spot


## One payoff (a RULES kind, or an upgrade cell's from IMPROV): one hit, and a state, a chain to the neighbour, a launch
## or a crater. `el` is the hitting element (a rule's tell is tinted by it).
static func _pay(hero: CharacterBody3D, e: Node3D, kind: String, state: String, at: Vector3, power: float, cell := "", el := "") -> void:
	var parent: Node = hero.get_parent()
	var spot := _flat(e.global_position)
	var heavy: bool = hero._void.is_heavy(e)
	var damage := IMPROV_DAMAGE * power
	var down := Vector3.DOWN * IMPROV_DOWN
	if state in ["buried", "molten", "skewered", "charged"]:
		unmark(e, state)  # (spent: once; Conduct charges it again)
	var next: Variant = null  # the neighbour a chain reached (its tell draws the jump)
	match kind:
		# The six rules (kit grammar section 3): any element's hit on the state.
		"shatter":  # frozen: the hit shatters the ice for RULE_SHATTER_MULT, and the ice is gone
			_break_ice(e)
			e.take_hit(damage * RULE_SHATTER_MULT, Vector3.ZERO, 0.0, true)
		"arc":  # charged: the hit arcs on to every other charged foe within RULE_ARC_R, discharging them
			zap_hit(e, damage)
			next = _arc(hero, e, IMPROV_CHAIN_DAMAGE * power)
		"burst":  # molten: it goes off, and the burn catches everyone within RULE_BURST_R
			e.take_hit(damage * IMPROV_MULT, Vector3.ZERO, 0.0, true)
			next = _burst(hero, e, IMPROV_CHAIN_DAMAGE * power)
		"snap":  # bound: the hold ends with a snap; no knockback, so no shield blocks it (and the held can't dodge)
			BIND.let_go_of(hero.get_tree(), e)
			e.take_hit(damage * IMPROV_MULT, Vector3.ZERO, 0.0, true)
		"juggle":  # airborne: the hit keeps it up there
			e.take_hit(damage, Vector3.ZERO, 0.0 if heavy else RULE_JUGGLE_LAUNCH, false)
		# "crater" (buried: driven back in for IMPROV_MULT) is below, with the upgrade cells that crater.
		# The upgrade cells (IMPROV_UPGRADE, Kit.has()).
		"lift":  # frozen x wind: the gale takes the cube up, still in its ice
			e.take_hit(damage, Vector3.ZERO, 0.0 if heavy else IMPROV_LAUNCH, true)
			freeze_aloft(e)
		"shards":  # frozen x dark (shard_cut): the dark crushes the ice, and the shards cut the one beside it
			THROWN.remove_cube(e)
			e.take_hit(damage, Vector3.ZERO, 0.0, true)
			next = _chain(hero, e, IMPROV_CHAIN_DAMAGE * power, "")
		"encase":  # buried / bound x ice: frozen where it's stuck
			e.take_hit(damage, Vector3.ZERO, 0.0, false)
			encase(e)
		"crater", "swallow", "smother", "spike":  # the buried rule, and molten / airborne / buried x earth or dark: into the floor
			e.take_hit(damage * IMPROV_MULT, down, 0.0, true)
			if kind == "swallow" and not heavy:
				e.stagger(IMPROV_HOLD)
		"fan":  # molten x wind: the gale fans the flames up, and onto the one beside it
			e.take_hit(damage, Vector3.ZERO, 0.0 if heavy else IMPROV_LAUNCH, true)
			next = _chain(hero, e, IMPROV_CHAIN_DAMAGE * power, "molten")
		"quench":  # molten x water: it goes off in steam
			e.take_hit(damage * IMPROV_STEAM_MULT, Vector3.ZERO, 0.0 if heavy else STEAM_LAUNCH, true)
		"erupt":  # molten x earth: the floor goes up under it
			e.take_hit(damage * ERUPT_MOLTEN_MULT, Vector3.ZERO, 0.0 if heavy else ERUPT_LAUNCH, true)
		"spread":  # skewered x ice: the ice climbs on to the nearest foe not in it, and skewers it too
			e.take_hit(damage, Vector3.ZERO, 0.0, false)
			encase(e)
			next = _chain(hero, e, 0.0, "skewered")
		"tear":  # skewered x dark: torn off the spear towards him
			THROWN.remove_cube(e)
			var back := _flat(at - e.global_position)
			e.take_hit(damage * IMPROV_MULT, back.normalized() * IMPROV_PULL if back.length() > 0.6 else Vector3.ZERO, 0.0, true)
		"freeze":  # airborne x ice: frozen up there; it comes down a cube
			e.take_hit(damage, Vector3.ZERO, 0.0, false)
			freeze_aloft(e)
		"loose":  # bound x wind: the gale tears it out of the bind and up
			BIND.let_go_of(hero.get_tree(), e)
			e.take_hit(damage * IMPROV_MULT, Vector3.ZERO, 0.0 if heavy else IMPROV_LAUNCH, true)
		"conduct":  # charged x dark: the dark carries the charge on, to everyone near not charged yet
			e.take_hit(damage, Vector3.ZERO, 0.0, true)
			mark(e, "charged")
			next = _conduct(hero, e, CONDUCT_DAMAGE * power)
		"superconduct":  # charged x ice: frozen, and the charge runs through all the ice near it
			e.take_hit(damage * IMPROV_MULT, Vector3.ZERO, 0.0, false)
			encase(e)
			next = _superconduct(hero, e, SUPER_DAMAGE * power)
		"flash":  # charged x magma: the charge goes off in the heat, and blows the ones beside it away
			e.take_hit(damage * IMPROV_MULT, Vector3.ZERO, 0.0, true)
			next = _arc_flash(hero, e, power)
		"overload":  # charged x storm: every charged foe near goes off at once, harder the more there are
			var k := 1.0 + OVERLOAD_PER * (_overload_n - 1)
			e.take_hit(damage * k, Vector3.ZERO, 0.0, true)
			next = _overload(hero, e, at, IMPROV_CHAIN_DAMAGE * power * k)
	if Game.comic_style:
		COMIC_IMPROV.spawn(parent, cell, e, at, next, el)
	Game.register_hit("cast")


## The frozen rule's ice, gone: the cube off now (renamed, so in_cube() reads it gone this frame) and the ice's time out.
static func _break_ice(e: Node3D) -> void:
	var cube: Node = e.get_node_or_null(THROWN.CUBE_NAME)
	if cube != null:
		cube.name = "ThrownCubeGone"
		cube.queue_free()


## The charged rule: an arc from `from` on through every other charged foe within RULE_ARC_R of it (nearest first,
## each from the last: one lime bolt path), `damage` each; they're discharged. Returns where the first went, or null.
static func _arc(hero: CharacterBody3D, from: Node3D, damage: float) -> Variant:
	var live: Array = FOES.near(hero.get_tree(), from.global_position, RULE_ARC_R).filter(func(o: Node3D) -> bool:
		return o != from and marked(o, "charged") and not THROWN.flying(o))
	var path := PackedVector3Array([from.global_position + Vector3.UP * 0.9])
	var last: Node3D = from
	while not live.is_empty():
		live.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_to(last.global_position) < b.global_position.distance_to(last.global_position))
		var o: Node3D = live.pop_front()
		path.append(o.global_position + Vector3.UP * 0.9)
		unmark(o, "charged")
		zap_hit(o, damage)
		Game.register_hit("cast")
		last = o
	if path.size() < 2:
		return null
	if DESIGNED.on():
		DESIGNED.bolt_path(hero.get_parent(), path, 0.24)
	else:
		for i in path.size() - 1:
			COMIC_BOLT.spawn(hero.get_parent(), path[i], path[i + 1], 0.24, 0.4)
	return path[1] - Vector3.UP * 0.9


## The molten rule's burn: everyone within RULE_BURST_R of `from` takes `damage` (a quiet burn). Returns where the
## nearest stood, or null.
static func _burst(hero: CharacterBody3D, from: Node3D, damage: float) -> Variant:
	var first: Variant = null
	var best := INF
	for o: Node3D in FOES.near(hero.get_tree(), from.global_position, RULE_BURST_R):
		if o == from or THROWN.flying(o):
			continue
		if o.has_method("burn_hit"):
			o.burn_hit(damage, false)
		else:
			o.take_hit(damage, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		var d: float = o.global_position.distance_to(from.global_position)
		if d < best:
			best = d
			first = o.global_position
	return first


## Conduct: an arc from `from` to each uncharged foe within CONDUCT_R (nearest first, CONDUCT_MOST), `damage`
## each, and charged. Returns where the first went (world), or null.
static func _conduct(hero: CharacterBody3D, from: Node3D, damage: float) -> Variant:
	var near: Array = FOES.near(hero.get_tree(), from.global_position, CONDUCT_R).filter(func(o: Node3D) -> bool:
		return o != from and not THROWN.flying(o) and not marked(o, "charged"))
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(from.global_position) < b.global_position.distance_to(from.global_position))
	near = near.slice(0, CONDUCT_MOST)
	for o: Node3D in near:
		COMIC_BOLT.spawn(hero.get_parent(), from.global_position + Vector3.UP * 0.9, o.global_position + Vector3.UP * 0.9, 0.18, 0.3)
		zap_hit(o, damage)
		mark(o, "charged")
		Game.register_hit("cast")
	return null if near.is_empty() else near[0].global_position


## Superconduct: an arc from `from` through every frozen foe within SUPER_R, `damage` each, and charged.
static func _superconduct(hero: CharacterBody3D, from: Node3D, damage: float) -> Variant:
	var ice: Array = FOES.near(hero.get_tree(), from.global_position, SUPER_R).filter(func(o: Node3D) -> bool:
		return o != from and is_frozen(o) and not THROWN.flying(o))
	ice.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(from.global_position) < b.global_position.distance_to(from.global_position))
	var last := from.global_position + Vector3.UP * 0.9
	for o: Node3D in ice:
		var to: Vector3 = o.global_position + Vector3.UP * 0.9
		COMIC_BOLT.spawn(hero.get_parent(), last, to, 0.2, 0.34)
		last = to
		o.take_hit(damage, Vector3.ZERO, 0.0, false)  # (frozen: x FREEZE_BREAK)
		mark(o, "charged")
		Game.register_hit("cast")
	return null if ice.is_empty() else ice[0].global_position


## Arc Flash: everyone within FLASH_R of `from` takes FLASH_DAMAGE and is thrown FLASH_THROW away from it, on to a
## wall short of that (thrown_foe: splatted there, PALM_WALL_MULT). Big ones only take the hit.
static func _arc_flash(hero: CharacterBody3D, from: Node3D, power: float) -> Variant:
	var first: Variant = null
	for o: Node3D in FOES.near(hero.get_tree(), from.global_position, FLASH_R):
		if o == from or THROWN.flying(o):
			continue
		var out := _flat(o.global_position - from.global_position)
		if out.length() < 0.05:
			out = _flat(o.global_position - hero.global_position)
		out = out.normalized() if out.length() > 0.01 else hero._facing()
		o.take_hit(FLASH_DAMAGE * power, Vector3.ZERO, 0.0, false)
		Game.register_hit("cast")
		if first == null:
			first = o.global_position
		if hero._void.is_heavy(o):
			continue
		var reach: float = THROWN.clear_from(hero, o, o.global_position, out, FLASH_THROW)
		THROWN.launch(hero, o, _flat(o.global_position) + out * reach, FLASH_SPLAT * power,
			{"quiet": true, "solid": false, "el": "earth", "speed": FLASH_SPEED, "land_y": 0.0, "wall_mult": PALM_WALL_MULT})
	Game.shake(0.35)
	return first


## Overload: an arc from `from` on through every other charged foe within OVERLOAD_R of `at` (nearest first, each
## from the last), `damage` each; they're discharged. Returns where the first went, or null.
static func _overload(hero: CharacterBody3D, from: Node3D, at: Vector3, damage: float) -> Variant:
	var live: Array = FOES.near(hero.get_tree(), at, OVERLOAD_R).filter(func(o: Node3D) -> bool:
		return o != from and marked(o, "charged"))
	var last: Node3D = from
	var first: Variant = null
	var k := 0  # (each link out a fatter bolt and a bigger star)
	while not live.is_empty():
		live.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_to(last.global_position) < b.global_position.distance_to(last.global_position))
		var o: Node3D = live.pop_front()
		COMIC_BOLT.spawn(hero.get_parent(), last.global_position + Vector3.UP * 0.9, o.global_position + Vector3.UP * 0.9, 0.24 + 0.03 * mini(k, 5), 0.4 + 0.06 * mini(k, 5))
		k += 1
		unmark(o, "charged")
		zap_hit(o, damage)
		Game.register_hit("cast")
		if first == null:
			first = o.global_position
		last = o
	return first


## The chain to the neighbour: the nearest other foe within IMPROV_CHAIN_R takes `damage` and, for "molten" /
## "skewered", the state too (the skewered frozen in a cube). Returns where it jumped to (world), or null.
static func _chain(hero: CharacterBody3D, from: Node3D, damage: float, state: String) -> Variant:
	var best: Node3D = null
	var best_d := INF
	for o: Node3D in FOES.near(hero.get_tree(), from.global_position, IMPROV_CHAIN_R):
		var d: float = _flat(o.global_position - from.global_position).length()
		if o != from and not THROWN.flying(o) and d < best_d and not (state != "" and in_state(o, state)):
			best = o
			best_d = d
	if best == null:
		return null
	var to: Vector3 = best.global_position
	if not Game.comic_style:
		var tone: String = {"molten": "earth", "skewered": "water"}.get(state, "void")
		ELEMENTS.arc(hero.get_parent(), from.global_position + Vector3.UP, to + Vector3.UP, ELEMENTS.LOOK[tone].color)
	if damage > 0.0:
		var out := _flat(best.global_position - from.global_position)
		best.take_hit(damage, (out.normalized() if out.length() > 0.01 else Vector3.ZERO) * 3.0, 0.0, false)
		Game.register_hit("cast")
	if state == "skewered":
		encase(best)
	if state != "":
		mark(best, state)
	return to
