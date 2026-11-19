extends Control
## Short introductory tutorial: controls, the three core farm scenarios and
## the climate / water / security / safety devices.

signal finished

var _page := 0
var _pages: Array = []
var _title: Label
var _body: Label
var _step: Label
var _next: Button
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UITheme.card(UITheme.BG, 22, 26.0)
	card.custom_minimum_size = Vector2(minf(560.0, PlatformManager.get_logical_size().x - 32.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	_step = UITheme.label("", 13, UITheme.ACCENT)
	v.add_child(_step)
	_title = UITheme.label("", 28)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_body = UITheme.label("", 17, UITheme.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 170)
	v.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var skip := UITheme.button("Skip")
	skip.pressed.connect(_finish)
	row.add_child(skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_back = UITheme.button("Back")
	_back.pressed.connect(func() -> void: _show(_page - 1))
	row.add_child(_back)
	_next = UITheme.accent_button("Next")
	_next.custom_minimum_size.x = 120
	_next.pressed.connect(func() -> void:
		if _page >= _pages.size() - 1:
			_finish()
		else:
			_show(_page + 1))
	row.add_child(_next)


func _build_pages() -> void:
	var touch := PlatformManager.touch_enabled
	var controls := ""
	if touch:
		controls = "Left joystick: walk\nDrag on the right side of the screen: rotate the camera\nINTERACT: inspect the highlighted device (or tap the prompt)\nSPRINT toggles running  ·  JUMP jumps\nDashboard / Menu buttons: top-right corner"
	else:
		controls = "WASD / arrow keys: walk   ·   Shift: sprint   ·   Space: jump\nClick the view, then move the mouse to look around (or hold right mouse button)\nE: inspect the highlighted device\nTab: Smart Farm Dashboard   ·   Esc: close panels / pause menu\nGamepads are supported too."
	_pages = [
		["Welcome to Green Valley Smart Farm", "This is an interactive showcase of a virtual IoT farm. Every sensor, plug, pump, fan and light is simulated inside the game - no real hardware or internet connection is needed.\n\nExplore the farm, inspect devices and watch automations control the 3D world."],
		["Controls", controls],
		["Scenario 1 - Smart Irrigation", "IF soil moisture drops below 30 %, the hub switches on the smart plug and the irrigation pump.\nWatch the sprinklers spray, water pulse through the pipes and the soil darken. Irrigation stops automatically at 65 %.\n\nThe pump and tank are west of the greenhouse; the moisture sensor sits in the greenhouse bed."],
		["Scenario 2 - Temperature Control", "IF the greenhouse gets hotter than 32 °C, the ventilation fans on the back wall start spinning. They switch off again below 28 °C.\n\nSunny afternoons heat the greenhouse naturally - or trigger a heat wave from the dashboard."],
		["Scenario 3 - Smart Lighting", "IF ambient light falls below 35 % (dusk), the greenhouse grow lights switch on. At dawn they switch off.\n\nTime passes quickly here: one full day lasts six minutes. Use the dashboard to jump straight to dusk."],
		["Climate, water, security & safety", "The farm also runs common smart-home devices: a heat-pump HVAC with thermostat and a motorised shade screen in the greenhouse, a smart water valve and leak sensor at the pump, and a door lock, contact sensor, motion sensor, floodlight and live camera at the shed. A smoke & CO alarm and a siren guard the control station.

Five more automations link them: sun shading, leak protection, security lighting, smoke alarm and night lockdown. Walk past the shed after dark and the floodlight reacts to you."],
		["The Smart Farm Dashboard", "Open it with %s. It shows live readings, every paired device grouped by category, all eight automation cards (enable / disable each one) and buttons to trigger each scenario.\n\nTip: disconnect a device from the hub to see how automations react to offline sensors." % ("the Dashboard button" if touch else "Tab")],
	]


func open() -> void:
	_build_pages()
	visible = true
	_show(0)


func _show(i: int) -> void:
	_page = clampi(i, 0, _pages.size() - 1)
	_step.text = "STEP %d OF %d" % [_page + 1, _pages.size()]
	_title.text = _pages[_page][0]
	_body.text = _pages[_page][1]
	_back.disabled = _page == 0
	_next.text = "Start exploring" if _page == _pages.size() - 1 else "Next"


func _finish() -> void:
	visible = false
	GameSettings.set_value("tutorial_seen", true)
	finished.emit()
