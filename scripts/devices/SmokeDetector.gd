class_name SmokeDetector
extends VirtualDevice
## Ceiling smoke + carbon-monoxide alarm under the control-station roof
## (SmartThings "smoke detector" + "carbon monoxide detector" capabilities).
##
## Like the leak sensor it also owns the simulated hazard it watches: a
## smouldering cable in the console cabinet produces smoke for a while, then
## burns out; the smoke slowly clears and the alarm resets.

const ALARM_ON := 0.3
const ALARM_OFF := 0.1
const SOURCE_SECONDS := 20.0

@export var smoke_origin := Vector3(0, 1.05, -0.65)  ## local: top of the console cabinet
@export var mount_height := 2.62

var smoke_level := 0.0   ## 0..1 obscuration (normalised)
var source_time := 0.0   ## seconds the smoke source keeps burning
var alarm := false
var alarms := 0
var battery := 88.0
var _smoke: CPUParticles3D
var _ring_mat: StandardMaterial3D
var _audio: AudioStreamPlayer3D
var _blink := 0.0


func _init() -> void:
	super()
	device_name = "Smoke & CO Alarm"
	device_type = "Smoke + Carbon Monoxide Detector"
	category = "Safety"


func is_sensor() -> bool:
	return true


func is_alert() -> bool:
	return alarm


func get_co_ppm() -> float:
	return smoke_level * 140.0


func start_smoke(seconds := SOURCE_SECONDS) -> void:
	source_time = seconds
	_update_visuals()


func clear_smoke() -> void:
	source_time = 0.0
	smoke_level = minf(smoke_level, ALARM_OFF * 0.5)
	simulate(0.0)


func simulate(dt: float) -> void:
	if source_time > 0.0:
		source_time = maxf(source_time - dt, 0.0)
		smoke_level = minf(smoke_level + dt * 0.18, 1.0)
	else:
		smoke_level = maxf(smoke_level - dt * 0.05, 0.0)
	var was := alarm
	if not alarm and smoke_level > ALARM_ON:
		alarm = true
		alarms += 1
	elif alarm and smoke_level < ALARM_OFF:
		alarm = false
	_update_visuals()
	if alarm != was:
		_refresh()
	else:
		notify_reading()


func _status_online() -> String:
	return "SMOKE ALARM" if alarm else "Clear"


func get_primary_reading() -> String:
	return "ALARM - smoke detected" if alarm else "Clear"


func get_readings() -> Array:
	return [
		["Smoke", "Detected - ALARM" if alarm else ("Trace" if smoke_level > 0.02 else "Clear")],
		["Obscuration", "%.1f %%/m" % (smoke_level * 12.0)],
		["Carbon monoxide", "%d ppm" % int(get_co_ppm())],
		["Alarms", str(alarms)],
		["Battery", "%d %%" % int(battery)],
	]


func get_extra_controls() -> Array:
	return [
		{"id": "smoke", "label": "Simulate smouldering cable", "kind": "button", "enabled": source_time <= 0.0},
		{"id": "clear", "label": "Ventilate / clear smoke", "kind": "button", "enabled": smoke_level > 0.0 or source_time > 0.0},
	]


func _perform_extra(id: String, _value: Variant) -> void:
	match id:
		"smoke":
			start_smoke()
		"clear":
			clear_smoke()
	_refresh()


func _build_model() -> void:
	var y := mount_height
	ProcMesh.cyl(self, 0.075, 0.07, 0.045, Vector3(0, y, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 24)
	ProcMesh.cyl(self, 0.05, 0.05, 0.01, Vector3(0, y - 0.027, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 20, false)
	_ring_mat = Mats.emissive(Color(1.0, 0.15, 0.1), 0.0)
	ProcMesh.torus(self, 0.052, 0.062, Vector3(0, y - 0.024, 0), _ring_mat, Vector3.ZERO, false)
	_make_led(self, Vector3(0.04, y - 0.025, 0.02), 0.007)
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	q.material = Mats.get_mat("smoke")
	_smoke.mesh = q
	_smoke.amount = maxi(int(60 * float(GameSettings.q("particles"))), 14)
	_smoke.lifetime = 3.0
	_smoke.position = smoke_origin
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(0.6, 0.05, 0.2)
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.3
	_smoke.initial_velocity_max = 0.6
	_smoke.gravity = Vector3(0.15, 0.25, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(0.5, 0.5, 0.52, 0.0), Color(0.4, 0.4, 0.42, 0.85), Color(0.6, 0.6, 0.62, 0.0)])
	_smoke.color_ramp = ramp
	_smoke.cast_shadow = ProcMesh.NO_SHADOW
	add_child(_smoke)
	_audio = AudioManager.make_3d_player("smoke_beep", self, -10.0, 22.0)
	_audio.position = Vector3(0, y, 0)


func _update_visuals() -> void:
	if _smoke == null:
		return
	var emit := source_time > 0.0
	if _smoke.emitting != emit:
		_smoke.emitting = emit
	if alarm and not _audio.playing:
		_audio.play()
	elif not alarm and _audio.playing:
		_audio.stop()
	set_process(alarm)
	if not alarm:
		_ring_mat.emission_energy_multiplier = 0.0


func _process(delta: float) -> void:
	_blink += delta
	_ring_mat.emission_energy_multiplier = 4.0 if fmod(_blink, 0.5) < 0.3 else 0.3
