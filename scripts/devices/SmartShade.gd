class_name SmartShade
extends VirtualDevice
## Motorised greenhouse shade screen (SmartThings "window shade" capability).
## A cloth screen under the roof glass that slides across the greenhouse.
## Closed = shading: blocks part of the solar gain, so the air runs cooler.
## The device origin is the greenhouse centre; the switch panel is by the door.

const SHADE_COOLING := 2.5    ## °C at full sun with the screen fully closed
const TRAVEL_TIME := 6.0      ## seconds for a full open/close run

@export var screen_height := 2.97
@export var half_size := Vector2(7.85, 4.85)
@export var panel_position := Vector3(-2.3, 1.3, 4.82)

var position_pct := 0.0  ## 0 = open (retracted) .. 100 = closed (shading)
var _cloth: Node3D
var _bar: MeshInstance3D
var _motor_mat: StandardMaterial3D


func _init() -> void:
	super()
	device_name = "Greenhouse Shade Screen"
	device_type = "Smart Motorised Shade"
	category = "Climate"


func is_controllable() -> bool:
	return true


func is_running() -> bool:
	return power_on


func get_power_label() -> String:
	return "Shade"


func get_power_state_text(on: bool) -> String:
	return "CLOSED" if on else "OPEN"


func get_power_action_text(on: bool) -> String:
	return "Close shade" if on else "Open shade"


func get_thermal_offset() -> float:
	return -SHADE_COOLING * (position_pct / 100.0) * EnvironmentManager.get_ambient_light()


func is_moving() -> bool:
	return not is_equal_approx(position_pct, 100.0 if power_on else 0.0)


## Position is physical, so it advances in the simulation tick (deterministic).
func simulate(dt: float) -> void:
	var target := 100.0 if power_on else 0.0
	if is_equal_approx(position_pct, target):
		return
	position_pct = move_toward(position_pct, target, dt * 100.0 / TRAVEL_TIME)
	_apply_position()
	notify_reading()
	if is_equal_approx(position_pct, target):
		_refresh()


func _status_online() -> String:
	if is_moving():
		return "Closing" if power_on else "Opening"
	return "Closed - shading" if power_on else "Open"


func get_primary_reading() -> String:
	if is_moving():
		return "%s - %d %%" % ["CLOSING" if power_on else "OPENING", int(position_pct)]
	return "CLOSED - shading" if power_on else "OPEN"


func get_readings() -> Array:
	return [
		["Shade", _status_online()],
		["Position", "%d %% closed" % int(position_pct)],
		["Solar heat blocked", "-%.1f °C" % -get_thermal_offset()],
		["Outdoor light", "%.0f %%" % EnvironmentManager.get_light_percent()],
	]


func _build_model() -> void:
	# guide rails across the roof, motor tube on the north wall
	var metal := Mats.get_mat("metal")
	for x: float in [-half_size.x, -half_size.x * 0.33, half_size.x * 0.33, half_size.x]:
		ProcMesh.box(self, Vector3(0.04, 0.03, half_size.y * 2.0), Vector3(x, screen_height + 0.02, 0), metal, Vector3.ZERO, false)
	ProcMesh.cyl(self, 0.07, 0.07, half_size.x * 2.0, Vector3(0, screen_height, -half_size.y + 0.05), Mats.get_mat("plastic_white"), Vector3(0, 0, 90), 12)
	_motor_mat = Mats.emissive(COLOR_ONLINE, 1.0)
	ProcMesh.box(self, Vector3(0.22, 0.18, 0.18), Vector3(half_size.x - 0.2, screen_height - 0.12, -half_size.y + 0.1), Mats.get_mat("plastic_dark"))
	# the cloth is scaled along Z from the motor tube
	_cloth = Node3D.new()
	_cloth.position = Vector3(0, screen_height, -half_size.y + 0.05)
	add_child(_cloth)
	ProcMesh.box(_cloth, Vector3(half_size.x * 2.0, 0.015, 1.0), Vector3(0, 0, 0.5), Mats.get_mat("shade_cloth"), Vector3.ZERO, false)
	_bar = ProcMesh.box(self, Vector3(half_size.x * 2.0, 0.04, 0.05), Vector3.ZERO, metal, Vector3.ZERO, false)
	# wall switch panel inside, left of the door
	ProcMesh.box(self, Vector3(0.28, 0.4, 0.06), panel_position, Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.18, 0.08, 0.01), panel_position + Vector3(0, 0.09, -0.035), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	ProcMesh.box(self, Vector3(0.18, 0.08, 0.01), panel_position + Vector3(0, -0.02, -0.035), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_make_led(self, panel_position + Vector3(0.0, -0.12, -0.035), 0.018)
	var lbl := ProcMesh.label3d(self, "SHADE", panel_position + Vector3(0, -0.075, -0.036), 14, Color(0.15, 0.15, 0.2), false)
	lbl.rotation_degrees = Vector3(0, 180, 0)
	_apply_position()


func _apply_position() -> void:
	if _cloth == null:
		return
	var f := position_pct / 100.0
	var length := maxf(f * (half_size.y * 2.0 - 0.1), 0.01)
	_cloth.visible = f > 0.005
	_cloth.scale = Vector3(1, 1, length)
	_bar.position = _cloth.position + Vector3(0, -0.01, length)


func _update_visuals() -> void:
	_apply_position()
