## The kit grammar's upgrade gate (docs/characters/kit-grammar.md).
##
## A character's base kit is the fixed slot table. Moves and matrix cells outside it are "upgrades": still in the
## game, off by default, on with `--kit=full` (everything) or `--kit=<id>,<id>` (named ones), later from runs.
## Ask `Kit.has("storm_pitch")` at the routing or payoff site; never remove the code behind a gate.
class_name Kit

## Every upgrade id a lane gates, with the doc line that explains it. Add here when you gate something.
const UPGRADES := {
	"storm_pitch": "Tow Line hurls the bunch (Dash H L); demoted from the base kit",
	"overload": "charged x storm cell beyond the shared charged rule",
	"superconduct": "charged x ice cell",
	"arc_flash": "charged x magma cell (the throw)",
	"conduct": "charged x dark cell",
	# The element matrix's other cells (round 49, matrix collapse): each is richer than its state's one shared rule
	# (void_element.RULES); off, the rule plays.
	"gale_lift": "frozen x storm cell: the gale takes the cube up, still in its ice (rule: shatter)",
	"shard_cut": "frozen x dark cell: the shatter's shards cut the foe beside it (rule: shatter)",
	"frozen_in": "buried x ice cell: frozen where it is stuck in the floor (rule: crater)",
	"swallowed": "buried x dark cell: dragged under and held a moment (rule: crater)",
	"firestorm": "molten x storm cell: launched, the flames catch the one beside it (rule: burst)",
	"quench": "molten x ice cell: a steam burst x1.6 and up (rule: burst)",
	"flare_up": "molten x magma cell: the floor erupts under it (own element: the move's own)",
	"smother": "molten x dark cell: driven into the floor x1.5 (rule: burst)",
	"ice_spreads": "skewered x ice cell: the spear's ice climbs onto the nearest foe and skewers it (own element: nothing)",
	"torn_off": "skewered x dark cell: ripped off the spear towards him (rule: frozen's shatter)",
	"freeze_aloft": "airborne x ice cell: frozen up there, comes down a cube (rule: juggle)",
	"meteor_spike": "airborne x magma cell: driven down into a crater x1.5 (rule: juggle)",
	"torn_loose": "bound x storm cell: torn out of the bind and launched (rule: snap)",
	"frozen_dark": "bound x ice cell: frozen where the tendrils hold it (rule: snap)",
}

static var _on := {}
static var _all := false
static var _parsed := false


static func has(id: String) -> bool:
	if not _parsed:
		_parse()
	assert(UPGRADES.has(id), "unknown kit upgrade: " + id)
	return _all or _on.has(id)


## Tests and menus may turn an upgrade on or off at runtime.
static func set_on(id: String, on: bool) -> void:
	if not _parsed:
		_parse()
	if on:
		_on[id] = true
	else:
		_on.erase(id)


static func _parse() -> void:
	_parsed = true
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not a.begins_with("--kit="):
			continue
		for id in a.trim_prefix("--kit=").split(","):
			if id == "full":
				_all = true
			elif UPGRADES.has(id):
				_on[id] = true
