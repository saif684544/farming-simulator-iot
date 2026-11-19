class_name VirtualDevice
extends Node3D
## Base class for every simulated IoT device.
##
## - `online`  : network connection to the virtual hub (can be toggled to
##               simulate connectivity loss). Offline devices can't be commanded
##               and their readings are not trusted by automations.
## - `power_on`: physical switch state for actuators.
##
## Subclasses override the hooks in the "virtuals" section. UI code never talks
## to a subclass directly - it uses get_readings()/get_controls()/perform_control().

signal state_changed(device: VirtualDevice)
signal connection_changed(device: VirtualDevice, connected: bool)
signal reading_updated(device: VirtualDevice)

const COLOR_ONLINE := Color(0.25, 0.85, 0.45)
const COLOR_ACTIVE := Color(0.15, 0.65, 1.0)
const COLOR_OFFLINE := Color(0.95, 0.25, 0.2)
const COLOR_IDLE := Color(0.95, 0.75, 0.2)
const COLOR_OFF := Color(0.6, 0.65, 0.72)
const COLOR_ALERT := Color(1.0, 0.35, 0.15)

## Dashboard grouping, in display order.
const CATEGORIES := ["Hub", "Climate", "Water & irrigation", "Lighting", "Security", "Safety"]

@export var device_id := ""
@export var device_name := "Virtual Device"
@export var device_type := "Generic Device"
@export var category := "Hub"
@export var start_online := true
@export var start_powered := false
@export var interact_point := Vector3(0, 1.0, 0)  ## local position the player must approach
@export var interact_radius := 2.0
@export var label_offset := Vector3(0, 1.9, 0)
@export var build_visuals := true  ## tests can skip model building

var online := false
var power_on := false
var _label: Label3D
var _highlight: MeshInstance3D
var _led_mat: StandardMaterial3D
var _highlighted := false
var _registered := false


func _init() -> void:
	online = start_online


func _enter_tree() -> void:
	if not _registered and not device_id.is_empty():
		DeviceManager.register_device(self)
		_registered = true


func _exit_tree() -> void:
	if _registered:
		DeviceManager.unregister_device(self)
		_registered = false


func _ready() -> void:
	online = start_online
	power_on = start_powered
	if build_visuals:
		_build_model()
		ProcMesh.bake_static(self, _script_node_refs())
		_label = ProcMesh.label3d(self, "", label_offset, 36)
		_label.visibility_range_end = 18.0
		_label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		_label.visibility_range_end_margin = 3.0
		_label.visibility_range_begin = 1.6
		_label.visibility_range_begin_margin = 0.6
		_create_highlight()
	_after_ready()
	_refresh()


# ------------------------------------------------------------ public API ---

func connect_device() -> void:
	if online:
		return
	online = true
	connection_changed.emit(self, true)
	_refresh()


func disconnect_device() -> void:
	if not online:
		return
	online = false
	connection_changed.emit(self, false)
	_refresh()


## Returns false if the command could not be delivered (offline / not switchable).
func set_power(on: bool) -> bool:
	if not online or not is_controllable():
		return false
	if power_on == on:
		return true
	power_on = on
	_on_power_changed()
	_refresh()
	return true


func toggle_power() -> bool:
	return set_power(not power_on)


## True when the device is physically doing work (actuators) / reporting (sensors).
func is_running() -> bool:
	return power_on


func notify_reading() -> void:
	_refresh_label()
	reading_updated.emit(self)


func get_interact_position() -> Vector3:
	return global_transform * interact_point


func set_highlighted(on: bool) -> void:
	_highlighted = on
	if _highlight:
		_highlight.visible = on


func get_status_text() -> String:
	if not online:
		return "Offline"
	return _status_online()


func get_status_color() -> Color:
	if not online:
		return COLOR_OFFLINE
	if is_alert():
		return COLOR_ALERT
	if is_controllable():
		return COLOR_ACTIVE if is_running() else (COLOR_IDLE if power_on else COLOR_OFF)
	return COLOR_ONLINE


## Generic control descriptors consumed by DevicePanel and the dashboard.
func get_controls() -> Array:
	var c: Array = []
	if is_controllable():
		c.append({"id": "power", "label": get_power_label(), "kind": "toggle", "value": power_on, "enabled": online,
			"on_text": get_power_state_text(true), "off_text": get_power_state_text(false)})
	c.append_array(get_extra_controls())
	c.append({"id": "connection", "label": "Network connection", "kind": "toggle", "value": online, "enabled": true})
	return c


func perform_control(id: String, value: Variant = null) -> void:
	match id:
		"power":
			set_power(bool(value) if value != null else not power_on)
		"connection":
			var want: bool = bool(value) if value != null else not online
			if want:
				connect_device()
			else:
				disconnect_device()
		_:
			_perform_extra(id, value)
			_refresh()
	AudioManager.play_ui("beep" if (id == "power" and power_on) or (id == "connection" and online) else "beep_off")


# -------------------------------------------------------------- virtuals ---

func is_sensor() -> bool:
	return false


func is_controllable() -> bool:
	return false


## Wording for the main switch. A lock's "power" is Locked/Unlocked, a valve's
## is Open/Closed - the API stays the same, only the words change.
func get_power_label() -> String:
	return "Power"


func get_power_state_text(on: bool) -> String:
	return "ON" if on else "OFF"


## Button text for the command that sets the switch to `on`.
func get_power_action_text(on: bool) -> String:
	return "Turn ON" if on else "Turn OFF"


## True while the device reports an alarm condition (leak, smoke, intrusion).
func is_alert() -> bool:
	return false


## Optional live image (security camera). The panel calls set_preview_active
## so the device only renders while someone is looking at it.
func get_preview_texture() -> Texture2D:
	return null


func set_preview_active(_on: bool) -> void:
	pass


func simulate(_dt: float) -> void:
	pass


func get_primary_reading() -> String:
	return "On" if power_on else "Off"


## Array of [label, value] pairs.
func get_readings() -> Array:
	return []


func get_extra_controls() -> Array:
	return []


func _perform_extra(_id: String, _value: Variant) -> void:
	pass


func _status_online() -> String:
	if is_controllable():
		return "On" if power_on else "Off"
	return "Online"


func _build_model() -> void:
	pass


func _after_ready() -> void:
	pass


func _on_power_changed() -> void:
	pass


func _update_visuals() -> void:
	pass


# --------------------------------------------------------------- helpers ---

func _refresh() -> void:
	_update_led()
	_update_visuals()
	_refresh_label()
	state_changed.emit(self)


func _refresh_label() -> void:
	if _label == null:
		return
	var reading := get_primary_reading() if online else "OFFLINE"
	_label.text = "%s\n%s" % [device_name, reading]
	_label.modulate = Color(1, 1, 1) if online else Color(1.0, 0.6, 0.55)


func _make_led(parent: Node3D, pos: Vector3, radius := 0.022) -> MeshInstance3D:
	if _led_mat == null:
		_led_mat = Mats.emissive(COLOR_ONLINE, 3.0)
	return ProcMesh.sphere(parent, radius, pos, _led_mat, Vector3.ONE, 8, false)


func _update_led() -> void:
	if _led_mat == null:
		return
	var c := get_status_color()
	_led_mat.albedo_color = c
	_led_mat.emission = c
	_led_mat.emission_energy_multiplier = 3.0 if online else 1.2


## Nodes held in script variables (animated parts) must not be baked away.
func _script_node_refs() -> Array:
	var out: Array = []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v: Variant = get(p.name)
			if v is Node:
				out.append(v)
			elif v is Array:
				for e in v:
					if e is Node:
						out.append(e)
	return out


func _create_highlight() -> void:
	# Ground ring around the interaction spot, always placed on the floor (y = 0).
	_highlight = ProcMesh.torus(self, 0.55, 0.62, interact_point, Mats.get_mat("highlight"), Vector3.ZERO, false)
	if is_inside_tree():
		var gp := get_interact_position()
		_highlight.global_position = Vector3(gp.x, 0.05, gp.z)
	_highlight.visible = false
