extends Control
## Smart Farm Dashboard (TAB). Tabs: Overview, Devices, Automations, Settings.
## Every value shown is read from the live simulation (DeviceManager /
## AutomationManager / EnvironmentManager), refreshed 4x per second.

signal closed
signal tutorial_requested

const AutomationPanelScript := preload("res://scripts/ui/AutomationPanel.gd")
const SettingsPanelScript := preload("res://scripts/ui/SettingsPanel.gd")
const EQUIPMENT := ["irrigation_pump", "smart_plug", "water_valve", "vent_fan", "hvac", "greenhouse_shade", "greenhouse_lights"]
const SECURITY := ["shed_lock", "door_contact", "motion_sensor", "floodlight", "security_camera", "leak_sensor", "smoke_detector", "siren"]
const SCENARIOS := [
	["Simulate dry soil", "irrigation", "ACCENT"], ["Simulate heat wave", "temperature", "BAD"],
	["Jump to dusk", "lighting", "WARN"], ["Jump to midday", "daytime", "GOOD"],
	["Midday sun (shade)", "shading", "WARN"], ["Burst pipe fitting", "leak", "ACCENT"],
	["Night intruder", "security_light", "WARN"], ["Smoke in cabinet", "smoke", "BAD"],
	["Shed left open at dusk", "lockdown", "WARN"],
]

var tabs: TabContainer
var _panel: PanelContainer
var _status := {}
var _tiles := {}
var _device_cards := {}
var _card_ids: Array = []
var _devices_flow: VBoxContainer
var _automation_panel: VBoxContainer
var _timer: Timer
var _scenario_msg: Label
var _speed_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = UITheme.card(Color(0.07, 0.09, 0.12, 0.96), 22, 18.0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)

	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	tv.add_child(UITheme.label("SMART FARM DASHBOARD", 13, UITheme.ACCENT))
	var t := UITheme.label("Green Valley Smart Farm", 26)
	t.clip_text = true
	tv.add_child(t)
	var sub := UITheme.label("SmartThings-inspired virtual hub  ·  all devices are simulated in-game", 13, UITheme.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	var close := UITheme.button("Close")
	close.custom_minimum_size = Vector2(96, UITheme.MIN_TOUCH)
	close.pressed.connect(close_dashboard)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(close)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_focus_mode = Control.FOCUS_NONE
	tabs.tab_changed.connect(func(_i: int) -> void: AudioManager.play_ui("click"))
	v.add_child(tabs)
	tabs.add_child(_scroll("Overview", _build_overview()))
	tabs.add_child(_scroll("Devices", _build_devices()))
	_automation_panel = AutomationPanelScript.new()
	_automation_panel.scenario_triggered.connect(_on_scenario)
	tabs.add_child(_scroll("Automations", _automation_panel))
	var settings: VBoxContainer = SettingsPanelScript.new()
	settings.tutorial_requested.connect(func() -> void: tutorial_requested.emit())
	tabs.add_child(_scroll("Settings", settings))

	_timer = Timer.new()
	_timer.wait_time = 0.25
	_timer.timeout.connect(refresh)
	add_child(_timer)
	DeviceManager.device_state_changed.connect(func(_d: VirtualDevice) -> void:
		if visible:
			refresh())
	PlatformManager.layout_changed.connect(_on_layout)
	_on_layout(PlatformManager.get_logical_size(), PlatformManager.is_portrait())


func _scroll(title: String, content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.name = title
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	s.add_child(m)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(content)
	return s


# -------------------------------------------------------------- overview ---

func _section(parent: Control, title: String) -> void:
	var l := UITheme.label(title, 12, UITheme.MUTED)
	parent.add_child(l)


func _build_overview() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_section(v, "SYSTEM STATUS")
	var sflow := HFlowContainer.new()
	sflow.add_theme_constant_override("h_separation", 8)
	sflow.add_theme_constant_override("v_separation", 8)
	v.add_child(sflow)
	for k: String in ["hub", "devices", "automations", "time", "platform"]:
		var p := UITheme.pill("-", UITheme.GOOD)
		sflow.add_child(p)
		_status[k] = p

	_section(v, "SENSOR READINGS")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	v.add_child(flow)
	flow.add_child(_tile("soil", "Soil moisture", "Irrigation starts < 30 %, stops at 65 %"))
	flow.add_child(_tile("temp", "Greenhouse temperature", "Fans on > 32 °C, off < 28 °C"))
	flow.add_child(_tile("light", "Ambient light", "Grow lights on < 35 %, off at 40 %"))
	flow.add_child(_tile("humidity", "Greenhouse humidity", "Rises while irrigating"))

	for group in [["ACTIVE EQUIPMENT", EQUIPMENT], ["SECURITY & SAFETY", SECURITY]]:
		_section(v, group[0])
		var eflow := HFlowContainer.new()
		eflow.add_theme_constant_override("h_separation", 8)
		eflow.add_theme_constant_override("v_separation", 8)
		v.add_child(eflow)
		for k: String in group[1]:
			var p2 := UITheme.pill("-", UITheme.GOOD)
			p2.name = "Eq_" + k
			eflow.add_child(p2)
			_status["eq_" + k] = p2

	_section(v, "TRIGGER SCENARIOS")
	var sc := HFlowContainer.new()
	sc.add_theme_constant_override("h_separation", 10)
	sc.add_theme_constant_override("v_separation", 10)
	v.add_child(sc)
	var colors := {"ACCENT": UITheme.ACCENT, "BAD": UITheme.BAD, "WARN": UITheme.WARN, "GOOD": UITheme.GOOD}
	for item in SCENARIOS:
		var b := UITheme.accent_button(item[0], colors[item[2]])
		var sid: String = item[1]
		b.name = "Scenario_" + sid
		b.pressed.connect(func() -> void: _on_scenario(AutomationManager.trigger_scenario(sid)))
		sc.add_child(b)
	_scenario_msg = UITheme.label("", 14, UITheme.ACCENT)
	v.add_child(_scenario_msg)

	_section(v, "SIMULATION SPEED")
	var sp := HFlowContainer.new()
	sp.add_theme_constant_override("h_separation", 8)
	v.add_child(sp)
	for s in [[0.0, "Pause time"], [1.0, "1x"], [4.0, "4x"], [12.0, "12x"]]:
		var b2 := UITheme.button(s[1])
		b2.custom_minimum_size.x = 84
		var spd: float = s[0]
		b2.pressed.connect(func() -> void:
			EnvironmentManager.set_time_speed(spd)
			refresh())
		sp.add_child(b2)
		_speed_buttons[spd] = b2
	return v


func _tile(key: String, title: String, hint: String) -> Control:
	var card := UITheme.card(UITheme.CARD, 16, 16.0)
	card.custom_minimum_size = Vector2(250, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	v.add_child(UITheme.label(title.to_upper(), 12, UITheme.MUTED))
	var val := UITheme.label("--", 34)
	v.add_child(val)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	v.add_child(bar)
	var h := UITheme.label(hint, 13, UITheme.MUTED)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	_tiles[key] = {"value": val, "bar": bar}
	return card


func _set_tile(key: String, text: String, ratio: float, color: Color) -> void:
	var t: Dictionary = _tiles[key]
	(t.value as Label).text = text
	var bar := t.bar as ProgressBar
	bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	bar.add_theme_stylebox_override("fill", UITheme.box(color, 6, 0.0))


# --------------------------------------------------------------- devices ---

func _build_devices() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_section(v, "PAIRED DEVICES  ·  switch devices or simulate connection loss")
	_devices_flow = VBoxContainer.new()
	_devices_flow.add_theme_constant_override("separation", 10)
	v.add_child(_devices_flow)
	return v


func _rebuild_device_cards() -> void:
	var devs := DeviceManager.get_all_devices()
	var ids := devs.map(func(d: VirtualDevice) -> String: return d.device_id)
	if ids == _card_ids:
		return
	_card_ids = ids
	for c in _devices_flow.get_children():
		c.free()
	_device_cards.clear()
	var cats: Array = VirtualDevice.CATEGORIES.duplicate()
	for d in devs:
		if not d.category in cats:
			cats.append(d.category)
	for cat: String in cats:
		var members := devs.filter(func(d: VirtualDevice) -> bool: return d.category == cat)
		if members.is_empty():
			continue
		_devices_flow.add_child(UITheme.label("%s  (%d)" % [cat.to_upper(), members.size()], 13, UITheme.ACCENT))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		_devices_flow.add_child(flow)
		for d in members:
			flow.add_child(_device_card(d))


func _device_card(d: VirtualDevice) -> Control:
	var card := UITheme.card(UITheme.CARD, 16, 14.0)
	card.name = "Card_" + d.device_id
	card.custom_minimum_size = Vector2(290, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(UITheme.label(d.device_type.to_upper(), 11, UITheme.ACCENT))
	v.add_child(UITheme.label(d.device_name, 19))
	var pill := UITheme.pill("-", UITheme.GOOD)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(pill)
	var reading := UITheme.label("-", 16, UITheme.TEXT)
	v.add_child(reading)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var power: Button = null
	if d.is_controllable():
		power = UITheme.button("Power")
		power.name = "Power"
		power.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		power.pressed.connect(func() -> void: d.perform_control("power", not d.power_on))
		h.add_child(power)
	var conn := UITheme.button("Connection")
	conn.name = "Connection"
	conn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conn.pressed.connect(func() -> void: d.perform_control("connection", not d.online))
	h.add_child(conn)
	_device_cards[d.device_id] = {"pill": pill, "reading": reading, "power": power, "conn": conn, "device": d}
	return card


func _refresh_device_cards() -> void:
	for id in _device_cards:
		var c: Dictionary = _device_cards[id]
		var d: VirtualDevice = c.device
		if not is_instance_valid(d):
			continue
		UITheme.set_pill(c.pill, d.get_status_text(), d.get_status_color())
		(c.reading as Label).text = d.get_primary_reading() if d.online else "No data (offline)"
		if c.power:
			var pb := c.power as Button
			pb.text = d.get_power_action_text(not d.power_on)
			pb.disabled = not d.online
			pb.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT.darkened(0.25) if d.power_on else Color(0.18, 0.22, 0.29), 12, 14.0))
		var cb := c.conn as Button
		cb.text = "Disconnect" if d.online else "Reconnect"
		cb.add_theme_stylebox_override("normal", UITheme.box(Color(0.18, 0.22, 0.29) if d.online else UITheme.BAD.darkened(0.3), 12, 14.0))


# ---------------------------------------------------------------- common ---

func open(tab := -1) -> void:
	visible = true
	if tab >= 0:
		tabs.current_tab = tab
	_rebuild_device_cards()
	refresh()
	_timer.start()
	AudioManager.play_ui("click")


func close_dashboard() -> void:
	if not visible:
		return
	visible = false
	_timer.stop()
	closed.emit()


func refresh() -> void:
	if not visible:
		return
	var hub := DeviceManager.get_device("hub") as VirtualHub
	if hub:
		UITheme.set_pill(_status.hub, "Hub: " + hub.get_status_text(), hub.get_status_color() if hub.is_running() else UITheme.BAD)
	var on := DeviceManager.get_online_count()
	var total := DeviceManager.get_device_count()
	UITheme.set_pill(_status.devices, "%d / %d devices online" % [on, total], UITheme.GOOD if on == total else UITheme.BAD)
	UITheme.set_pill(_status.automations, "%d / %d automations enabled" % [AutomationManager.get_enabled_count(), AutomationManager.rules.size()], UITheme.GOOD)
	var spd := EnvironmentManager.time_speed
	UITheme.set_pill(_status.time, "%s  %s  ·  %s" % [EnvironmentManager.format_time(), EnvironmentManager.get_phase(), "time paused" if spd == 0.0 else "%sx speed" % str(spd)], UITheme.ACCENT)
	UITheme.set_pill(_status.platform, "%s  ·  %s quality" % [PlatformManager.platform_name(), GameSettings.quality.capitalize()], UITheme.MUTED)

	var ms := DeviceManager.get_device("soil_sensor") as MoistureSensor
	if ms:
		_set_tile("soil", ("%.1f %%" % ms.moisture) if ms.online else "Offline", ms.moisture / 100.0, UITheme.WARN if ms.moisture < 30.0 else UITheme.ACCENT)
	var ts := DeviceManager.get_device("temp_sensor") as TemperatureSensor
	if ts:
		_set_tile("temp", ("%.1f °C" % ts.temperature) if ts.online else "Offline", (ts.temperature - 10.0) / 30.0, UITheme.BAD if ts.temperature > 32.0 else UITheme.GOOD)
		_set_tile("humidity", ("%.0f %%" % ts.humidity) if ts.online else "Offline", ts.humidity / 100.0, UITheme.ACCENT)
	var ls := DeviceManager.get_device("light_sensor") as LightSensor
	if ls:
		_set_tile("light", ("%.0f %%" % ls.light_level) if ls.online else "Offline", ls.light_level / 100.0, UITheme.WARN if ls.light_level < 35.0 else UITheme.GOOD)
	for k: String in EQUIPMENT + SECURITY:
		var d := DeviceManager.get_device(k)
		var pill: Control = _status["eq_" + k]
		pill.visible = d != null
		if d:
			UITheme.set_pill(pill, "%s: %s" % [d.device_name, d.get_status_text()], d.get_status_color())
	for s in _speed_buttons:
		(_speed_buttons[s] as Button).add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT.darkened(0.25) if is_equal_approx(s, spd) else Color(0.18, 0.22, 0.29), 12, 14.0))
	_rebuild_device_cards()
	_refresh_device_cards()
	_automation_panel.refresh()


func _on_scenario(msg: String) -> void:
	if msg.is_empty():
		return
	_scenario_msg.text = msg + "  -  close the dashboard to watch the farm respond."
	refresh()


func _on_layout(_size: Vector2, portrait: bool) -> void:
	var m := PlatformManager.get_safe_margins()
	var pad := 8.0 if portrait else 28.0
	_panel.offset_left = pad + m.left
	_panel.offset_right = -pad - m.right
	_panel.offset_top = pad + m.top
	_panel.offset_bottom = -pad - m.bottom
