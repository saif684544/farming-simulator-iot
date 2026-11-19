class_name TestCase
extends RefCounted
## Minimal test base for the project's lightweight runner (GUT is not bundled).
## Every method whose name starts with "test_" is executed by TestRunner.

const DEVICE_SCENES := {
	"hub": "res://scenes/SmartHub.tscn",
	"soil_sensor": "res://scenes/Devices/MoistureSensor.tscn",
	"temp_sensor": "res://scenes/Devices/TemperatureSensor.tscn",
	"light_sensor": "res://scenes/Devices/LightSensor.tscn",
	"smart_plug": "res://scenes/Devices/SmartPlug.tscn",
	"irrigation_pump": "res://scenes/Devices/IrrigationPump.tscn",
	"vent_fan": "res://scenes/Devices/VentilationFan.tscn",
	"greenhouse_lights": "res://scenes/Devices/SmartLight.tscn",
}
## Climate, water, security and safety devices added on top of the core farm.
const SMART_HOME_SCENES := {
	"hvac": "res://scenes/Devices/SmartHVAC.tscn",
	"greenhouse_shade": "res://scenes/Devices/SmartShade.tscn",
	"water_valve": "res://scenes/Devices/SmartValve.tscn",
	"leak_sensor": "res://scenes/Devices/LeakSensor.tscn",
	"shed_lock": "res://scenes/Devices/SmartLock.tscn",
	"door_contact": "res://scenes/Devices/ContactSensor.tscn",
	"motion_sensor": "res://scenes/Devices/MotionSensor.tscn",
	"floodlight": "res://scenes/Devices/SmartFloodlight.tscn",
	"security_camera": "res://scenes/Devices/SecurityCamera.tscn",
	"smoke_detector": "res://scenes/Devices/SmokeDetector.tscn",
	"siren": "res://scenes/Devices/SmartSiren.tscn",
}

var runner: Node
var failures: Array[String] = []
var _nodes: Array[Node] = []


func before_each() -> void:
	DeviceManager.auto_simulate = false
	AutomationManager.reset()
	EnvironmentManager.set_time(12.0)
	EnvironmentManager.time_speed = 1.0
	EnvironmentManager.heat_boost = 0.0


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func spawn(path: String) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	runner.add_child(n)
	_nodes.append(n)
	return n


func spawn_device(id: String) -> VirtualDevice:
	return spawn(DEVICE_SCENES[id] if DEVICE_SCENES.has(id) else SMART_HOME_SCENES[id]) as VirtualDevice


## Spawn the core farm plus every smart-home device (19 in total).
func spawn_everything() -> Dictionary:
	var out := spawn_all()
	for id in SMART_HOME_SCENES:
		out[id] = spawn_device(id)
	return out


## Spawn every device of the farm, returns id -> device.
func spawn_all() -> Dictionary:
	var out := {}
	for id in DEVICE_SCENES:
		out[id] = spawn_device(id)
	return out


func run_sim(seconds: float) -> void:
	var steps := int(seconds / DeviceManager.TICK)
	for i in steps:
		DeviceManager.step(DeviceManager.TICK)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s (expected %s, got %s)" % [msg, str(b), str(a)])
