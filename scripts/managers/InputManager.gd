extends Node
## Centralised input abstraction. Gameplay code only asks InputManager for a
## move vector, a look delta and discrete actions; keyboard/mouse, gamepad and
## on-screen touch controls all feed into the same API.

signal action_pressed(action: String)  ## "interact", "dashboard", "pause", "jump"
signal mouse_capture_changed(captured: bool)

const LOOK_MOUSE := 0.0025
const LOOK_TOUCH := 0.006
const LOOK_PAD := 2.6

var gameplay_enabled := true  ## false while a UI panel blocks gameplay
var _virtual_move := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _jump_queued := false
var _sprint_toggle := false
var _rmb_look := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_actions()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy_btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _joy_axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in events:
		InputMap.action_add_event(action, e)


func _define_actions() -> void:
	_add("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("sprint", [_key(KEY_SHIFT), _joy_btn(JOY_BUTTON_LEFT_STICK)])
	_add("jump", [_key(KEY_SPACE), _joy_btn(JOY_BUTTON_A)])
	_add("interact", [_key(KEY_E), _joy_btn(JOY_BUTTON_X)])
	_add("dashboard", [_key(KEY_TAB), _joy_btn(JOY_BUTTON_BACK)])
	_add("pause", [_key(KEY_ESCAPE), _joy_btn(JOY_BUTTON_START)])


# ---------------------------------------------------------------- queries ---

func get_move_vector() -> Vector2:
	if not gameplay_enabled:
		return Vector2.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	v += _virtual_move
	return v.limit_length(1.0)


func is_sprinting() -> bool:
	return gameplay_enabled and (Input.is_action_pressed("sprint") or _sprint_toggle)


func consume_jump() -> bool:
	var j := _jump_queued
	_jump_queued = false
	return j and gameplay_enabled


## Returns accumulated look rotation (radians, x = yaw, y = pitch) since last call.
func consume_look_delta(delta: float) -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	if not gameplay_enabled:
		return Vector2.ZERO
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if pad.length() > 0.15:
		d += pad * LOOK_PAD * delta
	if GameSettings.invert_y:
		d.y = -d.y
	return d


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# --------------------------------------------------------- touch bridge ---

func set_virtual_move(v: Vector2) -> void:
	_virtual_move = v


func add_touch_look(relative: Vector2) -> void:
	_look_delta += relative * LOOK_TOUCH * GameSettings.touch_sensitivity


func set_sprint_toggle(on: bool) -> void:
	_sprint_toggle = on


func is_sprint_toggled() -> bool:
	return _sprint_toggle


func trigger(action: String) -> void:
	if action == "jump":
		_jump_queued = true
	action_pressed.emit(action)


# ------------------------------------------------------- mouse capture ---

func set_mouse_captured(captured: bool) -> void:
	if PlatformManager.touch_enabled and captured:
		return
	var mode := Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
		mouse_capture_changed.emit(captured)


func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled
	if not enabled:
		_virtual_move = Vector2.ZERO
		_look_delta = Vector2.ZERO
		_rmb_look = false
		set_mouse_captured(false)


# --------------------------------------------------------------- events ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	for a: String in ["dashboard", "pause", "interact"]:
		if event.is_action_pressed(a):
			action_pressed.emit(a)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("jump") and gameplay_enabled:
		_jump_queued = true

	if event is InputEventMouseMotion:
		if gameplay_enabled and (is_mouse_captured() or _rmb_look):
			_look_delta += event.relative * LOOK_MOUSE * GameSettings.mouse_sensitivity


func _unhandled_input(event: InputEvent) -> void:
	# Clicking the 3D view (not UI) captures the mouse for camera control.
	# On the web this must happen inside a user gesture, which this is.
	if event is InputEventMouseButton and not PlatformManager.touch_enabled:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and gameplay_enabled:
			set_mouse_captured(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_look = event.pressed and gameplay_enabled


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_virtual_move = Vector2.ZERO
		_rmb_look = false
		set_mouse_captured(false)
