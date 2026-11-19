extends Control
## Pause menu. Pauses the SceneTree (simulation + player) while open.

signal resume_requested
signal dashboard_requested
signal settings_requested
signal tutorial_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UITheme.card(UITheme.BG, 22, 26.0)
	card.custom_minimum_size = Vector2(340, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UITheme.label("IoT SMART FARM SIMULATOR", 13, UITheme.ACCENT))
	v.add_child(UITheme.label("Paused", 32))
	var items := [["Resume", resume_requested], ["Smart Farm Dashboard", dashboard_requested], ["Settings", settings_requested], ["How to play", tutorial_requested]]
	for it in items:
		var b := UITheme.button(it[0])
		var sig: Signal = it[1]
		b.pressed.connect(func() -> void: sig.emit())
		v.add_child(b)
	if PlatformManager.can_quit():
		var q := UITheme.accent_button("Quit to desktop", UITheme.BAD)
		q.pressed.connect(func() -> void: get_tree().quit())
		v.add_child(q)
	var note := UITheme.label("A virtual IoT showcase inspired by smart-home platforms.\nNot affiliated with or endorsed by Samsung SmartThings.", 12, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 300
	v.add_child(note)
