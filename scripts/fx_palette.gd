extends RefCounted
## One palette per element for the flat comic effects (comic_pop, comic_bolt, comic_gale, comic_geyser,
## comic_fist, comic_comet, comic_crack, dark_fx, frost_spear), so a string reads as one designed set
## rather than a pile of colours (Zak, round 33: "sleeker and more put together ... very thick colours").
## Each element has five tones, darkest to lightest: ink (the line, a near-black of the element), deep
## (shadow tone), body (the flat colour), light (the rim / edge light) and hot (the core, near white).
## The sleek rules every drawer follows:
##   - Lines are thin: LINE m of ink round a shape, not a hull 1.2-2x its size.
##   - Fills are not opaque slabs: the body fades out toward its edges (EDGE_ALPHA) or its tail, and the
##     light tone is a rim along the leading edge, not a second filled shape.
##   - One hot core per hit, small.
## Words and damage numbers keep their hot red-yellow (an element colour sinks into its own effect).
##   const PAL := preload("res://scripts/fx_palette.gd")
##   var p: Dictionary = PAL.of("wind"); p.body, p.ink ...

const LINE := 0.035  # m: the ink line round a flat effect (about 2 px at the game camera)
const EDGE_ALPHA := 0.55  # a fill's alpha at its outer edge (its middle is opaque)
const TAIL_ALPHA := 0.0  # a stroke's or ribbon's alpha at its tail

const ELEMENTS := {
	"wind": {"ink": Color(0.02, 0.07, 0.05), "deep": Color(0.04, 0.42, 0.26), "body": Color(0.18, 0.86, 0.46),
		"light": Color(0.82, 1.0, 0.76), "hot": Color(1.0, 1.0, 0.9)},
	"water": {"ink": Color(0.02, 0.04, 0.12), "deep": Color(0.12, 0.36, 0.78), "body": Color(0.42, 0.78, 1.0),
		"light": Color(0.88, 0.97, 1.0), "hot": Color(1.0, 1.0, 1.0)},
	"earth": {"ink": Color(0.09, 0.02, 0.02), "deep": Color(0.62, 0.12, 0.02), "body": Color(1.0, 0.38, 0.05),
		"light": Color(1.0, 0.76, 0.28), "hot": Color(1.0, 0.95, 0.72)},
	"void": {"ink": Color(0.03, 0.01, 0.06), "deep": Color(0.3, 0.1, 0.56), "body": Color(0.62, 0.3, 1.0),
		"light": Color(1.0, 0.52, 0.95), "hot": Color(1.0, 0.86, 1.0)},
	"spirit": {"ink": Color(0.01, 0.05, 0.06), "deep": Color(0.05, 0.42, 0.44), "body": Color(0.28, 0.92, 0.84),
		"light": Color(0.84, 1.0, 0.95), "hot": Color(1.0, 1.0, 0.92)},
	## The neutral hit (no element): hot orange to a near-white core.
	"hit": {"ink": Color(0.06, 0.02, 0.02), "deep": Color(0.85, 0.22, 0.03), "body": Color(1.0, 0.5, 0.08),
		"light": Color(1.0, 0.86, 0.32), "hot": Color(1.0, 0.97, 0.82)},
	## Awakening's gold.
	"gold": {"ink": Color(0.08, 0.04, 0.01), "deep": Color(0.82, 0.48, 0.08), "body": Color(1.0, 0.78, 0.3),
		"light": Color(1.0, 0.93, 0.66), "hot": Color(1.0, 1.0, 0.9)},
}
## Names other code uses for the same element.
const ALIAS := {"storm": "wind", "ice": "water", "frost": "water", "magma": "earth", "lava": "earth",
	"dark": "void"}


static func of(element: String) -> Dictionary:
	var e: String = ALIAS.get(element, element)
	return ELEMENTS.get(e, ELEMENTS.hit)


## `c` at alpha `a` (times its own).
static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## The element whose body tone is nearest `c` (for callers that only pass a colour).
static func nearest(c: Color) -> String:
	var best := "hit"
	var best_d := INF
	for k: String in ELEMENTS:
		var b: Color = ELEMENTS[k].body
		var d := Vector3(b.r - c.r, b.g - c.g, b.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = k
	return best
