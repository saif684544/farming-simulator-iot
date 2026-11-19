class_name SmartHVAC
extends VirtualDevice
## Greenhouse heat-pump HVAC with a built-in smart thermostat (SmartThings
## "thermostat" capability: mode, heating/cooling setpoints, operating state).
##
## The outdoor unit sits outside the east gable; an indoor wall unit blows
## warm or cool air into the greenhouse. The thermostat regulates on its own,
## with a 0.5 °C deadband. Cooling is "stage 2": the exhaust fans (automation)
## react at 32 °C, the heat pump only cools above its cooling setpoint.

const MODES := ["Heat", "Cool", "Auto"]
const HEAT_POWER := 10.0   ## °C added to the greenhouse target while heating
const COOL_POWER := 7.0    ## °C removed while cooling
const DEADBAND := 0.5

@export var temp_sensor_id := "temp_sensor"
@export var wall_unit_offset := Vector3(0, 2.3, -1.45)  ## indoor unit (local)

var mode := "Auto"
var heat_setpoint := 18.0
var cool_setpoint := 33.0
var operating := "Idle"   ## Idle / Heating / Cooling
var energy_kwh := 0.0
var _fan_speed := 0.0
var _rotor: Node3D
var _louver: Node3D
var _glow_mat: StandardMaterial3D
var _display: Label3D
var _audio: AudioStreamPlayer3D


func _init() -> void:
	super()
	device_name = "Greenhouse HVAC"
	device_type = "Heat Pump + Smart Thermostat"
	category = "Climate"


func is_controllable() -> bool:
	return true


func is_running() -> bool:
	return power_on and operating != "Idle"


func get_power_label() -> String:
	return "System"


## Physical effect on the greenhouse air (works while offline too - only the
## network link is lost, the thermostat keeps regulating locally).
func get_thermal_offset() -> float:
	if not power_on:
		return 0.0
	match operating:
		"Heating":
			return HEAT_POWER
		"Cooling":
			return -COOL_POWER
	return 0.0


func get_air_temperature() -> float:
	var ts := DeviceManager.get_device(temp_sensor_id) as TemperatureSensor
	if ts:
		return ts.temperature
	return EnvironmentManager.get_greenhouse_target_temperature()


func simulate(dt: float) -> void:
	var prev := operating
	if not power_on:
		operating = "Idle"
	else:
		var t := get_air_temperature()
		var can_heat := mode == "Heat" or mode == "Auto"
		var can_cool := mode == "Cool" or mode == "Auto"
		match operating:
			"Heating":
				if not can_heat or t >= heat_setpoint + DEADBAND:
					operating = "Idle"
			"Cooling":
				if not can_cool or t <= cool_setpoint - DEADBAND:
					operating = "Idle"
		if operating == "Idle":
			if can_heat and t < heat_setpoint - DEADBAND:
				operating = "Heating"
			elif can_cool and t > cool_setpoint + DEADBAND:
				operating = "Cooling"
	energy_kwh += get_power_kw() * dt / 3600.0
	if operating != prev:
		_refresh()
	else:
		notify_reading()


func get_power_kw() -> float:
	match operating:
		"Heating":
			return 2.4
		"Cooling":
			return 2.8
	return 0.02 if power_on else 0.0


func _status_online() -> String:
	if not power_on:
		return "Off"
	return "%s · %s" % [mode, operating] if operating != "Idle" else "%s · Idle" % mode


func get_primary_reading() -> String:
	if not power_on:
		return "OFF"
	var sp := heat_setpoint if operating == "Heating" or mode == "Heat" else cool_setpoint
	match operating:
		"Heating":
			return "%s - heating to %.0f °C" % [mode.to_upper(), sp]
		"Cooling":
			return "%s - cooling to %.0f °C" % [mode.to_upper(), sp]
	return "%s - idle (%.1f °C)" % [mode.to_upper(), get_air_temperature()]


func get_readings() -> Array:
	return [
		["Thermostat mode", mode if power_on else "Off"],
		["Operating state", operating],
		["Greenhouse air", "%.1f °C" % get_air_temperature()],
		["Heating setpoint", "%.0f °C" % heat_setpoint],
		["Cooling setpoint", "%.0f °C" % cool_setpoint],
		["Power draw", "%.2f kW" % get_power_kw()],
		["Energy used", "%.2f kWh" % energy_kwh],
	]


func get_extra_controls() -> Array:
	var on := online and power_on
	return [
		{"id": "mode", "label": "Thermostat mode", "kind": "choice", "options": MODES, "value": mode, "enabled": on},
		{"id": "heat_setpoint", "label": "Heat to", "kind": "stepper", "value": heat_setpoint, "min": 10.0, "max": 26.0, "step": 1.0, "unit": "°C", "enabled": on},
		{"id": "cool_setpoint", "label": "Cool to", "kind": "stepper", "value": cool_setpoint, "min": 22.0, "max": 38.0, "step": 1.0, "unit": "°C", "enabled": on},
	]


func _perform_extra(id: String, value: Variant) -> void:
	if not online:
		return
	match id:
		"mode":
			set_mode(str(value))
		"heat_setpoint":
			set_setpoints(float(value), cool_setpoint)
		"cool_setpoint":
			set_setpoints(heat_setpoint, float(value))


func set_mode(m: String) -> bool:
	if not online or not m in MODES:
		return false
	mode = m
	simulate(0.0)
	_refresh()
	return true


## Keeps at least 2 °C between the setpoints, like real auto-changeover thermostats.
func set_setpoints(heat: float, cool: float) -> void:
	heat = clampf(heat, 10.0, 26.0)
	cool = clampf(cool, 22.0, 38.0)
	if cool - heat < 2.0:
		if not is_equal_approx(heat, heat_setpoint):
			cool = heat + 2.0
		else:
			heat = cool - 2.0
	heat_setpoint = heat
	cool_setpoint = cool
	simulate(0.0)
	_refresh()


func _on_power_changed() -> void:
	simulate(0.0)


# ---------------------------------------------------------------- visuals ---

func _build_model() -> void:
	var white := Mats.get_mat("plastic_white")
	var dark := Mats.get_mat("metal_dark")
	# concrete pad + outdoor unit (front = local +Z)
	ProcMesh.box(self, Vector3(1.3, 0.1, 0.7), Vector3(0, 0.05, 0), Mats.get_mat("concrete"))
	ProcMesh.box(self, Vector3(1.1, 0.82, 0.42), Vector3(0, 0.53, 0), white)
	ProcMesh.box(self, Vector3(1.12, 0.04, 0.44), Vector3(0, 0.95, 0), Mats.get_mat("metal"))
	for x: float in [-0.45, 0.45]:
		ProcMesh.box(self, Vector3(0.08, 0.06, 0.5), Vector3(x, 0.13, 0), dark)
	# fan grille + rotor
	ProcMesh.torus(self, 0.28, 0.31, Vector3(-0.17, 0.53, 0.215), dark, Vector3(90, 0, 0))
	ProcMesh.cyl(self, 0.29, 0.29, 0.01, Vector3(-0.17, 0.53, 0.205), Mats.get_mat("plastic_dark"), Vector3(90, 0, 0), 24, false)
	_rotor = Node3D.new()
	_rotor.position = Vector3(-0.17, 0.53, 0.22)
	add_child(_rotor)
	for i in 3:
		var pv := Node3D.new()
		pv.rotation.z = i * TAU / 3.0
		_rotor.add_child(pv)
		ProcMesh.box(pv, Vector3(0.13, 0.25, 0.01), Vector3(0, 0.14, 0), Mats.get_mat("metal"), Vector3(0, 25, 0), false)
	for i in 5:
		ProcMesh.box(self, Vector3(0.6, 0.012, 0.012), Vector3(-0.17, 0.33 + i * 0.1, 0.235), dark, Vector3.ZERO, false)
	# thermostat display on the service panel
	ProcMesh.box(self, Vector3(0.26, 0.2, 0.02), Vector3(0.36, 0.7, 0.215), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_glow_mat = Mats.emissive(Color(0.3, 0.7, 1.0), 1.5)
	ProcMesh.box(self, Vector3(0.22, 0.03, 0.01), Vector3(0.36, 0.62, 0.226), _glow_mat, Vector3.ZERO, false)
	_display = ProcMesh.label3d(self, "", Vector3(0.36, 0.73, 0.227), 20, Color(0.8, 0.95, 1.0), false)
	_make_led(self, Vector3(0.46, 0.84, 0.215), 0.014)
	ProcMesh.label3d(self, "HEAT PUMP", Vector3(0.36, 0.45, 0.216), 16, Color(0.2, 0.22, 0.26), false)
	# copper line set up the wall and through it to the indoor unit
	var cu := Mats.get_mat("copper")
	var wall_z := wall_unit_offset.z + 0.17
	for dx: float in [0.0, 0.06]:
		ProcMesh.cyl_between(self, Vector3(0.5 + dx, 0.4, -0.21), Vector3(0.5 + dx, 0.4, wall_z), 0.016, cu, 6, false)
		ProcMesh.cyl_between(self, Vector3(0.5 + dx, 0.4, wall_z), Vector3(0.5 + dx, wall_unit_offset.y, wall_z), 0.016, cu, 6, false)
	ProcMesh.box(self, Vector3(0.16, wall_unit_offset.y - 0.3, 0.08), Vector3(0.53, (wall_unit_offset.y + 0.3) * 0.5, wall_z), white, Vector3.ZERO, false)
	# indoor wall unit (faces into the greenhouse = local -Z)
	var w := wall_unit_offset
	ProcMesh.box(self, Vector3(1.0, 0.32, 0.22), w, white)
	ProcMesh.box(self, Vector3(0.94, 0.03, 0.02), w + Vector3(0, -0.12, -0.115), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_louver = Node3D.new()
	_louver.position = w + Vector3(0, -0.15, -0.1)
	add_child(_louver)
	ProcMesh.box(_louver, Vector3(0.9, 0.012, 0.09), Vector3(0, 0, -0.04), white, Vector3.ZERO, false)
	ProcMesh.box(self, Vector3(0.3, 0.02, 0.01), w + Vector3(0.25, 0.06, -0.112), _glow_mat, Vector3.ZERO, false)
	_audio = AudioManager.make_3d_player("fan", self, -9.0, 16.0)
	_audio.pitch_scale = 0.7
	_audio.position = Vector3(-0.17, 0.53, 0.2)


func _update_visuals() -> void:
	if _glow_mat == null:
		return
	var c := Color(1.0, 0.55, 0.2) if operating == "Heating" else (Color(0.3, 0.7, 1.0) if operating == "Cooling" else Color(0.5, 0.9, 0.6))
	_glow_mat.albedo_color = c
	_glow_mat.emission = c
	_glow_mat.emission_energy_multiplier = (3.0 if operating != "Idle" else 0.8) if power_on else 0.0
	_display.text = ("%s %.0f°" % [mode.to_upper(), heat_setpoint if operating == "Heating" or mode == "Heat" else cool_setpoint]) if power_on else "OFF"
	var running := is_running()
	if _audio:
		if running and not _audio.playing:
			_audio.play()
		elif not running:
			_audio.stop()
	set_process(running or _fan_speed > 0.0)


func _process(delta: float) -> void:
	var running := is_running()
	_fan_speed = move_toward(_fan_speed, 1.0 if running else 0.0, delta * 0.8)
	_rotor.rotate_z(delta * 18.0 * _fan_speed)
	_louver.rotation.x = lerpf(0.0, 0.7, _fan_speed)
	if not running and _fan_speed <= 0.0:
		set_process(false)
