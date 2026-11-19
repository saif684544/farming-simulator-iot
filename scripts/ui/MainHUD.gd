extends Control
## Always-visible heads-up display: farm name + clock, live sensor chips,
## device connectivity, interaction prompt, automation toasts.

signal dashboard_requested
signal menu_requested
signal interact_requested

var _margin: MarginContainer
var _time_label: Label
var _phase_label: Label
var _chips := {}
var _prompt: Button
var _toasts: VBoxContainer
var _hint: Label
var _fps: Label
var _target: VirtualDevice
var _dash_btn: Button
var _menu_btn: Button
var _portrait := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(root)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(_build_farm_card())
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_END
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	top.add_child(flow)
	for key: String in ["temp", "soil", "light", "devices", "alerts"]:
		flow.add_child(_build_chip(key))
	_dash_btn = UITheme.accent_button("Dashboard")
	_dash_btn.pressed.connect(func() -> void: dashboard_requested.emit())
	flow.add_child(_dash_btn)
	_menu_btn = UITheme.button("Menu")
	_menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	flow.add_child(_menu_btn)

	var toast_row := CenterContainer.new()
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_row)
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	toast_row.add_child(_toasts)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	var bottom := CenterContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_prompt = Button.new()
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.custom_minimum_size = Vector2(0, 58)
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_stylebox_override("normal", UITheme.box(Color(0.07, 0.09, 0.12, 0.85), 30, 22.0, UITheme.ACCENT, 2))
	_prompt.add_theme_stylebox_override("hover", UITheme.box(Color(0.1, 0.14, 0.2, 0.9), 30, 22.0, UITheme.ACCENT, 2))
	_prompt.add_theme_stylebox_override("pressed", UITheme.box(UITheme.ACCENT.darkened(0.3), 30, 22.0, UITheme.ACCENT, 2))
	_prompt.visible = false
	_prompt.clip_text = true
	_prompt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_prompt.pressed.connect(func() -> void: interact_requested.emit())
	bottom.add_child(_prompt)

	_hint = UITheme.label("", 15, UITheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_stylebox_override("normal", UITheme.box(Color(0.07, 0.09, 0.12, 0.7), 14, 12.0))
	_hint.add_theme_color_override("font_color", UITheme.TEXT)
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_hint)

	_fps = UITheme.label("", 13, UITheme.MUTED)
	_fps.position = Vector2(8, 4)
	add_child(_fps)

	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	AutomationManager.rule_fired.connect(func(r: AutomationRule, msg: String) -> void: show_toast(msg, UITheme.BAD if r.id in ["smoke", "leak"] else UITheme.ACCENT))
	PlatformManager.layout_changed.connect(_on_layout)
	InputManager.mouse_capture_changed.connect(func(_c: bool) -> void: _update_hint())
	_on_layout(PlatformManager.get_logical_size(), PlatformManager.is_portrait())
	_refresh()


func _build_farm_card() -> Control:
	var card := UITheme.card(UITheme.BG, 16, 14.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.add_child(UITheme.dot(UITheme.GOOD, 9))
	name_row.add_child(UITheme.label("GREEN VALLEY SMART FARM", 13, UITheme.GOOD))
	v.add_child(name_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_time_label = UITheme.label("14:00", 34, UITheme.TEXT)
	row.add_child(_time_label)
	_phase_label = UITheme.label("Afternoon", 15, UITheme.MUTED)
	_phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_phase_label)
	return card


func _build_chip(key: String) -> Control:
	var titles := {"temp": "GREENHOUSE", "soil": "SOIL MOISTURE", "light": "AMBIENT LIGHT", "devices": "DEVICES", "alerts": "SECURITY"}
	var card := UITheme.card(UITheme.BG, 14, 12.0)
	card.custom_minimum_size = Vector2(128, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var d := UITheme.dot(UITheme.GOOD, 8)
	h.add_child(d)
	h.add_child(UITheme.label(titles[key], 11, UITheme.MUTED))
	v.add_child(h)
	var val := UITheme.label("--", 22, UITheme.TEXT)
	v.add_child(val)
	_chips[key] = {"value": val, "dot": d, "card": card}
	return card


func _set_chip(key: String, text: String, color: Color) -> void:
	var c: Dictionary = _chips[key]
	(c.value as Label).text = text
	UITheme.set_dot(c.dot as Panel, color)


func _refresh() -> void:
	_time_label.text = EnvironmentManager.format_time()
	_phase_label.text = EnvironmentManager.get_phase()
	var ts := DeviceManager.get_device("temp_sensor") as TemperatureSensor
	if ts and ts.online:
		_set_chip("temp", "%.1f °C" % ts.temperature, UITheme.BAD if ts.temperature > 32.0 else (UITheme.ACCENT if ts.temperature < 18.0 else UITheme.GOOD))
	else:
		_set_chip("temp", "Offline", UITheme.BAD)
	var ms := DeviceManager.get_device("soil_sensor") as MoistureSensor
	if ms and ms.online:
		var irrigating := DeviceManager.is_irrigating()
		_set_chip("soil", "%.0f %%%s" % [ms.moisture, " +" if irrigating else ""], UITheme.ACCENT if irrigating else (UITheme.WARN if ms.moisture < 30.0 else UITheme.GOOD))
	else:
		_set_chip("soil", "Offline", UITheme.BAD)
	var ls := DeviceManager.get_device("light_sensor") as LightSensor
	if ls and ls.online:
		_set_chip("light", "%.0f %%" % ls.light_level, UITheme.WARN if ls.light_level < 35.0 else UITheme.GOOD)
	else:
		_set_chip("light", "Offline", UITheme.BAD)
	var total := DeviceManager.get_device_count()
	var on := DeviceManager.get_online_count()
	var hub_ok := DeviceManager.is_hub_online()
	_set_chip("devices", "%d/%d online" % [on, total], UITheme.GOOD if on == total and hub_ok else UITheme.BAD)
	_refresh_alerts()
	_fps.visible = GameSettings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _target and is_instance_valid(_target):
		_prompt.text = _prompt_text(_target)
	_update_hint()


## Most important security/safety condition, SmartThings "Home Monitor" style.
func _refresh_alerts() -> void:
	var text := "All clear"
	var color := UITheme.GOOD
	var smoke := DeviceManager.get_device("smoke_detector") as SmokeDetector
	var leak := DeviceManager.get_device("leak_sensor") as LeakSensor
	var motion := DeviceManager.get_device("motion_sensor") as MotionSensor
	var lock := DeviceManager.get_device("shed_lock") as SmartLock
	if smoke and smoke.alarm:
		text = "SMOKE!"
		color = UITheme.BAD
	elif leak and leak.wet:
		text = "Water leak"
		color = UITheme.BAD
	elif motion and motion.motion:
		text = "Motion"
		color = UITheme.WARN
	elif lock and lock.door_open:
		text = "Shed open"
		color = UITheme.WARN
	elif lock and not lock.power_on:
		text = "Unlocked"
		color = UITheme.MUTED
	elif smoke == null and leak == null and motion == null and lock == null:
		text = "-"
		color = UITheme.MUTED
	_set_chip("alerts", text, color)
	# Narrow portrait screens: only show the security chip when it has news.
	(_chips.alerts.card as Control).visible = not _portrait or (color != UITheme.GOOD and text != "-")


func _prompt_text(d: VirtualDevice) -> String:
	var reading := d.get_primary_reading() if d.online else "OFFLINE"
	if PlatformManager.touch_enabled:
		return "Tap to inspect  %s  ·  %s" % [d.device_name, reading]
	return "[E]  Inspect  %s  ·  %s" % [d.device_name, reading]


func set_target(d: VirtualDevice) -> void:
	_target = d
	_prompt.visible = d != null
	if d:
		_prompt.text = _prompt_text(d)


func set_prompt_visible(v: bool) -> void:
	_prompt.visible = v and _target != null


func _update_hint() -> void:
	if PlatformManager.touch_enabled:
		_hint.text = ""
	elif not InputManager.is_mouse_captured() and InputManager.gameplay_enabled:
		_hint.text = "Click the view to look around  ·  WASD move  ·  Shift sprint  ·  E interact  ·  Tab dashboard  ·  Esc menu"
	else:
		_hint.text = ""
	_hint.visible = _hint.text != ""


func show_toast(text: String, color := UITheme.ACCENT) -> void:
	var card := UITheme.card(Color(0.07, 0.09, 0.12, 0.92), 22, 14.0)
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.09, 0.12, 0.92), 22, 14.0, color, 2))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	card.add_child(h)
	h.add_child(UITheme.dot(color, 10))
	h.add_child(UITheme.label(text, 16))
	_toasts.add_child(card)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).free()
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


func _on_layout(size: Vector2, portrait: bool) -> void:
	# Fixed prompt width bounded by the viewport so long device names never
	# push the HUD wider than a phone screen (text is ellipsised instead).
	_prompt.custom_minimum_size.x = minf(size.x - 40.0, 720.0)
	_portrait = portrait
	var m := PlatformManager.get_safe_margins()
	var pad := 12.0 if portrait else 18.0
	_margin.add_theme_constant_override("margin_left", int(pad + m.left))
	_margin.add_theme_constant_override("margin_right", int(pad + m.right))
	_margin.add_theme_constant_override("margin_top", int(pad + m.top))
	# leave room for the touch controls at the bottom
	var touch_room := 0.0
	if PlatformManager.touch_enabled:
		touch_room = 280.0 if portrait else 150.0
	var bottom: float = pad + m.bottom + touch_room
	_margin.add_theme_constant_override("margin_bottom", int(bottom))
	_dash_btn.text = "Dashboard" if PlatformManager.touch_enabled else "Dashboard  [Tab]"
	_menu_btn.text = "Menu" if PlatformManager.touch_enabled else "Menu  [Esc]"
