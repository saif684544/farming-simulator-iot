class_name SmartLock
extends VirtualDevice
## Smart deadbolt with keypad on the utility-shed door (SmartThings "lock"
## capability). power_on = LOCKED. The lock owns the door leaf so the door
## visibly swings open/closed; a locked door can't be opened and the bolt
## can't be thrown while the door stands open.
##
## Device origin: centre of the door opening at floor level; local -Z faces
## out of the shed.

const DOOR_W := 1.1
const DOOR_H := 2.1
const OPEN_ANGLE := 100.0

var door_open := false
var last_action := "-"
var battery := 84.0
var _pivot: Node3D
var _angle := 0.0
var _keypad_mat: StandardMaterial3D


func _init() -> void:
	super()
	device_name = "Shed Door Lock"
	device_type = "Smart Deadbolt + Keypad"
	category = "Security"


func is_controllable() -> bool:
	return true


func is_running() -> bool:
	return power_on


func get_power_label() -> String:
	return "Lock"


func get_power_state_text(on: bool) -> String:
	return "LOCKED" if on else "UNLOCKED"


func get_power_action_text(on: bool) -> String:
	return "Lock" if on else "Unlock"


## The bolt can't be thrown while the door is open.
func set_power(on: bool) -> bool:
	if on and door_open and online:
		last_action = "Lock refused - door open"
		_refresh()
		return false
	return super(on)


func set_door_open(open: bool) -> bool:
	if open and power_on:
		return false
	if door_open == open:
		return true
	door_open = open
	last_action = "Door %s at %s" % ["opened" if open else "closed", EnvironmentManager.format_time()]
	_refresh()
	return true


func _on_power_changed() -> void:
	last_action = "%s at %s" % ["Locked" if power_on else "Unlocked", EnvironmentManager.format_time()]


func get_status_color() -> Color:
	if online and not power_on:
		return COLOR_IDLE
	return super()


func _status_online() -> String:
	if door_open:
		return "Unlocked · door open"
	return "Locked" if power_on else "Unlocked"


func get_primary_reading() -> String:
	if door_open:
		return "UNLOCKED - door open"
	return "LOCKED" if power_on else "UNLOCKED"


func get_readings() -> Array:
	return [
		["Lock", "Locked" if power_on else "Unlocked"],
		["Door", "Open" if door_open else "Closed"],
		["Last action", last_action],
		["Battery", "%d %%" % int(battery)],
	]


func get_extra_controls() -> Array:
	# Opening the door is physical: works offline, but not while locked.
	return [
		{"id": "door", "label": "Door", "kind": "toggle", "value": door_open, "enabled": not power_on,
			"on_text": "OPEN", "off_text": "CLOSED"},
	]


func _perform_extra(id: String, value: Variant) -> void:
	if id == "door":
		set_door_open(bool(value) if value != null else not door_open)


func _build_model() -> void:
	# dark interior revealed when the door swings out
	ProcMesh.box(self, Vector3(DOOR_W - 0.04, DOOR_H - 0.04, 0.01), Vector3(0, DOOR_H * 0.5, 0.04), Mats.std(Color(0.05, 0.05, 0.06), 1.0), Vector3.ZERO, false)
	# frame
	var frame := Mats.get_mat("wood_painted")
	for x: float in [-DOOR_W * 0.5 - 0.05, DOOR_W * 0.5 + 0.05]:
		ProcMesh.box(self, Vector3(0.08, DOOR_H + 0.1, 0.1), Vector3(x, DOOR_H * 0.5, 0.0), frame)
	ProcMesh.box(self, Vector3(DOOR_W + 0.18, 0.08, 0.1), Vector3(0, DOOR_H + 0.04, 0.0), frame)
	# hinged door leaf (hinge on the -X side)
	_pivot = Node3D.new()
	_pivot.position = Vector3(-DOOR_W * 0.5, 0, 0)
	add_child(_pivot)
	ProcMesh.box(_pivot, Vector3(DOOR_W, DOOR_H, 0.06), Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0), Mats.get_mat("wood_dark"))
	for y: float in [0.4, DOOR_H - 0.4]:
		ProcMesh.box(_pivot, Vector3(DOOR_W - 0.1, 0.1, 0.02), Vector3(DOOR_W * 0.5, y, -0.04), Mats.get_mat("wood"), Vector3.ZERO, false)
	# keypad deadbolt + handle on the outside face
	var kx := DOOR_W - 0.16
	ProcMesh.box(_pivot, Vector3(0.08, 0.17, 0.03), Vector3(kx, 1.12, -0.045), Mats.get_mat("metal_dark"))
	_keypad_mat = Mats.emissive(Color(0.3, 0.75, 1.0), 0.6)
	ProcMesh.box(_pivot, Vector3(0.06, 0.1, 0.005), Vector3(kx, 1.13, -0.062), _keypad_mat, Vector3.ZERO, false)
	_make_led(_pivot, Vector3(kx, 1.19, -0.063), 0.008)
	ProcMesh.cyl(_pivot, 0.012, 0.012, 0.07, Vector3(kx, 1.0, -0.06), Mats.get_mat("metal"), Vector3(90, 0, 0), 8, false)
	ProcMesh.box(_pivot, Vector3(0.12, 0.022, 0.022), Vector3(kx - 0.05, 1.0, -0.095), Mats.get_mat("metal"), Vector3.ZERO, false)


func _update_visuals() -> void:
	if _keypad_mat:
		var c := Color(0.3, 0.75, 1.0) if power_on else Color(1.0, 0.75, 0.25)
		_keypad_mat.emission = c
		_keypad_mat.albedo_color = c
	set_process(true)


func _process(delta: float) -> void:
	var target := OPEN_ANGLE if door_open else 0.0
	_angle = move_toward(_angle, target, delta * 160.0)
	_pivot.rotation_degrees.y = _angle
	if is_equal_approx(_angle, target):
		set_process(false)
