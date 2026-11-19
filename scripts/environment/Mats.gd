class_name Mats
extends RefCounted
## Shared, cached material library. Every scene builder pulls materials from here
## so identical surfaces share one Material resource (fewer state changes,
## smaller memory footprint on mobile/web).

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const GRASS_SHADER := preload("res://assets/shaders/grass.gdshader")
const PIPE_SHADER := preload("res://assets/shaders/pipe_flow.gdshader")
const SCREEN_SHADER := preload("res://assets/shaders/screen.gdshader")

static var _cache: Dictionary = {}


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = _create(key)
	_cache[key] = m
	return m


static func std(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := std(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func noise_tex(freq: float, seed_v: int, low: Color, high: Color, size: int = 256) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.seed = seed_v
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, low)
	g.set_color(1, high)
	t.color_ramp = g
	return t


static func _textured(color: Color, roughness: float, metallic: float, tex: Texture2D, scale: float) -> StandardMaterial3D:
	var m := std(color, roughness, metallic)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


static func _create(key: String) -> Material:
	match key:
		"terrain":
			var sm := ShaderMaterial.new()
			sm.shader = TERRAIN_SHADER
			sm.set_shader_parameter("noise_tex", noise_tex(0.02, 7, Color(0.35, 0.35, 0.35), Color.WHITE))
			return sm
		"grass":
			var g := ShaderMaterial.new()
			g.shader = GRASS_SHADER
			return g
		"pipe":
			var p := ShaderMaterial.new()
			p.shader = PIPE_SHADER
			return p
		"screen":
			var s := ShaderMaterial.new()
			s.shader = SCREEN_SHADER
			return s
		"gravel":
			return _textured(Color(0.62, 0.58, 0.52), 0.95, 0.0, noise_tex(0.25, 3, Color(0.6, 0.6, 0.6), Color.WHITE), 0.6)
		"soil":
			return _textured(Color(0.30, 0.20, 0.13), 0.97, 0.0, noise_tex(0.08, 11, Color(0.5, 0.5, 0.5), Color.WHITE), 0.4)
		"soil_wet":
			return _textured(Color(0.17, 0.11, 0.07), 0.55, 0.0, noise_tex(0.08, 11, Color(0.5, 0.5, 0.5), Color.WHITE), 0.4)
		"concrete":
			return _textured(Color(0.70, 0.70, 0.68), 0.85, 0.0, noise_tex(0.05, 5, Color(0.8, 0.8, 0.8), Color.WHITE), 0.2)
		"wood":
			var w := _textured(Color(0.58, 0.40, 0.24), 0.8, 0.0, noise_tex(0.15, 21, Color(0.7, 0.7, 0.7), Color.WHITE, 128), 0.6)
			w.uv1_scale = Vector3(0.25, 3.0, 0.25)
			return w
		"wood_dark":
			return _textured(Color(0.33, 0.22, 0.14), 0.85, 0.0, noise_tex(0.15, 22, Color(0.7, 0.7, 0.7), Color.WHITE, 128), 0.6)
		"wood_painted":
			return std(Color(0.86, 0.84, 0.78), 0.7)
		"siding":
			return _textured(Color(0.36, 0.47, 0.42), 0.75, 0.0, noise_tex(0.4, 9, Color(0.85, 0.85, 0.85), Color.WHITE, 128), 0.5)
		"roof":
			return std(Color(0.22, 0.24, 0.27), 0.55, 0.45)
		"metal":
			return std(Color(0.78, 0.80, 0.82), 0.28, 0.85)
		"metal_dark":
			return std(Color(0.22, 0.23, 0.25), 0.4, 0.7)
		"frame":
			return std(Color(0.92, 0.93, 0.94), 0.3, 0.6)
		"glass":
			var gl := StandardMaterial3D.new()
			gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gl.albedo_color = Color(0.78, 0.92, 0.95, 0.16)
			gl.roughness = 0.04
			gl.metallic = 0.15
			gl.metallic_specular = 0.9
			gl.cull_mode = BaseMaterial3D.CULL_DISABLED
			return gl
		"window":
			var wi := std(Color(0.30, 0.45, 0.55), 0.08, 0.6)
			return wi
		"plastic_white":
			return std(Color(0.94, 0.95, 0.96), 0.35)
		"plastic_dark":
			return std(Color(0.12, 0.13, 0.15), 0.45)
		"plastic_blue":
			return std(Color(0.10, 0.45, 0.85), 0.4)
		"plastic_green":
			return std(Color(0.18, 0.55, 0.30), 0.5)
		"rubber":
			return std(Color(0.06, 0.06, 0.07), 0.9)
		"tank":
			return std(Color(0.18, 0.42, 0.62), 0.45, 0.1)
		"leaf":
			return _textured(Color(0.30, 0.58, 0.18), 0.7, 0.0, noise_tex(0.3, 31, Color(0.75, 0.75, 0.75), Color.WHITE, 128), 1.2)
		"leaf_dark":
			return _textured(Color(0.13, 0.36, 0.12), 0.75, 0.0, noise_tex(0.3, 32, Color(0.75, 0.75, 0.75), Color.WHITE, 128), 1.2)
		"lettuce":
			return std(Color(0.55, 0.80, 0.30), 0.6)
		"foliage":
			return _textured(Color(0.20, 0.42, 0.15), 0.85, 0.0, noise_tex(0.25, 33, Color(0.65, 0.65, 0.65), Color.WHITE, 128), 0.5)
		"foliage_light":
			return _textured(Color(0.38, 0.55, 0.18), 0.85, 0.0, noise_tex(0.25, 34, Color(0.65, 0.65, 0.65), Color.WHITE, 128), 0.5)
		"bark":
			return _textured(Color(0.32, 0.23, 0.16), 0.95, 0.0, noise_tex(0.5, 35, Color(0.6, 0.6, 0.6), Color.WHITE, 128), 0.8)
		"stem":
			return std(Color(0.30, 0.48, 0.16), 0.8)
		"tomato":
			return std(Color(0.85, 0.12, 0.07), 0.35)
		"corn":
			return std(Color(0.42, 0.62, 0.20), 0.75)
		"corn_cob":
			return std(Color(0.92, 0.78, 0.30), 0.6)
		"rock":
			return _textured(Color(0.50, 0.49, 0.46), 0.9, 0.0, noise_tex(0.2, 41, Color(0.6, 0.6, 0.6), Color.WHITE, 128), 0.5)
		"terracotta":
			return std(Color(0.72, 0.36, 0.22), 0.8)
		"flower_yellow":
			return std(Color(0.98, 0.82, 0.18), 0.6)
		"flower_purple":
			return std(Color(0.62, 0.36, 0.86), 0.6)
		"flower_white":
			return std(Color(0.96, 0.95, 0.92), 0.6)
		"solar":
			return std(Color(0.06, 0.10, 0.22), 0.15, 0.7)
		"red":
			return std(Color(0.80, 0.12, 0.10), 0.45)
		"yellow":
			return std(Color(0.95, 0.75, 0.10), 0.5)
		"hivis":
			return std(Color(0.98, 0.55, 0.08), 0.6)
		"skin":
			return std(Color(0.80, 0.60, 0.46), 0.6)
		"denim":
			return std(Color(0.16, 0.24, 0.40), 0.85)
		"jacket":
			return std(Color(0.16, 0.42, 0.30), 0.75)
		"shade_cloth":
			var sc := std(Color(0.3, 0.42, 0.33, 0.62), 0.95)
			sc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sc.cull_mode = BaseMaterial3D.CULL_DISABLED
			return sc
		"copper":
			return std(Color(0.72, 0.42, 0.25), 0.35, 0.9)
		"puddle":
			var pu := std(Color(0.16, 0.22, 0.27), 0.04, 0.3)
			pu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pu.albedo_color.a = 0.8
			return pu
		"smoke":
			var sm := StandardMaterial3D.new()
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			sm.vertex_color_use_as_albedo = true
			sm.albedo_color = Color(0.36, 0.36, 0.38, 0.85)
			var puff := GradientTexture2D.new()
			puff.width = 64
			puff.height = 64
			puff.fill = GradientTexture2D.FILL_RADIAL
			puff.fill_from = Vector2(0.5, 0.5)
			puff.fill_to = Vector2(1.0, 0.5)
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
			puff.gradient = g
			sm.albedo_texture = puff
			return sm
		"lamp_glow":
			return emissive(Color(1.0, 0.82, 0.55), 0.0)
		"water_drop":
			var wd := StandardMaterial3D.new()
			wd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wd.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			wd.vertex_color_use_as_albedo = true
			wd.albedo_color = Color(0.8, 0.92, 1.0, 0.8)
			return wd
		"highlight":
			var h := StandardMaterial3D.new()
			h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			h.albedo_color = Color(0.25, 0.75, 1.0, 0.55)
			return h
	push_warning("Mats: unknown material '%s'" % key)
	return std(Color.MAGENTA)
