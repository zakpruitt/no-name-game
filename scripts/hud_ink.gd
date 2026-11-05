extends RefCounted
## The HUD's comic language (round 33, part 3, sleek): the combo counter, the combo guide's rows, the breaker
## prompt and the combo-name callout drawn like the effects, in a thin ink line over a see-through halftone
## fill instead of solid dark pills and fat outlines. Static helpers for a CanvasItem's _draw().
##   const HUD_INK := preload("res://scripts/hud_ink.gd")
##   HUD_INK.dots(self, rect, Color(col, 0.3), true)   # a halftone patch in a capsule, densest on the left

const INK := Color(0.04, 0.02, 0.06)
const LINE := 1.5  # px: the ink line round a panel (the 2-4 px rims and outlines read thick at 1080p)
const CELL := 6.0  # px between halftone dots
const DOT_R := 0.42  # of a cell: the biggest dot (0.5 touches)
const DOT_MIN := 0.12  # of a cell: the smallest, at the faded end
const FONT_PATH := "res://assets/fonts/Bangers-Regular.ttf"  # the words' font (comic_fx.gd)
const OUTLINE_DIV := 9  # a text's ink outline: its size / this (comic_fx words; the HUD's was / 6)

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


## The ink outline for text `size` px tall.
static func outline(size: int) -> int:
	return maxi(3, size / OUTLINE_DIV)


## Halftone dots over `r`, shrinking toward the far end (`from_left` true = biggest at the left), inset from a
## capsule's round ends when `capsule`. Drawn as LEVELS vertical bands, each one tiled rect of a two-dot tile at
## that band's dot size: one circle per dot cost 2000 extra draw calls and 8 ms of GPU a frame with the guide up.
static func dots(ci: CanvasItem, r: Rect2, color: Color, from_left := true, capsule := true) -> void:
	if color.a <= 0.01 or r.size.x <= 0.0:
		return
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var inset := r.size.y * 0.3 if capsule else 0.0
	var x0 := r.position.x + inset
	var x1 := r.end.x - inset
	var y0 := r.position.y + (2.0 if capsule else 0.0)
	var h := r.size.y - (4.0 if capsule else 0.0)
	var tile := CELL * 2.0
	var band := maxf(tile, floorf((x1 - x0) / LEVELS / tile) * tile)
	var x := x0
	while x < x1 - 1.0:
		var w := minf(band, x1 - x)
		var t := (x + w * 0.5 - x0) / maxf(x1 - x0, 1.0)
		var k := 1.0 - t if from_left else t
		ci.draw_texture_rect(_tile(roundi(k * (LEVELS - 1))), Rect2(x, y0, w, h), true, color)
		x += w


const LEVELS := 6
static var _tiles := {}


## A CELL * 2 px square tile with two white dots on a 45 degree screen, dot size `level` of LEVELS.
static func _tile(level: int) -> ImageTexture:
	if _tiles.has(level):
		return _tiles[level]
	var n := int(CELL * 2.0)
	var rad := CELL * lerpf(DOT_MIN, DOT_R, float(level) / (LEVELS - 1))
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := minf(p.distance_to(Vector2(CELL * 0.5, CELL * 0.5)), p.distance_to(Vector2(CELL * 1.5, CELL * 1.5)))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(rad + 0.5 - d, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_tiles[level] = tex
	return tex


## Halftone dots in a ring between radii `r0` and `r1` round `c`.
static func dot_ring(ci: CanvasItem, c: Vector2, r0: float, r1: float, color: Color) -> void:
	if color.a <= 0.01:
		return
	var y := -r1
	var row := 0
	while y <= r1:
		var x := -r1 + CELL * 0.5 * (row % 2)
		while x <= r1:
			var d := Vector2(x, y).length()
			if d >= r0 and d <= r1:
				var k := 1.0 - (d - r0) / maxf(r1 - r0, 1.0)  # biggest on the inside
				ci.draw_circle(c + Vector2(x, y), CELL * lerpf(DOT_MIN, DOT_R, k), color)
			x += CELL
		y += CELL
		row += 1
