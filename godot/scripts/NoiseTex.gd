class_name NoiseTex
extends RefCounted
## One seamless, mipmapped noise texture shared by the terrain, layer and water shaders (round 6). Replaces the
## per-fragment hash noise those shaders computed (16-24 hash evaluations per fragment): a texture fetch is
## cheaper and, being mipmapped, filters correctly at a distance instead of aliasing. Two octaves of simplex
## noise, values 0..1; a shader scales world metres to tiles (feature size is about a tenth of a tile).

static var _tex: ImageTexture


static func get_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := FastNoiseLite.new()
	n.seed = 7
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 2
	n.fractal_gain = 0.45
	n.frequency = 0.02
	var img: Image = n.get_seamless_image(512, 512, false, false, 0.1, true)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
