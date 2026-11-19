extends Control
## Multi-touch on-screen controls: virtual joystick (left), camera drag area
## (right half), and Interact / Jump / Sprint buttons. Each finger is tracked
## by its touch index so the joystick and buttons work simultaneously.
## All output goes through InputManager.

const JOY_RADIUS := 80.0
const KNOB_RADIUS := 34.0

var _joy_center := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _joy_touch := -1
var _look_touch := -1
var _buttons: Array = []  ## [{id, center, radius, label, touch}]
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_buttons = [
		{"id": "interact", "label": "INTERACT", "radius": 54.0, "touch": -1},
		{"id": "jump", "label": "JUMP", "radius": 38.0, "touch": -1},
		{"id": "sprint", "label": "SPRINT", "radius": 38.0, "touch": -1},
	]
	PlatformManager.layout_changed.connect(func(_s: Vector2, _p: bool) -> void: _layout())
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	var m := PlatformManager.get_safe_margins()
	_joy_center = Vector2(40.0 + m.left + JOY_RADIUS, s.y - 40.0 - m.bottom - JOY_RADIUS)
	_joy_knob = _joy_center
	var br := Vector2(s.x - 40.0 - m.right, s.y - 40.0 - m.bottom)
	_buttons[0].center = br + Vector2(-54.0, -54.0)
	_buttons[1].center = br + Vector2(-170.0, -34.0)
	_buttons[2].center = br + Vector2(-54.0, -180.0)
	queue_redraw()


func set_active(on: bool) -> void:
	visible = on
	if not on:
		_release_all()


func _release_all() -> void:
	_joy_touch = -1
	_look_touch = -1
	_joy_knob = _joy_center
	for b in _buttons:
		b.touch = -1
	InputManager.set_virtual_move(Vector2.ZERO)
	queue_redraw()


func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var p := _to_local(event.position)
		if event.pressed:
			if _try_press(event.index, p):
				get_viewport().set_input_as_handled()
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		var p2 := _to_local(event.position)
		if event.index == _joy_touch:
			_update_joy(p2)
			get_viewport().set_input_as_handled()
		elif event.index == _look_touch:
			InputManager.add_touch_look(event.relative)
			get_viewport().set_input_as_handled()


func _try_press(index: int, p: Vector2) -> bool:
	for b in _buttons:
		if p.distance_to(b.center) <= b.radius + 12.0:
			b.touch = index
			match b.id:
				"interact":
					InputManager.trigger("interact")
				"jump":
					InputManager.trigger("jump")
				"sprint":
					InputManager.set_sprint_toggle(not InputManager.is_sprint_toggled())
			queue_redraw()
			return true
	if _joy_touch == -1 and p.distance_to(_joy_center) <= JOY_RADIUS * 1.6:
		_joy_touch = index
		_update_joy(p)
		return true
	# camera look: anywhere on the right 60% of the screen not covered by UI
	if _look_touch == -1 and p.x > size.x * 0.4:
		_look_touch = index
		return false  # let UI underneath still receive the tap
	return false


func _release(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_joy_knob = _joy_center
		InputManager.set_virtual_move(Vector2.ZERO)
	if index == _look_touch:
		_look_touch = -1
	for b in _buttons:
		if b.touch == index:
			b.touch = -1
	queue_redraw()


func _update_joy(p: Vector2) -> void:
	var off := (p - _joy_center).limit_length(JOY_RADIUS)
	_joy_knob = _joy_center + off
	var v := off / JOY_RADIUS
	if v.length() < 0.12:
		v = Vector2.ZERO
	InputManager.set_virtual_move(v)
	queue_redraw()


func _draw() -> void:
	draw_circle(_joy_center, JOY_RADIUS, Color(0.05, 0.08, 0.12, 0.45))
	draw_arc(_joy_center, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(_joy_knob, KNOB_RADIUS, Color(0.12, 0.62, 1.0, 0.75 if _joy_touch >= 0 else 0.5))
	for b in _buttons:
		var pressed: bool = b.touch >= 0 or (b.id == "sprint" and InputManager.is_sprint_toggled())
		var col := Color(0.12, 0.62, 1.0, 0.8) if pressed else Color(0.05, 0.08, 0.12, 0.55)
		draw_circle(b.center, b.radius, col)
		draw_arc(b.center, b.radius, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
		var fs := 15 if b.radius > 40.0 else 12
		var tw := _font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, b.center + Vector2(-tw * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
