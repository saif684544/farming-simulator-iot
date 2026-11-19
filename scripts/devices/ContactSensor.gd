class_name ContactSensor
extends VirtualDevice
## Magnetic open/close sensor on the shed door frame (SmartThings "contact
## sensor" capability). Reads the physical door state from the lock that owns
## the door leaf.

@export var door_device_id := "shed_lock"

var contact_open := false
var open_count := 0
var open_seconds := 0.0
var battery := 96.0


func _init() -> void:
	super()
	device_name = "Shed Door Contact"
	device_type = "Open/Close Sensor"
	category = "Security"


func is_sensor() -> bool:
	return true


func get_status_color() -> Color:
	if online and contact_open:
		return COLOR_IDLE
	return super()


func _door_is_open() -> bool:
	var lock := DeviceManager.get_device(door_device_id) as SmartLock
	return lock != null and lock.door_open


func simulate(dt: float) -> void:
	var now := _door_is_open()
	open_seconds = open_seconds + dt if now else 0.0
	if now != contact_open:
		contact_open = now
		if now:
			open_count += 1
		_refresh()
	elif now:
		notify_reading()


func _status_online() -> String:
	return "Open" if contact_open else "Closed"


func get_primary_reading() -> String:
	return "OPEN" if contact_open else "CLOSED"


func get_readings() -> Array:
	return [
		["Contact", "Open" if contact_open else "Closed"],
		["Open for", "%d s" % int(open_seconds) if contact_open else "-"],
		["Openings", str(open_count)],
		["Battery", "%d %%" % int(battery)],
	]


func _build_model() -> void:
	# sensor body on the frame + magnet piece next to it
	ProcMesh.box(self, Vector3(0.035, 0.11, 0.025), Vector3(0, 0, 0), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.025, 0.06, 0.02), Vector3(-0.045, 0, 0), Mats.get_mat("plastic_white"))
	_make_led(self, Vector3(0, 0.035, -0.014), 0.007)
