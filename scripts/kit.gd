## The kit grammar's upgrade gate (docs/characters/kit-grammar.md).
##
## A character's base kit is the fixed slot table. Moves and matrix cells outside it are "upgrades": still in the
## game, off by default, on with `--kit=full` (everything) or `--kit=<id>,<id>` (named ones), later from runs.
## Ask `Kit.has("storm_pitch")` at the routing or payoff site; never remove the code behind a gate.
class_name Kit

## Every upgrade id a lane gates, with the doc line that explains it. Add here when you gate something.
const UPGRADES := {
	"storm_pitch": "Tow Line hurls the bunch (Dash H L); demoted from the base kit",
	"rockslide_payoff": "Rockslide's own buried payoff (L H L L); the step stays as Fault Line's route",
	"overload": "charged x storm cell beyond the shared charged rule",
	"superconduct": "charged x ice cell",
	"arc_flash": "charged x magma cell (the throw)",
	"conduct": "charged x dark cell",
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
