class_name LeakSensor
extends VirtualDevice
## Battery water-leak sensor on the ground under the irrigation main
## (SmartThings "water sensor" capability: wet / dry).
##
## The sensor also owns the simulated pipe fault it watches: a burst fitting
## sprays water while the main valve is open, a puddle spreads, the probe gets
## wet. Closing the valve stops the spray and the puddle slowly dries out.

const WET_ON := 0.15
const WET_OFF := 0.05

@export var leak_point := Vector3(-0.6, 0.3, 0.0)  ## local position of the faulty fitting

var leak_source := false   ## burst fitting present (until repaired)
var wetness := 0.0         ## 0..1 water on the ground around the probe
var wet := false
var leak_events := 0
var battery := 91.0
var _spray: CPUParticles3D
var _puddle: MeshInstance3D
var _audio: AudioStreamPlayer3D


func _init() -> void:
	super()
	device_name = "Water Leak Sensor"
	device_type = "Water Leak Sensor"
	category = "Water & irrigation"


func is_sensor() -> bool:
	return true


func is_alert() -> bool:
	return wet


func is_spraying() -> bool:
	return leak_source and DeviceManager.is_water_valve_open()


func start_leak() -> void:
	leak_source = true
	_update_visuals()


func repair_leak() -> void:
	leak_source = false
	_update_visuals()


func simulate(dt: float) -> void:
	var spraying := is_spraying()
	var rate := 0.35 if DeviceManager.is_irrigating() else 0.2
	wetness = clampf(wetness + (dt * rate if spraying else -dt * 0.035), 0.0, 1.0)
	var was := wet
	if not wet and wetness > WET_ON:
		wet = true
		leak_events += 1
	elif wet and wetness < WET_OFF:
		wet = false
	_update_visuals()
	if wet != was:
		_refresh()
	else:
		notify_reading()


func _status_online() -> String:
	return "LEAK DETECTED" if wet else "Dry"


func get_primary_reading() -> String:
	return "WET - leak detected" if wet else "Dry"


func get_readings() -> Array:
	return [
		["Water", "Wet - leak detected" if wet else "Dry"],
		["Puddle coverage", "%d %%" % int(wetness * 100.0)],
		["Pipe fitting", ("Spraying" if is_spraying() else "Leaking (valve closed)") if leak_source else "OK"],
		["Leaks detected", str(leak_events)],
		["Battery", "%d %%" % int(battery)],
	]


func get_extra_controls() -> Array:
	return [
		{"id": "burst", "label": "Simulate burst fitting", "kind": "button", "enabled": not leak_source},
		{"id": "repair", "label": "Repair the fitting", "kind": "button", "enabled": leak_source},
	]


func _perform_extra(id: String, _value: Variant) -> void:
	match id:
		"burst":
			start_leak()
		"repair":
			repair_leak()
	_refresh()


func _build_model() -> void:
	# flat puck sensor on the ground with probe contacts
	ProcMesh.cyl(self, 0.07, 0.075, 0.03, Vector3(0, 0.015, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 20)
	ProcMesh.cyl(self, 0.05, 0.05, 0.006, Vector3(0, 0.032, 0), Mats.get_mat("plastic_blue"), Vector3.ZERO, 20, false)
	for a in 3:
		var ang := a * TAU / 3.0
		ProcMesh.cyl(self, 0.006, 0.006, 0.01, Vector3(cos(ang) * 0.05, 0.002, sin(ang) * 0.05), Mats.get_mat("metal"), Vector3.ZERO, 6, false)
	_make_led(self, Vector3(0.0, 0.036, 0.04), 0.01)
	# marker stake so the sensor is easy to spot
	ProcMesh.cyl(self, 0.015, 0.015, 0.6, Vector3(0.2, 0.3, 0), Mats.get_mat("hivis"), Vector3.ZERO, 6)
	ProcMesh.box(self, Vector3(0.18, 0.12, 0.01), Vector3(0.2, 0.55, 0.01), Mats.get_mat("plastic_white"), Vector3.ZERO, false)
	ProcMesh.label3d(self, "LEAK", Vector3(0.2, 0.55, 0.017), 16, Color(0.1, 0.35, 0.8), false)
	# puddle + spray at the faulty fitting
	_puddle = ProcMesh.cyl(self, 1.0, 1.0, 0.004, Vector3(leak_point.x * 0.5, 0.004, leak_point.z * 0.5), Mats.get_mat("puddle"), Vector3.ZERO, 24, false)
	_puddle.visible = false
	ProcMesh.torus(self, 0.04, 0.065, leak_point, Mats.get_mat("metal_dark"), Vector3(0, 0, 90), false)
	_spray = CPUParticles3D.new()
	_spray.emitting = false
	_spray.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = Mats.get_mat("water_drop")
	_spray.mesh = q
	_spray.amount = maxi(int(70 * float(GameSettings.q("particles"))), 10)
	_spray.lifetime = 0.9
	_spray.position = leak_point
	_spray.direction = Vector3(0.3, 1, -0.5)
	_spray.spread = 25.0
	_spray.initial_velocity_min = 2.2
	_spray.initial_velocity_max = 3.4
	_spray.gravity = Vector3(0, -9.8, 0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.4
	_spray.color = Color(0.75, 0.9, 1.0, 0.85)
	_spray.cast_shadow = ProcMesh.NO_SHADOW
	add_child(_spray)
	_audio = AudioManager.make_3d_player("water", self, -8.0, 14.0)
	_audio.position = leak_point


func _update_visuals() -> void:
	if _spray == null:
		return
	var spraying := is_spraying()
	if _spray.emitting != spraying:
		_spray.emitting = spraying
		if spraying:
			_audio.play()
		else:
			_audio.stop()
	_puddle.visible = wetness > 0.01
	var r := 0.15 + wetness * 0.9
	_puddle.scale = Vector3(r, 1, r * 0.8)
