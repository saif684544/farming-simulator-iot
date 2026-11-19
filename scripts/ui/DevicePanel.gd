extends Control
## Device inspection panel. Generic: renders any VirtualDevice through its
## get_readings()/get_controls() API, refreshing live while open.

signal closed

var device: VirtualDevice
var _card: PanelContainer
var _title: Label
var _type: Label
var _pill: PanelContainer
var _readings: GridContainer
var _controls: VBoxContainer
var _footer: Label
var _preview_box: VBoxContainer
var _preview: TextureRect
var _preview_caption: Label
var _refresh_timer: Timer
var _rebuild_pending := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()
	visible = false
	_card = UITheme.card(UITheme.BG, 20, 18.0)
	add_child(_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	_type = UITheme.label("DEVICE", 12, UITheme.ACCENT)
	tv.add_child(_type)
	_title = UITheme.label("Device", 24)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_title)
	var close := UITheme.button("✕", UITheme.MIN_TOUCH)
	close.text = "X"
	close.custom_minimum_size = Vector2(UITheme.MIN_TOUCH, UITheme.MIN_TOUCH)
	close.pressed.connect(close_panel)
	head.add_child(close)

	_pill = UITheme.pill("Online", UITheme.GOOD)
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_pill)
	# live feed (security camera)
	_preview_box = VBoxContainer.new()
	_preview_box.add_theme_constant_override("separation", 4)
	_preview_box.visible = false
	v.add_child(_preview_box)
	var frame := UITheme.card(Color(0, 0, 0, 1), 10, 4.0)
	_preview_box.add_child(frame)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(0, 200)
	frame.add_child(_preview)
	_preview_caption = UITheme.label("", 13, UITheme.MUTED)
	_preview_box.add_child(_preview_caption)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.label("LIVE STATUS", 12, UITheme.MUTED))
	_readings = GridContainer.new()
	_readings.columns = 2
	_readings.add_theme_constant_override("h_separation", 16)
	_readings.add_theme_constant_override("v_separation", 6)
	v.add_child(_readings)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.label("CONTROLS", 12, UITheme.MUTED))
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 8)
	v.add_child(_controls)
	_footer = UITheme.label("", 13, UITheme.MUTED)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_footer)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.25
	_refresh_timer.timeout.connect(_refresh_readings)
	add_child(_refresh_timer)
	PlatformManager.layout_changed.connect(_on_layout)
	_on_layout(PlatformManager.get_logical_size(), PlatformManager.is_portrait())


func open(d: VirtualDevice) -> void:
	if device and is_instance_valid(device):
		device.set_preview_active(false)
		if device.state_changed.is_connected(_on_state):
			device.state_changed.disconnect(_on_state)
	device = d
	device.set_preview_active(true)
	device.state_changed.connect(_on_state)
	visible = true
	_footer.text = "Tap X to close" if PlatformManager.touch_enabled else "Press E or Esc to close"
	_on_state(d)
	_refresh_timer.start()
	AudioManager.play_ui("click")


func close_panel() -> void:
	if not visible:
		return
	if device and is_instance_valid(device):
		device.set_preview_active(false)
		if device.state_changed.is_connected(_on_state):
			device.state_changed.disconnect(_on_state)
	device = null
	visible = false
	_refresh_timer.stop()
	closed.emit()


func _on_state(_d: VirtualDevice) -> void:
	if device == null:
		return
	_title.text = device.device_name
	_type.text = device.device_type.to_upper()
	UITheme.set_pill(_pill, device.get_status_text(), device.get_status_color())
	# Deferred: the state change may originate from one of our own buttons,
	# which must not be freed while its pressed signal is being emitted.
	if not _rebuild_pending:
		_rebuild_pending = true
		_rebuild_controls.call_deferred()
	_refresh_readings()


func _refresh_readings() -> void:
	if device == null or not is_instance_valid(device):
		return
	UITheme.set_pill(_pill, device.get_status_text(), device.get_status_color())
	_refresh_preview()
	var rows: Array = device.get_readings()
	if not device.online:
		rows = [["Status", "No connection to hub"], ["Last reading", device.get_primary_reading()]]
	if _readings.get_child_count() != rows.size() * 2:
		for c in _readings.get_children():
			c.free()
		for r in rows:
			var k := UITheme.label(str(r[0]), 15, UITheme.MUTED)
			_readings.add_child(k)
			var val := UITheme.label(str(r[1]), 16)
			val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_readings.add_child(val)
	for i in rows.size():
		(_readings.get_child(i * 2) as Label).text = str(rows[i][0])
		(_readings.get_child(i * 2 + 1) as Label).text = str(rows[i][1])


func _rebuild_controls() -> void:
	_rebuild_pending = false
	if device == null or not is_instance_valid(device):
		return
	for c in _controls.get_children():
		_controls.remove_child(c)
		c.queue_free()
	for ctl in device.get_controls():
		var b: Button
		if ctl.kind == "choice":
			_controls.add_child(_choice_row(ctl))
			continue
		if ctl.kind == "stepper":
			_controls.add_child(_stepper_row(ctl))
			continue
		if ctl.kind == "toggle":
			var on: bool = ctl.value
			var state: String = ctl.get("on_text", "ON") if on else ctl.get("off_text", "OFF")
			b = UITheme.accent_button("%s:  %s" % [ctl.label, state], UITheme.ACCENT if on else Color(0.3, 0.34, 0.42))
			if ctl.id == "connection":
				b.text = "Connected  -  tap to disconnect" if on else "Disconnected  -  tap to reconnect"
				if not on:
					b = UITheme.accent_button(b.text, UITheme.BAD)
			var id: String = ctl.id
			b.pressed.connect(func() -> void: device.perform_control(id, not on))
		else:
			b = UITheme.button(ctl.label)
			var id2: String = ctl.id
			b.pressed.connect(func() -> void: device.perform_control(id2))
		b.disabled = not ctl.get("enabled", true)
		b.name = "Ctl_" + str(ctl.id)
		_controls.add_child(b)
	if device.is_controllable() and not device.online:
		_controls.add_child(UITheme.label("Device is offline - reconnect it to send commands.", 13, UITheme.WARN))


func _refresh_preview() -> void:
	var tex := device.get_preview_texture()
	var wants := device.has_method("set_preview_active") and device is SecurityCamera
	_preview_box.visible = wants
	if not wants:
		return
	_preview.texture = tex
	if tex == null:
		_preview_caption.text = "No signal - camera %s" % ("offline" if not device.online else "disabled")
	else:
		_preview_caption.text = "LIVE  ·  %s  ·  %s" % [EnvironmentManager.format_time(), device.get_primary_reading()]


## Segmented picker, e.g. thermostat mode Heat / Cool / Auto.
func _choice_row(ctl: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.name = "Ctl_" + str(ctl.id)
	v.add_child(UITheme.label(str(ctl.label), 14, UITheme.MUTED))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var id: String = ctl.id
	for opt in ctl.options:
		var selected: bool = str(opt) == str(ctl.value)
		var b := UITheme.accent_button(str(opt), UITheme.ACCENT if selected else Color(0.3, 0.34, 0.42))
		b.name = "Opt_" + str(opt)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not ctl.get("enabled", true)
		var value := str(opt)
		b.pressed.connect(func() -> void: device.perform_control(id, value))
		h.add_child(b)
	return v


## Label + [-] value [+] row, e.g. thermostat setpoints.
func _stepper_row(ctl: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.name = "Ctl_" + str(ctl.id)
	var l := UITheme.label(str(ctl.label), 15, UITheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var id: String = ctl.id
	var value: float = ctl.value
	var step: float = ctl.get("step", 1.0)
	var enabled: bool = ctl.get("enabled", true)
	var minus := UITheme.button("-")
	minus.name = "Minus"
	minus.custom_minimum_size = Vector2(UITheme.MIN_TOUCH, UITheme.MIN_TOUCH)
	minus.disabled = not enabled or value <= float(ctl.get("min", -INF))
	minus.pressed.connect(func() -> void: device.perform_control(id, value - step))
	h.add_child(minus)
	var val := UITheme.label("%s %s" % [str(snappedf(value, 0.1)).trim_suffix(".0"), ctl.get("unit", "")], 18)
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(val)
	var plus := UITheme.button("+")
	plus.name = "Plus"
	plus.custom_minimum_size = Vector2(UITheme.MIN_TOUCH, UITheme.MIN_TOUCH)
	plus.disabled = not enabled or value >= float(ctl.get("max", INF))
	plus.pressed.connect(func() -> void: device.perform_control(id, value + step))
	h.add_child(plus)
	return h


func _on_layout(size: Vector2, portrait: bool) -> void:
	var m := PlatformManager.get_safe_margins()
	if portrait or size.x < 820.0:
		_card.anchor_left = 0.0
		_card.anchor_right = 1.0
		_card.anchor_top = 0.42
		_card.anchor_bottom = 1.0
		_card.offset_left = 10.0 + m.left
		_card.offset_right = -10.0 - m.right
		_card.offset_top = 0.0
		_card.offset_bottom = -10.0 - m.bottom
	else:
		_card.anchor_left = 1.0
		_card.anchor_right = 1.0
		_card.anchor_top = 0.0
		_card.anchor_bottom = 1.0
		_card.offset_left = -430.0 - m.right
		_card.offset_right = -18.0 - m.right
		_card.offset_top = 175.0 if size.x < 1150.0 else 125.0
		_card.offset_bottom = -18.0 - m.bottom
