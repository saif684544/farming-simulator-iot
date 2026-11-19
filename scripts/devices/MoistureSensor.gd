class_name MoistureSensor
extends VirtualDevice
## Capacitive soil-moisture probe in the greenhouse bed. Simulates the soil
## itself: evaporation (faster when hot) and wetting while irrigation runs.

const IRRIGATION_RATE := 3.5   ## % per second while the pump runs
const BASE_DRY_RATE := 0.25    ## % per second at <= 20 °C

@export var initial_moisture := 45.0

var moisture := 45.0
var _gauge: MeshInstance3D
var _gauge_mat: StandardMaterial3D


func _init() -> void:
	super()
	device_name = "Soil Moisture Sensor"
	device_type = "Soil Moisture Sensor"
	category = "Water & irrigation"


func _after_ready() -> void:
	moisture = initial_moisture


func is_sensor() -> bool:
	return true


func simulate(dt: float) -> void:
	var temp := 25.0
	var ts := DeviceManager.get_device("temp_sensor") as TemperatureSensor
	if ts:
		temp = ts.temperature
	var rate := -(BASE_DRY_RATE + 0.03 * maxf(temp - 20.0, 0.0))
	if DeviceManager.is_irrigating():
		rate = IRRIGATION_RATE
	moisture = clampf(moisture + rate * dt, 0.0, 100.0)
	notify_reading()
	_update_visuals()


func get_primary_reading() -> String:
	return "%.1f %%" % moisture


func get_readings() -> Array:
	var state := "Dry" if moisture < 30.0 else ("Saturated" if moisture >= 65.0 else "Optimal")
	return [
		["Soil moisture", "%.1f %%" % moisture],
		["Soil condition", state],
		["Probe depth", "15 cm"],
		["Battery", "92 %"],
	]


func _build_model() -> void:
	# Probe spike pushed into the soil, sensor head and a moisture bar gauge.
	ProcMesh.cyl(self, 0.012, 0.004, 0.35, Vector3(0, -0.12, 0), Mats.get_mat("metal"), Vector3.ZERO, 6)
	ProcMesh.cyl(self, 0.012, 0.004, 0.35, Vector3(0.05, -0.12, 0), Mats.get_mat("metal"), Vector3.ZERO, 6)
	ProcMesh.box(self, Vector3(0.14, 0.32, 0.05), Vector3(0.025, 0.2, 0), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.1, 0.12, 0.01), Vector3(0.025, 0.25, 0.028), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	ProcMesh.cyl(self, 0.05, 0.05, 0.02, Vector3(0.025, 0.37, 0), Mats.get_mat("plastic_green"))
	_make_led(self, Vector3(0.07, 0.33, 0.028))
	_gauge_mat = Mats.emissive(Color(0.2, 0.6, 1.0), 2.5)
	_gauge = ProcMesh.box(self, Vector3(0.025, 0.1, 0.012), Vector3(0.025, 0.2, 0.034), _gauge_mat, Vector3.ZERO, false)


func _update_visuals() -> void:
	if _gauge == null:
		return
	var f := clampf(moisture / 100.0, 0.02, 1.0)
	_gauge.scale.y = f
	_gauge.position.y = 0.2 - 0.05 + 0.05 * f
	var c := Color(0.95, 0.55, 0.15).lerp(Color(0.2, 0.6, 1.0), clampf((moisture - 20.0) / 50.0, 0.0, 1.0))
	_gauge_mat.albedo_color = c
	_gauge_mat.emission = c
	# Wet soil looks darker and glossier.
	var soil := Mats.get_mat("soil") as StandardMaterial3D
	var w := clampf((moisture - 25.0) / 50.0, 0.0, 1.0)
	soil.albedo_color = Color(0.32, 0.22, 0.14).lerp(Color(0.17, 0.11, 0.07), w)
	soil.roughness = lerpf(0.97, 0.55, w)
