class_name SmartValve
extends VirtualDevice
## Motorised main shut-off valve on the irrigation line (SmartThings "valve"
## capability). power_on = valve OPEN. The irrigation pump can only deliver
## water while it is open; the leak-protection automation closes it.

const TURN_TIME := 2.0  ## seconds for a quarter turn

var lever := 1.0  ## 0 = closed, 1 = open (animated)
var close_count := 0
var _lever_node: Node3D


func _init() -> void:
	super()
	device_name = "Main Water Valve"
	device_type = "Smart Shut-off Valve"
	category = "Water & irrigation"


func _after_ready() -> void:
	lever = 1.0 if power_on else 0.0
	_apply_lever()


func is_controllable() -> bool:
	return true


func get_power_label() -> String:
	return "Valve"


func get_power_state_text(on: bool) -> String:
	return "OPEN" if on else "CLOSED"


func get_power_action_text(on: bool) -> String:
	return "Open valve" if on else "Close valve"


func get_status_color() -> Color:
	if online and not power_on:
		return COLOR_IDLE
	return super()


func _status_online() -> String:
	return "Open" if power_on else "Closed"


func get_flow() -> float:
	return 42.0 if DeviceManager.is_irrigating() else 0.0


func get_primary_reading() -> String:
	if not power_on:
		return "CLOSED"
	return "OPEN - %.0f L/min" % get_flow() if get_flow() > 0.0 else "OPEN"


func get_readings() -> Array:
	return [
		["Valve", "Open" if power_on else "Closed"],
		["Flow", "%.0f L/min" % get_flow()],
		["Line pressure", "2.4 bar" if get_flow() > 0.0 else ("0.4 bar (tank head)" if power_on else "0.0 bar")],
		["Times closed", str(close_count)],
	]


func _on_power_changed() -> void:
	if not power_on:
		close_count += 1
	set_process(true)


func _build_model() -> void:
	# Valve body sits on the existing main line (pipe runs along X at y=0.3).
	var metal := Mats.get_mat("metal")
	ProcMesh.cyl(self, 0.09, 0.09, 0.26, Vector3(0, 0.3, 0), Mats.get_mat("copper"), Vector3(0, 0, 90), 14)
	ProcMesh.sphere(self, 0.11, Vector3(0, 0.3, 0), Mats.get_mat("copper"), Vector3.ONE, 12)
	for x: float in [-0.14, 0.14]:
		ProcMesh.cyl(self, 0.075, 0.075, 0.04, Vector3(x, 0.3, 0), metal, Vector3(0, 0, 90), 12)
	# motor actuator on top
	ProcMesh.cyl(self, 0.03, 0.03, 0.08, Vector3(0, 0.44, 0), metal, Vector3.ZERO, 8)
	ProcMesh.box(self, Vector3(0.2, 0.16, 0.16), Vector3(0, 0.56, 0), Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.21, 0.03, 0.17), Vector3(0, 0.5, 0), Mats.get_mat("plastic_blue"))
	_make_led(self, Vector3(0.0, 0.6, -0.082), 0.014)
	var lbl := ProcMesh.label3d(self, "VALVE", Vector3(0, 0.54, -0.081), 14, Color(0.15, 0.15, 0.2), false)
	lbl.rotation_degrees = Vector3(0, 180, 0)
	# position indicator lever: along the pipe = open, across = closed
	_lever_node = Node3D.new()
	_lever_node.position = Vector3(0, 0.65, 0)
	add_child(_lever_node)
	ProcMesh.box(_lever_node, Vector3(0.3, 0.025, 0.04), Vector3(0.08, 0, 0), Mats.get_mat("red"), Vector3.ZERO, false)
	ProcMesh.static_box(self, Vector3(0.35, 0.7, 0.3), Vector3(0, 0.35, 0))


func _update_visuals() -> void:
	set_process(true)


func _process(delta: float) -> void:
	lever = move_toward(lever, 1.0 if power_on else 0.0, delta / TURN_TIME)
	_apply_lever()
	if is_equal_approx(lever, 1.0 if power_on else 0.0):
		set_process(false)


func _apply_lever() -> void:
	if _lever_node:
		_lever_node.rotation.y = lerpf(PI * 0.5, 0.0, lever)
