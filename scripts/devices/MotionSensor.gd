class_name MotionSensor
extends VirtualDevice
## Outdoor PIR motion sensor on the shed corner (SmartThings "motion sensor"
## capability). It really detects the player: anyone inside its range and
## field of view triggers it, and it stays "active" for a hold time after
## the last movement, like real PIR sensors.

const HOLD_TIME := 8.0

@export var detect_range := 8.0
@export var fov_degrees := 120.0
@export var head_offset := Vector3(0, 2.4, 0)
@export var facing := Vector3(0.6, 0, -0.8)  ## local look direction (XZ)

var motion := false
var last_motion_time := "-"
var events := 0
var last_source := "-"
var battery := 78.0
var _since := INF
var _player_cache: Node3D
var _lens_mat: StandardMaterial3D


func _init() -> void:
	super()
	device_name = "Yard Motion Sensor"
	device_type = "Outdoor Motion Sensor"
	category = "Security"


func is_sensor() -> bool:
	return true


func get_status_color() -> Color:
	if online and motion:
		return COLOR_ACTIVE
	return super()


## Scenario hook: something moved in front of the sensor (fox, intruder...).
func simulate_motion(source := "Simulated intruder") -> void:
	_on_detect(source)


func _find_player() -> Node3D:
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	return _player_cache


func sees(world_pos: Vector3) -> bool:
	var head := global_transform * head_offset
	var to := world_pos + Vector3(0, 1.0, 0) - head
	if to.length() > detect_range:
		return false
	var fwd := (global_transform.basis * facing).normalized()
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.5:
		return true
	return fwd.dot(flat.normalized()) >= cos(deg_to_rad(fov_degrees * 0.5))


func simulate(dt: float) -> void:
	_since += dt
	var p := _find_player()
	if p and sees(p.global_position):
		var moving := p is CharacterBody3D and (p as CharacterBody3D).velocity.length() > 0.3
		if moving:
			_on_detect("Person (you)")
	if motion and _since >= HOLD_TIME:
		motion = false
		_refresh()


func _on_detect(source: String) -> void:
	_since = 0.0
	last_source = source
	if not motion:
		motion = true
		events += 1
		last_motion_time = EnvironmentManager.format_time()
		_refresh()


func _status_online() -> String:
	return "Motion" if motion else "No motion"


func get_primary_reading() -> String:
	return "MOTION DETECTED" if motion else "Clear"


func get_readings() -> Array:
	return [
		["Motion", "Detected" if motion else "Clear"],
		["Last motion", last_motion_time],
		["Detected", last_source],
		["Events", str(events)],
		["Coverage", "%d m · %d°" % [int(detect_range), int(fov_degrees)]],
		["Battery", "%d %%" % int(battery)],
	]


func get_extra_controls() -> Array:
	return [{"id": "test", "label": "Simulate movement", "kind": "button", "enabled": true}]


func _perform_extra(id: String, _value: Variant) -> void:
	if id == "test":
		simulate_motion()


func _build_model() -> void:
	var h := head_offset
	var yaw := atan2(facing.x, facing.z)
	var mount := Node3D.new()
	mount.position = h
	mount.rotation.y = yaw
	add_child(mount)
	ProcMesh.box(mount, Vector3(0.1, 0.12, 0.05), Vector3(0, 0, -0.02), Mats.get_mat("plastic_white"))
	ProcMesh.box(mount, Vector3(0.09, 0.14, 0.08), Vector3(0, -0.02, 0.045), Mats.get_mat("plastic_white"), Vector3(-15, 0, 0))
	_lens_mat = Mats.std(Color(0.9, 0.92, 0.95), 0.15)
	_lens_mat.emission_enabled = true
	_lens_mat.emission = Color(1, 0.2, 0.15)
	_lens_mat.emission_energy_multiplier = 0.0
	ProcMesh.sphere(mount, 0.04, Vector3(0, -0.03, 0.085), _lens_mat, Vector3(1, 1, 0.7), 10, false)
	_make_led(mount, Vector3(0.03, 0.035, 0.087), 0.008)


func _update_visuals() -> void:
	if _lens_mat:
		_lens_mat.emission_energy_multiplier = 1.5 if motion else 0.0
