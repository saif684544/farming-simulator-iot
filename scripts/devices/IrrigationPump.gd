class_name IrrigationPump
extends VirtualDevice
## Electric irrigation pump fed by the smart plug. Runs only when it is both
## switched on AND its smart plug supplies power. While running it spins its
## cooling fan, animates water flow along every irrigation pipe and activates
## all sprinklers in the "sprinkler" group.

@export var supply_plug_id := "smart_plug"

var flow := 0.0  ## 0..1 smoothed flow used for visuals
var _rotor: Node3D
var _motor: Node3D
var _gauge_needle: Node3D
var _audio: AudioStreamPlayer3D
var _running_cached := false


func _init() -> void:
	super()
	device_name = "Irrigation Pump"
	device_type = "Water Pump (0.75 kW)"
	category = "Water & irrigation"


func is_controllable() -> bool:
	return true


func has_supply_power() -> bool:
	var plug := DeviceManager.get_device(supply_plug_id)
	return plug == null or plug.power_on


func has_water() -> bool:
	return DeviceManager.is_water_valve_open()


func is_running() -> bool:
	return power_on and has_supply_power() and has_water()


func _after_ready() -> void:
	DeviceManager.device_state_changed.connect(_on_any_device_changed)


func _on_any_device_changed(d: VirtualDevice) -> void:
	if d.device_id == supply_plug_id or d.device_id == "water_valve":
		_refresh()


func _status_online() -> String:
	if is_running():
		return "Running"
	if power_on and not has_supply_power():
		return "No power (plug off)"
	if power_on:
		return "No water (valve closed)"
	return "Off"


func get_primary_reading() -> String:
	if is_running():
		return "RUNNING - 42 L/min"
	if power_on:
		return "ON - no power" if not has_supply_power() else "ON - valve closed"
	return "OFF"


func get_readings() -> Array:
	return [
		["Pump", _status_online()],
		["Supply (smart plug)", "Powered" if has_supply_power() else "No power"],
		["Water (main valve)", "Open" if has_water() else "Closed"],
		["Flow rate", "42 L/min" if is_running() else "0 L/min"],
		["Pressure", "2.4 bar" if is_running() else "0.0 bar"],
		["Active sprinklers", str(get_tree().get_nodes_in_group("sprinkler").size()) if is_running() and is_inside_tree() else "0"],
	]


func _build_model() -> void:
	var paint := Mats.get_mat("plastic_blue")
	var metal := Mats.get_mat("metal")
	var dark := Mats.get_mat("metal_dark")
	# skid / base frame
	ProcMesh.box(self, Vector3(1.3, 0.08, 0.6), Vector3(0, 0.04, 0), dark)
	_motor = Node3D.new()
	add_child(_motor)
	# motor body with cooling fins
	ProcMesh.cyl(_motor, 0.2, 0.2, 0.55, Vector3(-0.2, 0.33, 0), paint, Vector3(0, 0, 90), 20)
	for i in 6:
		ProcMesh.cyl(_motor, 0.215, 0.215, 0.02, Vector3(-0.42 + i * 0.09, 0.33, 0), paint, Vector3(0, 0, 90), 20)
	ProcMesh.box(_motor, Vector3(0.18, 0.12, 0.18), Vector3(-0.2, 0.56, 0), paint)
	# fan cowl at the back of the motor; the visible spinning part
	ProcMesh.cyl(_motor, 0.19, 0.19, 0.06, Vector3(-0.5, 0.33, 0), dark, Vector3(0, 0, 90), 20)
	_rotor = Node3D.new()
	_rotor.position = Vector3(-0.54, 0.33, 0)
	_motor.add_child(_rotor)
	for i in 4:
		ProcMesh.box(_rotor, Vector3(0.02, 0.32, 0.05), Vector3.ZERO, metal, Vector3(i * 45.0, 0, 0))
	ProcMesh.cyl(_rotor, 0.05, 0.05, 0.03, Vector3.ZERO, Mats.get_mat("yellow"), Vector3(0, 0, 90), 12)
	# pump volute
	ProcMesh.cyl(self, 0.24, 0.24, 0.16, Vector3(0.22, 0.33, 0), metal, Vector3(0, 0, 90), 24)
	ProcMesh.cyl(self, 0.09, 0.09, 0.22, Vector3(0.42, 0.33, 0), metal, Vector3(0, 0, 90), 12)
	# outlet riser + pressure gauge
	ProcMesh.cyl(self, 0.06, 0.06, 0.45, Vector3(0.22, 0.75, 0), metal, Vector3.ZERO, 12)
	ProcMesh.cyl(self, 0.07, 0.07, 0.04, Vector3(0.22, 0.98, 0), dark, Vector3.ZERO, 12)
	ProcMesh.cyl(self, 0.07, 0.07, 0.03, Vector3(0.22, 0.82, 0.09), Mats.get_mat("plastic_white"), Vector3(90, 0, 0), 16, false)
	_gauge_needle = Node3D.new()
	_gauge_needle.position = Vector3(0.22, 0.82, 0.108)
	add_child(_gauge_needle)
	ProcMesh.box(_gauge_needle, Vector3(0.008, 0.05, 0.004), Vector3(0, 0.02, 0), Mats.get_mat("red"), Vector3.ZERO, false)
	# control box with LED
	ProcMesh.box(self, Vector3(0.22, 0.26, 0.12), Vector3(-0.2, 0.25, 0.3), Mats.get_mat("plastic_white"))
	_make_led(self, Vector3(-0.2, 0.32, 0.365))
	ProcMesh.label3d(self, "PUMP", Vector3(-0.2, 0.2, 0.362), 22, Color(0.2, 0.2, 0.25), false)
	_audio = AudioManager.make_3d_player("pump", self, -4.0, 22.0)


func _update_visuals() -> void:
	var running := is_running()
	if running != _running_cached:
		_running_cached = running
		for s in get_tree().get_nodes_in_group("sprinkler"):
			s.set_active(running)
		if _audio:
			if running:
				_audio.play()
			else:
				_audio.stop()
	set_process(running or flow > 0.0)


func _process(delta: float) -> void:
	var running := is_running()
	flow = move_toward(flow, 1.0 if running else 0.0, delta * 1.5)
	(Mats.get_mat("pipe") as ShaderMaterial).set_shader_parameter("flow", flow)
	if _rotor:
		_rotor.rotate_x(delta * 40.0 * flow)
		_motor.position = Vector3(0, sin(Time.get_ticks_msec() * 0.09) * 0.003 * flow, 0)
		_gauge_needle.rotation.z = lerpf(1.2, -0.9, flow)
	if not running and flow <= 0.0:
		set_process(false)
