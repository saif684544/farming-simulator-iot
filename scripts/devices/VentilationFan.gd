class_name VentilationFan
extends VirtualDevice
## Pair of greenhouse exhaust fans on the back wall. Blades spin up/down
## smoothly; the device origin sits between the two fan units.

@export var fan_spacing := 7.0
@export var fan_height := 2.2

var speed := 0.0  ## 0..1 smoothed
var _blades: Array[Node3D] = []
var _audio: AudioStreamPlayer3D


func _init() -> void:
	super()
	device_name = "Ventilation Fans"
	device_type = "Smart Exhaust Fan (x2)"
	category = "Climate"


func is_controllable() -> bool:
	return true


func _status_online() -> String:
	return "Running" if power_on else "Off"


func get_primary_reading() -> String:
	return "RUNNING - 1450 rpm" if power_on else "OFF"


func get_readings() -> Array:
	return [
		["Fans", "Running" if power_on else "Stopped"],
		["Speed", "%d rpm" % int(speed * 1450.0)],
		["Airflow", "%d m³/h" % int(speed * 9800.0)],
		["Cooling effect", "-%.0f °C" % TemperatureSensor.FAN_COOLING if power_on else "-"],
	]


func _build_model() -> void:
	for side: float in [-1.0, 1.0]:
		var unit := Node3D.new()
		unit.position = Vector3(side * fan_spacing * 0.5, fan_height, 0)
		add_child(unit)
		_build_fan_unit(unit)
	# wall controller box at reachable height
	ProcMesh.box(self, Vector3(0.3, 0.4, 0.08), Vector3(0, 1.3, 0.04), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.2, 0.12, 0.01), Vector3(0, 1.36, 0.085), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_make_led(self, Vector3(0.1, 1.2, 0.085))
	ProcMesh.label3d(self, "FAN CTRL", Vector3(0, 1.22, 0.085), 18, Color(0.15, 0.15, 0.2), false)
	_audio = AudioManager.make_3d_player("fan", self, -2.0, 18.0)
	_audio.position = Vector3(0, fan_height, 0)


func _build_fan_unit(unit: Node3D) -> void:
	var frame := Mats.get_mat("metal")
	var dark := Mats.get_mat("metal_dark")
	var s := 1.3
	# square housing
	ProcMesh.box(unit, Vector3(s, 0.08, 0.35), Vector3(0, s * 0.5, 0), frame)
	ProcMesh.box(unit, Vector3(s, 0.08, 0.35), Vector3(0, -s * 0.5, 0), frame)
	ProcMesh.box(unit, Vector3(0.08, s, 0.35), Vector3(s * 0.5, 0, 0), frame)
	ProcMesh.box(unit, Vector3(0.08, s, 0.35), Vector3(-s * 0.5, 0, 0), frame)
	# shroud ring + guard
	ProcMesh.torus(unit, 0.56, 0.6, Vector3(0, 0, 0.05), dark, Vector3(90, 0, 0))
	for i in 4:
		ProcMesh.box(unit, Vector3(0.015, 1.15, 0.015), Vector3(0, 0, 0.17), frame, Vector3(0, 0, i * 45.0), false)
	ProcMesh.torus(unit, 0.27, 0.29, Vector3(0, 0, 0.17), frame, Vector3(90, 0, 0), false)
	# motor + blades
	ProcMesh.cyl(unit, 0.12, 0.12, 0.2, Vector3(0, 0, -0.08), dark, Vector3(90, 0, 0), 14)
	var blades := Node3D.new()
	blades.position = Vector3(0, 0, 0.05)
	unit.add_child(blades)
	ProcMesh.cyl(blades, 0.09, 0.09, 0.08, Vector3.ZERO, Mats.get_mat("plastic_white"), Vector3(90, 0, 0), 14)
	for i in 5:
		var pivot := Node3D.new()
		pivot.rotation.z = i * TAU / 5.0
		blades.add_child(pivot)
		ProcMesh.box(pivot, Vector3(0.2, 0.48, 0.015), Vector3(0, 0.3, 0), Mats.get_mat("plastic_white"), Vector3(0, 28, 0))
	_blades.append(blades)


func _update_visuals() -> void:
	set_process(power_on or speed > 0.0)
	if _audio:
		if power_on and not _audio.playing:
			_audio.play()
		elif not power_on:
			_audio.stop()


func _process(delta: float) -> void:
	speed = move_toward(speed, 1.0 if power_on else 0.0, delta * 0.6)
	for b in _blades:
		b.rotate_z(delta * 22.0 * speed)
	if not power_on and speed <= 0.0:
		set_process(false)
