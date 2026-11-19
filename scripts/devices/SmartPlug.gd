class_name SmartPlug
extends VirtualDevice
## Outdoor smart plug supplying power to the irrigation pump.

@export var load_device_id := "irrigation_pump"
@export var cable_end := Vector3(0, 0.25, -1.8)  ## local point where the cable meets the pump

var _socket_mat: StandardMaterial3D


func _init() -> void:
	super()
	device_name = "Smart Plug"
	device_type = "Outdoor Smart Plug"
	category = "Water & irrigation"


func is_controllable() -> bool:
	return true


func get_load_watts() -> float:
	var pump := DeviceManager.get_device(load_device_id)
	if power_on and pump and pump.is_running():
		return 745.0
	return 0.6 if power_on else 0.0


func get_primary_reading() -> String:
	return "ON - %.0f W" % get_load_watts() if power_on else "OFF"


func get_readings() -> Array:
	var pump := DeviceManager.get_device(load_device_id)
	return [
		["Outlet", "ON" if power_on else "OFF"],
		["Connected equipment", pump.device_name if pump else "None"],
		["Power draw", "%.1f W" % get_load_watts()],
		["Voltage", "230 V" if power_on else "0 V"],
	]


func _build_model() -> void:
	# Post with a weatherproof outlet box, plug and cable running to the pump.
	ProcMesh.box(self, Vector3(0.1, 1.0, 0.1), Vector3(0, 0.5, 0), Mats.get_mat("wood_dark"))
	ProcMesh.box(self, Vector3(0.24, 0.3, 0.1), Vector3(0, 0.95, 0.09), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.26, 0.04, 0.14), Vector3(0, 1.11, 0.1), Mats.get_mat("plastic_white"))
	_socket_mat = Mats.emissive(COLOR_ONLINE, 1.5)
	ProcMesh.cyl(self, 0.06, 0.06, 0.02, Vector3(0, 0.95, 0.145), _socket_mat, Vector3(90, 0, 0), 16, false)
	ProcMesh.box(self, Vector3(0.07, 0.07, 0.05), Vector3(0, 0.95, 0.17), Mats.get_mat("plastic_dark"))
	_make_led(self, Vector3(0.085, 1.06, 0.142), 0.015)
	var c := Mats.get_mat("rubber")
	ProcMesh.cyl_between(self, Vector3(0, 0.92, 0.2), Vector3(0, 0.08, 0.22), 0.012, c, 6, false)
	ProcMesh.cyl_between(self, Vector3(0, 0.08, 0.22), Vector3(cable_end.x, 0.05, cable_end.z + 0.3), 0.012, c, 6, false)
	ProcMesh.cyl_between(self, Vector3(cable_end.x, 0.05, cable_end.z + 0.3), cable_end, 0.012, c, 6, false)


func _update_visuals() -> void:
	if _socket_mat == null:
		return
	var col := COLOR_ACTIVE if power_on and online else (COLOR_ONLINE if online else COLOR_OFFLINE)
	_socket_mat.emission = col
	_socket_mat.albedo_color = col
	_socket_mat.emission_energy_multiplier = 2.5 if power_on else 0.4
