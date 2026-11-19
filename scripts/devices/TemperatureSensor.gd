class_name TemperatureSensor
extends VirtualDevice
## Greenhouse air temperature sensor. Simulates the greenhouse thermal model:
## air drifts towards a solar-gain target; ventilation pulls it down strongly.

const FAN_COOLING := 9.0     ## °C the fans subtract from the target
const RESPONSE := 0.06       ## 1/s approach rate

@export var initial_temperature := 27.0

var temperature := 27.0
var humidity := 62.0
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	device_name = "Temperature Sensor"
	device_type = "Temperature & Humidity Sensor"
	category = "Climate"


func _after_ready() -> void:
	temperature = initial_temperature
	_rng.seed = 77


func is_sensor() -> bool:
	return true


func get_target_temperature() -> float:
	var target := EnvironmentManager.get_greenhouse_target_temperature()
	if DeviceManager.is_fan_running():
		target -= FAN_COOLING
	return target + DeviceManager.get_climate_offset()


func simulate(dt: float) -> void:
	var target := get_target_temperature()
	temperature += (target - temperature) * minf(dt * RESPONSE, 1.0) + _rng.randf_range(-0.008, 0.008)
	temperature = clampf(temperature, -10.0, 60.0)
	humidity = clampf(85.0 - (temperature - 15.0) * 1.2 + (8.0 if DeviceManager.is_irrigating() else 0.0), 20.0, 98.0)
	notify_reading()
	_update_visuals()


func get_primary_reading() -> String:
	return "%.1f °C" % temperature


func get_readings() -> Array:
	var trend := "Rising" if get_target_temperature() > temperature + 0.3 else ("Falling" if get_target_temperature() < temperature - 0.3 else "Stable")
	return [
		["Air temperature", "%.1f °C" % temperature],
		["Humidity", "%.0f %%" % humidity],
		["Trend", trend],
		["Outdoor", "%.1f °C" % EnvironmentManager.get_outdoor_temperature()],
	]


func _build_model() -> void:
	# Standing post with a louvred radiation-shield housing (Stevenson-screen style).
	ProcMesh.cyl(self, 0.04, 0.05, 1.5, Vector3(0, 0.75, 0), Mats.get_mat("metal"), Vector3.ZERO, 10)
	ProcMesh.cyl(self, 0.18, 0.2, 0.04, Vector3(0, 0.02, 0), Mats.get_mat("concrete"), Vector3.ZERO, 12)
	for i in 5:
		ProcMesh.cyl(self, 0.11 - i * 0.008, 0.14 - i * 0.008, 0.035, Vector3(0, 1.38 + i * 0.045, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 16)
	ProcMesh.box(self, Vector3(0.16, 0.22, 0.05), Vector3(0, 1.15, 0.06), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.12, 0.15, 0.01), Vector3(0, 1.15, 0.088), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_make_led(self, Vector3(0.05, 1.24, 0.09))
	_bar_mat = Mats.emissive(Color(1.0, 0.5, 0.2), 2.5)
	_bar = ProcMesh.box(self, Vector3(0.02, 0.12, 0.01), Vector3(-0.03, 1.15, 0.095), _bar_mat, Vector3.ZERO, false)


func _update_visuals() -> void:
	if _bar == null:
		return
	var f := clampf((temperature - 10.0) / 30.0, 0.05, 1.0)
	_bar.scale.y = f
	_bar.position.y = 1.15 - 0.06 + 0.06 * f
	var c := Color(0.2, 0.6, 1.0).lerp(Color(1.0, 0.25, 0.15), clampf((temperature - 20.0) / 15.0, 0.0, 1.0))
	_bar_mat.albedo_color = c
	_bar_mat.emission = c
