extends Node
## Registry of every virtual IoT device plus the fixed-step simulation clock.
## Devices register themselves on _ready; UI and automation look devices up by
## id and listen to the aggregated signals here instead of coupling to devices.

signal device_registered(device: VirtualDevice)
signal device_unregistered(device: VirtualDevice)
signal device_state_changed(device: VirtualDevice)
signal device_reading_updated(device: VirtualDevice)
signal simulation_ticked(dt: float)

const TICK := 0.1
const DISPLAY_ORDER := [
	"hub", "soil_sensor", "temp_sensor", "light_sensor", "smart_plug", "irrigation_pump", "vent_fan", "greenhouse_lights",
	"hvac", "greenhouse_shade", "water_valve", "leak_sensor",
	"shed_lock", "door_contact", "motion_sensor", "floodlight", "security_camera", "smoke_detector", "siren",
]

var auto_simulate := false  ## Main enables this; tests drive step() manually
var devices: Dictionary = {}
var _accum := 0.0


func register_device(d: VirtualDevice) -> void:
	if d.device_id.is_empty():
		push_warning("DeviceManager: device '%s' has no id" % d.name)
		return
	if devices.has(d.device_id) and devices[d.device_id] != d:
		push_warning("DeviceManager: duplicate device id '%s'" % d.device_id)
	devices[d.device_id] = d
	d.state_changed.connect(_on_device_state)
	d.reading_updated.connect(_on_device_reading)
	device_registered.emit(d)


func unregister_device(d: VirtualDevice) -> void:
	if devices.get(d.device_id) == d:
		devices.erase(d.device_id)
		if d.state_changed.is_connected(_on_device_state):
			d.state_changed.disconnect(_on_device_state)
			d.reading_updated.disconnect(_on_device_reading)
		device_unregistered.emit(d)


func get_device(id: String) -> VirtualDevice:
	var d = devices.get(id)
	if d != null and is_instance_valid(d):
		return d
	return null


func get_all_devices() -> Array[VirtualDevice]:
	var out: Array[VirtualDevice] = []
	for id in DISPLAY_ORDER:
		var d := get_device(id)
		if d:
			out.append(d)
	for id in devices:
		if not id in DISPLAY_ORDER and get_device(id):
			out.append(devices[id])
	return out


func get_device_count() -> int:
	return devices.size()


func get_online_count() -> int:
	var c := 0
	for d in devices.values():
		if is_instance_valid(d) and d.online:
			c += 1
	return c


## Automations route through the hub. With no hub present (unit tests) the
## network is treated as online.
func is_hub_online() -> bool:
	var hub := get_device("hub")
	return hub == null or (hub.online and hub.power_on)


func is_irrigating() -> bool:
	var pump := get_device("irrigation_pump")
	return pump != null and pump.has_method("is_running") and pump.is_running()


func is_fan_running() -> bool:
	var fan := get_device("vent_fan")
	return fan != null and fan.power_on


## Main water shut-off valve. Missing valve (unit tests) counts as open.
func is_water_valve_open() -> bool:
	var v := get_device("water_valve")
	return v == null or v.power_on


## Extra °C pushed onto the greenhouse air by climate equipment other than the
## exhaust fans (HVAC heat pump, shade screen).
func get_climate_offset() -> float:
	var off := 0.0
	for id: String in ["hvac", "greenhouse_shade"]:
		var d := get_device(id)
		if d and d.has_method("get_thermal_offset"):
			off += d.get_thermal_offset()
	return off


func get_devices_in_category(cat: String) -> Array[VirtualDevice]:
	var out: Array[VirtualDevice] = []
	for d in get_all_devices():
		if d.category == cat:
			out.append(d)
	return out


func _process(delta: float) -> void:
	if not auto_simulate:
		return
	_accum += minf(delta, 0.5)
	while _accum >= TICK:
		_accum -= TICK
		step(TICK)


## Advance the whole simulation by dt seconds.
func step(dt: float) -> void:
	EnvironmentManager.advance(dt)
	for d in devices.values():
		if is_instance_valid(d):
			d.simulate(dt)
	AutomationManager.evaluate_all(dt)
	simulation_ticked.emit(dt)


func _on_device_state(d: VirtualDevice) -> void:
	device_state_changed.emit(d)


func _on_device_reading(d: VirtualDevice) -> void:
	device_reading_updated.emit(d)
