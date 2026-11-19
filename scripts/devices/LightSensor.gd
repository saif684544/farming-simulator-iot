class_name LightSensor
extends VirtualDevice
## Outdoor ambient light (illuminance) sensor mounted on a pole.

var light_level := 100.0


func _init() -> void:
	super()
	device_name = "Ambient Light Sensor"
	device_type = "Illuminance Sensor"
	category = "Lighting"


func is_sensor() -> bool:
	return true


func simulate(_dt: float) -> void:
	light_level = EnvironmentManager.get_light_percent()
	notify_reading()


func get_lux() -> float:
	return light_level * light_level * 10.0


func get_primary_reading() -> String:
	return "%.0f %% light" % light_level


func get_readings() -> Array:
	return [
		["Ambient light", "%.0f %%" % light_level],
		["Illuminance", "%.0f lux" % get_lux()],
		["Time of day", "%s (%s)" % [EnvironmentManager.format_time(), EnvironmentManager.get_phase()]],
	]


func _build_model() -> void:
	ProcMesh.cyl(self, 0.035, 0.045, 2.6, Vector3(0, 1.3, 0), Mats.get_mat("metal"), Vector3.ZERO, 8)
	ProcMesh.cyl(self, 0.2, 0.22, 0.05, Vector3(0, 0.025, 0), Mats.get_mat("concrete"), Vector3.ZERO, 12)
	ProcMesh.box(self, Vector3(0.14, 0.1, 0.14), Vector3(0, 2.62, 0), Mats.get_mat("plastic_white"))
	var dome := ProcMesh.sphere(self, 0.07, Vector3(0, 2.68, 0), Mats.get_mat("glass"), Vector3(1, 0.8, 1), 12, false)
	dome.cast_shadow = ProcMesh.NO_SHADOW
	ProcMesh.sphere(self, 0.035, Vector3(0, 2.68, 0), Mats.get_mat("plastic_dark"), Vector3.ONE, 8, false)
	_make_led(self, Vector3(0.0, 2.6, 0.075), 0.018)
	# small IoT junction box lower on the pole
	ProcMesh.box(self, Vector3(0.16, 0.22, 0.09), Vector3(0, 1.2, 0.07), Mats.get_mat("plastic_white"))
