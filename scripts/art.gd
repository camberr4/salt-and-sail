class_name Art
extends RefCounted
## Optional painted art. Every asset under assets/art/ is optional: when a file
## exists it replaces the procedural stand-in, when it does not the game looks
## exactly as before. Folder and file names are listed in docs/ART-PIPELINE.md.

const ROOT := "res://assets/art/"

static var _cache := {}


static func has(rel: String) -> bool:
	return ResourceLoader.exists(ROOT + rel + ".png")


## A plain texture (UI, sprites). Null when the file is absent.
static func tex(rel: String) -> Texture2D:
	var key := "t:" + rel
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if has(rel):
		t = load(ROOT + rel + ".png")
	_cache[key] = t
	return t


## A tileable texture with mipmaps (terrain and water), so it does not shimmer
## when minified. Null when the file is absent.
static func tiled(rel: String) -> Texture2D:
	var key := "m:" + rel
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = null
	var src := tex(rel)
	if src != null:
		var img := src.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			out = ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## Binds `rel` to `param` on a shader material and sets `flag_param` to 1/0.
static func bind(mat: ShaderMaterial, param: String, flag_param: String, rel: String, fallback: Texture2D) -> void:
	var t := tiled(rel)
	mat.set_shader_parameter(param, t if t != null else fallback)
	mat.set_shader_parameter(flag_param, 1.0 if t != null else 0.0)


static var _white: ImageTexture


static func white() -> Texture2D:
	if _white == null:
		var img := Image.create(4, 4, true, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5, 1.0))
		img.generate_mipmaps()
		_white = ImageTexture.create_from_image(img)
	return _white
