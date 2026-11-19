extends Node
## Persistent user settings and graphics quality presets (Low / Medium / High).
## Visual systems listen to `quality_changed` and read `q(...)` for parameters.

signal quality_changed(preset: String)
signal settings_changed

const SAVE_PATH := "user://settings.cfg"
const PRESETS := ["low", "medium", "high"]

const QUALITY := {
	"high": {
		"shadows": true, "shadow_size": 4096, "shadow_distance": 70.0, "msaa": Viewport.MSAA_4X,
		"render_scale": 1.0, "glow": true, "fog": true, "grass_density": 1.0, "detail_density": 1.0,
		"particles": 1.0, "greenhouse_lights": 4, "lamp_lights": true, "radiance": Sky.RADIANCE_SIZE_128,
	},
	"medium": {
		"shadows": true, "shadow_size": 2048, "shadow_distance": 45.0, "msaa": Viewport.MSAA_2X,
		"render_scale": 1.0, "glow": true, "fog": true, "grass_density": 0.6, "detail_density": 0.75,
		"particles": 0.6, "greenhouse_lights": 2, "lamp_lights": false, "radiance": Sky.RADIANCE_SIZE_64,
	},
	"low": {
		"shadows": false, "shadow_size": 1024, "shadow_distance": 30.0, "msaa": Viewport.MSAA_DISABLED,
		"render_scale": 0.75, "glow": false, "fog": true, "grass_density": 0.3, "detail_density": 0.5,
		"particles": 0.35, "greenhouse_lights": 0, "lamp_lights": false, "radiance": Sky.RADIANCE_SIZE_32,
	},
}

var quality := "high"
var mouse_sensitivity := 1.0
var touch_sensitivity := 1.0
var invert_y := false
var master_volume := 0.8
var touch_mode := "auto"  ## auto / on / off
var tutorial_seen := false
var show_fps := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality = default_quality()
	_load()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--quality="):
			var qv := a.substr(10)
			if qv in PRESETS:
				quality = qv
		if a == "--skip-tutorial":
			tutorial_seen = true
	_apply_audio()
	PlatformManager.set_touch_override(touch_mode)


func default_quality() -> String:
	match PlatformManager.kind:
		PlatformManager.Kind.MOBILE:
			return "low"
		PlatformManager.Kind.WEB:
			return "low" if PlatformManager.is_mobile_device else "medium"
	return "high"


func q(key: String) -> Variant:
	return QUALITY[quality][key]


func set_quality(preset: String) -> void:
	if not preset in PRESETS or preset == quality:
		return
	quality = preset
	apply_viewport(get_tree().root)
	quality_changed.emit(quality)
	save()


func apply_viewport(vp: Viewport) -> void:
	vp.msaa_3d = q("msaa")
	vp.scaling_3d_scale = q("render_scale")
	RenderingServer.directional_shadow_atlas_set_size(q("shadow_size"), true)


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	if key == "master_volume":
		_apply_audio()
	if key == "touch_mode":
		PlatformManager.set_touch_override(touch_mode)
	settings_changed.emit()
	save()


func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)


func save() -> void:
	var cf := ConfigFile.new()
	for k: String in ["quality", "mouse_sensitivity", "touch_sensitivity", "invert_y", "master_volume", "touch_mode", "tutorial_seen", "show_fps"]:
		cf.set_value("settings", k, get(k))
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in cf.get_section_keys("settings"):
		if k in ["quality", "mouse_sensitivity", "touch_sensitivity", "invert_y", "master_volume", "touch_mode", "tutorial_seen", "show_fps"]:
			set(k, cf.get_value("settings", k))
	if not quality in PRESETS:
		quality = default_quality()
