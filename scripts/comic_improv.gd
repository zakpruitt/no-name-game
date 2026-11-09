## The element matrix's payoffs (void_element.IMPROV, docs/features/element-matrix.md): one small one-beat tell per
## cell that says WHICH two elements met, drawn from the shared designed pieces (designed_polish.improv), with its
## word (ComicFx.IMPROV_WORDS[cell], said over the move's own). The six rules (frozen, charged, molten, bound,
## airborne, buried) are tinted by the hitting element; the `state_x_element` cells are the kit upgrades'
## (void_element.IMPROV_UPGRADE). Torn Off (skewered x void) adds the void tear as it's yanked (comic_rip).
##   ComicImprov.spawn(parent, "frozen_x_void", foe, hero_spot, neighbour_or_null)
##   ComicImprov.spawn(parent, "frozen", foe, hero_spot, null, "wind")

const RIP := preload("res://scripts/comic_rip.gd")
const POLISH := preload("res://scripts/designed_polish.gd")
## The cells with a tell (void_element.improvise's improv_paid keys).
const CELLS := ["frozen_x_wind", "frozen_x_void", "buried_x_water", "buried_x_earth", "buried_x_void", "molten_x_wind",
	"molten_x_water", "molten_x_earth", "molten_x_void", "skewered_x_water", "skewered_x_void", "airborne_x_water",
	"airborne_x_earth", "bound_x_wind", "bound_x_water", "charged_x_void", "charged_x_water", "charged_x_earth",
	"charged_x_wind", "frozen", "charged", "molten", "bound", "airborne", "buried"]


## The tell for `cell` on `e`. `toward` is the hero's spot; `next` the neighbour a chain jumped to (Vector3) or null.
static func spawn(parent: Node, which: String, e: Variant, toward: Vector3, next: Variant = null, hitter := "") -> Node3D:
	if not CELLS.has(which) or not is_instance_valid(e):
		return null
	POLISH.improv(parent, which, e, toward, next, hitter)
	if which == "skewered_x_void":
		RIP.spawn(parent, e, toward)
	ComicFx.improv(which, e.global_position)
	return null
