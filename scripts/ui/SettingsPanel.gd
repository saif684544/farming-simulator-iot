extends VBoxContainer
## Settings tab: graphics preset, input sensitivity, audio, touch controls.

signal tutorial_requested

var _quality: OptionButton
var _touch: OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	theme = UITheme.get_theme()
	add_child(UITheme.label("GRAPHICS", 12, UITheme.MUTED))
	_quality = OptionButton.new()
	_quality.custom_minimum_size = Vector2(240, UITheme.MIN_TOUCH)
	_quality.focus_mode = Control.FOCUS_NONE
	for p in GameSettings.PRESETS:
		_quality.add_item(p.capitalize())
	_quality.selected = GameSettings.PRESETS.find(GameSettings.quality)
	_quality.item_selected.connect(func(i: int) -> void:
		AudioManager.play_ui("click")
		GameSettings.set_quality(GameSettings.PRESETS[i]))
	_row("Quality preset", _quality)
	var desc := UITheme.label("High: 4K shadow map, MSAA 4x, full grass and particles.  Medium: lighter shadows/effects.  Low: no real-time shadows, 75% render scale, reduced particles (best for phones and browsers).", 13, UITheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(desc)
	var fps := CheckButton.new()
	fps.text = "Show FPS counter"
	fps.button_pressed = GameSettings.show_fps
	fps.focus_mode = Control.FOCUS_NONE
	fps.custom_minimum_size.y = UITheme.MIN_TOUCH
	fps.toggled.connect(func(on: bool) -> void: GameSettings.set_value("show_fps", on))
	add_child(fps)

	add_child(UITheme.label("CONTROLS", 12, UITheme.MUTED))
	_row("Mouse sensitivity", _slider(0.2, 3.0, GameSettings.mouse_sensitivity, "mouse_sensitivity"))
	_row("Touch look sensitivity", _slider(0.2, 3.0, GameSettings.touch_sensitivity, "touch_sensitivity"))
	var inv := CheckButton.new()
	inv.text = "Invert camera Y axis"
	inv.button_pressed = GameSettings.invert_y
	inv.focus_mode = Control.FOCUS_NONE
	inv.custom_minimum_size.y = UITheme.MIN_TOUCH
	inv.toggled.connect(func(on: bool) -> void: GameSettings.set_value("invert_y", on))
	add_child(inv)
	_touch = OptionButton.new()
	_touch.custom_minimum_size = Vector2(240, UITheme.MIN_TOUCH)
	_touch.focus_mode = Control.FOCUS_NONE
	for t: String in ["Auto-detect", "Always show", "Hide"]:
		_touch.add_item(t)
	_touch.selected = ["auto", "on", "off"].find(GameSettings.touch_mode)
	_touch.item_selected.connect(func(i: int) -> void: GameSettings.set_value("touch_mode", ["auto", "on", "off"][i]))
	_row("On-screen touch controls", _touch)

	add_child(UITheme.label("AUDIO", 12, UITheme.MUTED))
	_row("Master volume", _slider(0.0, 1.0, GameSettings.master_volume, "master_volume"))

	add_child(UITheme.label("HELP", 12, UITheme.MUTED))
	var tut := UITheme.button("Show tutorial again")
	tut.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tut.pressed.connect(func() -> void: tutorial_requested.emit())
	add_child(tut)
	var info := UITheme.label("Platform: %s  ·  Renderer: Compatibility (OpenGL / WebGL 2)  ·  Godot %s" % [PlatformManager.platform_name(), Engine.get_version_info().string], 13, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	GameSettings.quality_changed.connect(func(p: String) -> void: _quality.selected = GameSettings.PRESETS.find(p))


func _row(title: String, control: Control) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 16)
	f.add_theme_constant_override("v_separation", 6)
	var l := UITheme.label(title, 16)
	l.custom_minimum_size = Vector2(220, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(l)
	f.add_child(control)
	add_child(f)


func _slider(lo: float, hi: float, value: float, key: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, UITheme.MIN_TOUCH * 0.7)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void: GameSettings.set_value(key, v))
	return s
