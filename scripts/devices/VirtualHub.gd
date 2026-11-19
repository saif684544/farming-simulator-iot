class_name VirtualHub
extends VirtualDevice
## SmartThings-inspired virtual hub. Every automation is routed through it:
## while the hub is powered off or offline, automations pause.

var uptime := 0.0
var _ring_mat: StandardMaterial3D
var _pulse := 0.0


func _init() -> void:
	super()
	device_name = "Smart Farm Hub"
	device_type = "Virtual IoT Hub (Zigbee / Wi-Fi)"
	category = "Hub"
	start_powered = true


func is_controllable() -> bool:
	return true


func is_running() -> bool:
	return online and power_on


func simulate(dt: float) -> void:
	if is_running():
		uptime += dt


func get_paired_devices() -> Array[VirtualDevice]:
	var out: Array[VirtualDevice] = []
	for d in DeviceManager.get_all_devices():
		if d != self:
			out.append(d)
	return out


func get_connected_count() -> int:
	var c := 0
	for d in get_paired_devices():
		if d.online:
			c += 1
	return c


func _status_online() -> String:
	return "Online" if power_on else "Powered off"


func get_primary_reading() -> String:
	if not power_on:
		return "POWERED OFF"
	return "%d/%d devices online" % [get_connected_count(), get_paired_devices().size()]


func get_readings() -> Array:
	var rows: Array = [
		["Hub", _status_online()],
		["Connected devices", "%d / %d" % [get_connected_count(), get_paired_devices().size()]],
		["Automations enabled", "%d / %d" % [AutomationManager.get_enabled_count(), AutomationManager.rules.size()]],
		["Network", "Virtual mesh (simulated)"],
		["Uptime", "%d s" % int(uptime)],
	]
	for d in get_paired_devices():
		rows.append(["  " + d.device_name, d.get_status_text()])
	return rows


func get_extra_controls() -> Array:
	return [
		{"id": "reconnect_all", "label": "Reconnect all devices", "kind": "button", "enabled": online and power_on},
		{"id": "outage", "label": "Simulate device outage", "kind": "button", "enabled": online and power_on},
	]


func _perform_extra(id: String, _value: Variant) -> void:
	match id:
		"reconnect_all":
			for d in get_paired_devices():
				d.connect_device()
		"outage":
			var candidates := get_paired_devices().filter(func(d: VirtualDevice) -> bool: return d.online)
			if not candidates.is_empty():
				candidates.pick_random().disconnect_device()
	_refresh()


func _after_ready() -> void:
	DeviceManager.device_state_changed.connect(func(d: VirtualDevice) -> void:
		if d != self:
			_refresh_label())


func _build_model() -> void:
	# White rounded "puck" hub with a glowing status ring.
	ProcMesh.cyl(self, 0.16, 0.17, 0.06, Vector3(0, 0.03, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 32)
	ProcMesh.cyl(self, 0.13, 0.15, 0.02, Vector3(0, 0.07, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 32)
	_ring_mat = Mats.emissive(COLOR_ACTIVE, 3.0)
	ProcMesh.torus(self, 0.1, 0.115, Vector3(0, 0.081, 0), _ring_mat, Vector3.ZERO, false)
	ProcMesh.cyl(self, 0.03, 0.03, 0.005, Vector3(0, 0.082, 0), Mats.get_mat("plastic_dark"), Vector3.ZERO, 16, false)
	_make_led(self, Vector3(0.0, 0.035, 0.168), 0.012)
	set_process(true)


func _process(delta: float) -> void:
	if _ring_mat == null:
		return
	_pulse += delta
	if is_running():
		_ring_mat.emission = COLOR_ACTIVE
		_ring_mat.emission_energy_multiplier = 2.0 + sin(_pulse * 2.5) * 1.2
	else:
		_ring_mat.emission = COLOR_OFFLINE
		_ring_mat.emission_energy_multiplier = 0.6 + (0.6 if fmod(_pulse, 1.0) < 0.5 else 0.0)
