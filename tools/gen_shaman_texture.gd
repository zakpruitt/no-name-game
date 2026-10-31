extends SceneTree
## Recolours the KayKit Barbarian's palette texture into the shaman's
## (assets/hero/shaman_texture.png, used by scripts/hero_look.gd). The texture
## is an 8x4 grid of 128x256px swatches; each mesh part samples one swatch, so
## recolouring a swatch recolours that part. Shading inside a swatch is kept
## (each pixel keeps its brightness relative to the swatch's average).
## Edit RECOLOR and rerun:
##   godot --headless --path . -s tools/gen_shaman_texture.gd
##   godot --headless --import --path .

const SRC := "res://assets/kaykit/characters/Barbarian_barbarian_texture.png"
const OUT := "res://assets/hero/shaman_texture.png"
const SWATCH_W := 128
const SWATCH_H := 256
# "col,row": target colour. Which parts use each swatch (from the mesh UVs):
#   7,0 hat pelt, cape, body fur   2,1 white fur trims, hat teeth
#   0,1 shirt   1,1 sleeves   6,0 straps, bracers, gloves   7,1 trousers
#   1,0 beard   0,0 skin      3,2 boots   2,2 axe handles   5,1 axe wraps
const RECOLOR := {
	"7,0": Color(0.4, 0.43, 0.48),  # grey wolf pelt
	"0,1": Color(0.1, 0.42, 0.42),  # deep teal shirt
	"1,1": Color(0.13, 0.33, 0.36),  # darker teal sleeves
	"6,0": Color(0.38, 0.24, 0.16),  # dark leather
	"7,1": Color(0.24, 0.23, 0.28),  # charcoal trousers
	"1,0": Color(0.24, 0.18, 0.15),  # dark braided beard
	"2,2": Color(0.32, 0.22, 0.15),  # wooden axe handles
	"5,1": Color(0.25, 0.78, 0.72),  # turquoise axe wraps
}


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	for key: String in RECOLOR:
		var cx := key.get_slice(",", 0).to_int() * SWATCH_W
		var cy := key.get_slice(",", 1).to_int() * SWATCH_H
		var mean := 0.0
		for y in SWATCH_H:
			for x in SWATCH_W:
				mean += img.get_pixel(cx + x, cy + y).get_luminance()
		mean = maxf(mean / (SWATCH_W * SWATCH_H), 0.01)
		var target: Color = RECOLOR[key]
		for y in SWATCH_H:
			for x in SWATCH_W:
				var k := clampf(img.get_pixel(cx + x, cy + y).get_luminance() / mean, 0.0, 2.5)
				img.set_pixel(cx + x, cy + y, Color(minf(target.r * k, 1.0), minf(target.g * k, 1.0), minf(target.b * k, 1.0)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("[shaman] wrote ", OUT)
	quit()
