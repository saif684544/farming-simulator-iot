extends Node
## Owns the WorldEnvironment, sky and sun/moon light and maps the simulated
## time of day (EnvironmentManager) onto them. Sky uniforms are throttled to
## avoid re-baking sky radiance every frame on mobile/web.

const SKY_SHADER := preload("res://assets/shaders/sky.gdshader")

const NIGHT := {"top": Color(0.01, 0.02, 0.06), "horizon": Color(0.05, 0.07, 0.14), "ground": Color(0.02, 0.025, 0.03)}
const SUNSET := {"top": Color(0.20, 0.28, 0.55), "horizon": Color(0.98, 0.58, 0.32), "ground": Color(0.22, 0.17, 0.14)}
const DAY := {"top": Color(0.17, 0.40, 0.80), "horizon": Color(0.66, 0.80, 0.94), "ground": Color(0.30, 0.32, 0.30)}

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var world_env: WorldEnvironment
var _last_sky_time := -100.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_fade_start = 0.85
	add_child(sun)

	EnvironmentManager.time_changed.connect(func(_t: float) -> void: update_lighting(false))
	GameSettings.quality_changed.connect(func(_p: String) -> void: _apply_quality())
	_apply_quality()
	update_lighting(true)


func _apply_quality() -> void:
	sun.shadow_enabled = GameSettings.q("shadows")
	sun.directional_shadow_max_distance = GameSettings.q("shadow_distance")
	env.glow_enabled = GameSettings.q("glow")
	env.fog_enabled = GameSettings.q("fog")
	env.sky.radiance_size = GameSettings.q("radiance")
	GameSettings.apply_viewport(get_viewport())


## Direction from the ground towards the sun (east -> overhead (tilted south) -> west).
func sun_direction(t: float) -> Vector3:
	var a := (t - 6.0) / 12.0 * PI
	return Vector3(cos(a), sin(a) * 0.86, sin(a) * 0.42 + 0.12).normalized()


func update_lighting(force: bool) -> void:
	var t := EnvironmentManager.time_of_day
	var s := sun_direction(t)
	var h := s.y
	var light_dir := s
	var energy := 0.0
	var color := Color.WHITE
	if h > -0.02:
		energy = 0.05 + 1.35 * smoothstep(-0.02, 0.35, h)
		color = Color(1.0, 0.55, 0.30).lerp(Color(1.0, 0.95, 0.88), smoothstep(0.0, 0.45, h))
	else:
		light_dir = -s
		energy = 0.22 * smoothstep(0.02, 0.3, -h)
		color = Color(0.55, 0.65, 1.0)
	var up := Vector3.UP if absf(light_dir.y) < 0.98 else Vector3.FORWARD
	sun.transform = Transform3D(Basis.looking_at(-light_dir, up), Vector3.ZERO)
	sun.light_energy = energy
	sun.light_color = color
	sun.shadow_opacity = clampf(energy * 1.4, 0.0, 1.0)

	if not force and absf(t - _last_sky_time) < 0.05 and absf(t - _last_sky_time) < 23.0:
		return
	_last_sky_time = t
	var c: Dictionary
	if h < 0.0:
		c = _blend(NIGHT, SUNSET, smoothstep(-0.3, 0.0, h))
	else:
		c = _blend(SUNSET, DAY, smoothstep(0.0, 0.35, h))
	sky_mat.set_shader_parameter("top_color", c.top)
	sky_mat.set_shader_parameter("horizon_color", c.horizon)
	sky_mat.set_shader_parameter("ground_color", c.ground)
	sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.9, 0.7) if h > -0.02 else Color(0.8, 0.85, 1.0))
	sky_mat.set_shader_parameter("sun_size", 0.9994 if h > -0.02 else 0.9997)
	sky_mat.set_shader_parameter("star_intensity", (1.0 - smoothstep(-0.25, -0.02, h)) * 1.3)
	var day := smoothstep(-0.15, 0.3, h)
	env.ambient_light_energy = lerpf(0.35, 1.0, day)
	env.background_energy_multiplier = lerpf(0.6, 1.0, day)
	env.fog_light_color = c.horizon
	env.tonemap_exposure = lerpf(1.25, 1.0, day)


func _blend(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	return {
		"top": (a.top as Color).lerp(b.top, f),
		"horizon": (a.horizon as Color).lerp(b.horizon, f),
		"ground": (a.ground as Color).lerp(b.ground, f),
	}
