class_name Spirits
## The spirit he holds, and what it opens in his kit (docs/features/spirits.md).
##
## A spirit carries one element. With none he has the base kit: the light string and the dark (tentacle) moves.
## Holding a spirit opens that element's enders, big moves, breakers and its crossover with dark; a crossover of
## two elements needs both, so one spirit never opens it. Closed moves stay in the game: void_route() goes past
## them the way it goes past a demoted move (KitSlots.open), so the press falls back to the grab or the string.
##
## `--spirit=all` (and every `-s` test and the autotest, so the checks play the whole kit) opens everything;
## `--spirit=storm|ice|magma` starts him holding one; `--spirit=none` is play's default.

## The spirits there are, by the code's element word (hero_moves.ELEMENT_WORDS has the names shown).
const ELEMENTS := ["wind", "water", "earth"]
const FLAG := "--spirit="
## Route steps into a two-element crossover that their own element alone doesn't describe.
const EXTRA := {"XR": ["wind", "earth"]}  # Air Slash's hammer, on the way to Fault Line (storm x magma)

static var held := ""  # "wind" / "water" / "earth", or "" for none
static var _all := true
static var _parsed := false
static var _element_of := {}  # void_element.ELEMENT_OF, loaded on first use (a preload here compiles it before the autoloads exist in a -s test)


## Whether the kit is cut down to what the held spirit opens (false: everything plays).
static func gated() -> bool:
	if not _parsed:
		_parse()
	return not _all


## Tests: `all` true opens everything, false gates by `held`.
static func set_all(all: bool) -> void:
	_parsed = true
	_all = all


## Take `element`'s spirit (the one held before goes back to its spot); "" lets it go.
static func claim(element: String) -> void:
	held = element


## Can he start move `id` with the spirit he holds?
static func allows(id: String) -> bool:
	if not gated():
		return true
	for el: String in needs(id):
		if el != "void" and el != held:
			return false
	return true


## The elements a move needs: a crossover's pair, else the move's own.
static func needs(id: String) -> Array:
	var s := KitSlots.slot_of(id)
	if s != "" and KitSlots.slot(s).has("pair"):
		return KitSlots.slot(s).pair
	if EXTRA.has(id):
		return EXTRA[id]
	if _element_of.is_empty():
		_element_of = load("res://scripts/void_element.gd").ELEMENT_OF
	var el: String = _element_of.get(id, "")
	return [el] if el != "" else []


static func _parse() -> void:
	_parsed = true
	var user := OS.get_cmdline_user_args()
	var engine := OS.get_cmdline_args()
	_all = "--autotest" in user or "-s" in engine or "--script" in engine
	for a in user:
		if not a.begins_with(FLAG):
			continue
		var v := a.trim_prefix(FLAG)
		var words: Dictionary = load("res://scripts/hero_moves.gd").ELEMENT_WORDS
		_all = v == "all"
		for el: String in ELEMENTS:
			if words[el] == v:
				held = el
