class_name SecurityCamera
extends VirtualDevice
## Outdoor Wi-Fi security camera on the shed corner (SmartThings "video
## camera" + "motion" capabilities). It renders a real live feed through a
## SubViewport that only updates while someone is watching it in the device
## panel, so it costs nothing the rest of the time. It records a clip
## whenever the yard motion sensor fires. Night vision kicks in after dark.

@export var head_position := Vector3(0, 2.6, 0)
@export var aim_offset := Vector3(5.5, -2.0, -4.0)   ## local point the camera looks at
@export var motion_sensor_id := "motion_sensor"
@export var feed_size := Vector2i(480, 270)

var recording := false
var clips := 0
var _viewport: SubViewport
var _cam: Camera3D
var _rec_mat: StandardMaterial3D
var _ir_mat: StandardMaterial3D
var _preview_on := false
var _env_day: Environment
var _env_night: Environment


func _init() -> void:
	super()
	device_name = "Yard Security Camera"
	device_type = "Outdoor Wi-Fi Camera (1080p)"
	category = "Security"


func is_controllable() -> bool:
	return true


func is_running() -> bool:
	return power_on


func get_power_label() -> String:
	return "Camera"


func get_power_action_text(on: bool) -> String:
	return "Enable" if on else "Disable"


func is_night_vision() -> bool:
	return EnvironmentManager.get_ambient_light() < 0.3


func simulate(_dt: float) -> void:
	var ms := DeviceManager.get_device(motion_sensor_id) as MotionSensor
	var want := power_on and ms != null and ms.motion
	if want != recording:
		recording = want
		if want:
			clips += 1
		_refresh()
	if _preview_on:
		_apply_night_vision()


func _status_online() -> String:
	if not power_on:
		return "Disabled"
	return "Recording" if recording else "Live"


func get_status_color() -> Color:
	if online and recording:
		return COLOR_ALERT
	return super()


func get_primary_reading() -> String:
	if not power_on:
		return "DISABLED"
	return "REC - motion" if recording else ("LIVE - night vision" if is_night_vision() else "LIVE")


func get_readings() -> Array:
	return [
		["Camera", "Recording (motion)" if recording else ("Live" if power_on else "Disabled")],
		["Night vision", ("On (IR)" if is_night_vision() else "Off") if power_on else "-"],
		["Clips saved", str(clips)],
		["Stream", "%dx%d preview · 1080p record" % [feed_size.x, feed_size.y]],
		["Storage", "Cloud (simulated)"],
	]


func get_preview_texture() -> Texture2D:
	if _viewport == null or not power_on or not online:
		return null
	return _viewport.get_texture()


func set_preview_active(on: bool) -> void:
	_preview_on = on
	if _viewport == null:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_aim()
		_apply_night_vision()


func _build_model() -> void:
	var white := Mats.get_mat("plastic_white")
	var h := head_position
	# wall bracket
	ProcMesh.box(self, Vector3(0.1, 0.14, 0.04), h + Vector3(0, 0, 0.0), white)
	var pivot := Node3D.new()
	pivot.position = h + Vector3(0, -0.02, -0.02)
	add_child(pivot)
	pivot.basis = Basis.looking_at(aim_offset.normalized(), Vector3.UP)
	ProcMesh.cyl(pivot, 0.02, 0.02, 0.1, Vector3(0, 0, 0.05), white, Vector3(90, 0, 0), 8, false)
	ProcMesh.box(pivot, Vector3(0.11, 0.1, 0.22), Vector3(0, 0, -0.1), white)
	ProcMesh.box(pivot, Vector3(0.13, 0.015, 0.26), Vector3(0, 0.058, -0.11), white, Vector3.ZERO, false)
	ProcMesh.cyl(pivot, 0.035, 0.035, 0.02, Vector3(0, 0, -0.215), Mats.get_mat("plastic_dark"), Vector3(90, 0, 0), 14, false)
	ProcMesh.cyl(pivot, 0.02, 0.02, 0.01, Vector3(0, 0, -0.228), Mats.std(Color(0.05, 0.08, 0.15), 0.05, 0.5), Vector3(90, 0, 0), 12, false)
	_ir_mat = Mats.emissive(Color(0.8, 0.1, 0.1), 0.0)
	for a in 6:
		var ang := a * TAU / 6.0
		ProcMesh.sphere(pivot, 0.006, Vector3(cos(ang) * 0.045, sin(ang) * 0.045, -0.222), _ir_mat, Vector3.ONE, 4, false)
	_rec_mat = Mats.emissive(Color(1.0, 0.15, 0.1), 0.0)
	ProcMesh.sphere(pivot, 0.008, Vector3(0.04, 0.035, -0.212), _rec_mat, Vector3.ONE, 6, false)
	_make_led(self, h + Vector3(0.03, 0.05, -0.022), 0.008)
	# feed
	_viewport = SubViewport.new()
	_viewport.size = feed_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.fov = 78.0
	_cam.far = 120.0
	_viewport.add_child(_cam)
	_cam.set_meta("pivot", pivot)


func _aim() -> void:
	var pivot: Node3D = _cam.get_meta("pivot")
	if pivot and pivot.is_inside_tree():
		var xf := pivot.global_transform
		_cam.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin + xf.basis * Vector3(0, 0, -0.25))


func _apply_night_vision() -> void:
	if _cam == null or not is_inside_tree():
		return
	var world_env := get_viewport().find_world_3d().environment if get_viewport() and get_viewport().find_world_3d() else null
	if world_env == null:
		return
	if _env_day == null or _env_day != world_env:
		_env_day = world_env
		_env_night = world_env.duplicate() as Environment
		_env_night.adjustment_enabled = true
		_env_night.adjustment_saturation = 0.0
		_env_night.adjustment_brightness = 1.6
		_env_night.adjustment_contrast = 1.1
		_env_night.ambient_light_energy = world_env.ambient_light_energy * 2.5
	_cam.environment = _env_night if is_night_vision() else null


func _update_visuals() -> void:
	if _rec_mat:
		_rec_mat.emission_energy_multiplier = 4.0 if recording and online else 0.0
		_ir_mat.emission_energy_multiplier = 1.2 if power_on and is_night_vision() else 0.0
