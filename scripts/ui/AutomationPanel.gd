extends VBoxContainer
## Automation cards: name, IF trigger, THEN action, live execution status,
## enable/disable toggle and a "run scenario" button that pushes the simulation
## into the triggering condition.

signal scenario_triggered(message: String)

var _cards := {}  ## rule id -> {status pill, toggle, last label}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	theme = UITheme.get_theme()
	for r in AutomationManager.rules:
		add_child(_build_card(r))
	AutomationManager.rule_updated.connect(_update_rule)
	refresh()


func _build_card(r: AutomationRule) -> Control:
	var card := UITheme.card(UITheme.CARD, 16, 16.0)
	card.name = "Rule_" + r.id
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	tv.add_child(UITheme.label("AUTOMATION", 11, UITheme.ACCENT))
	tv.add_child(UITheme.label(r.name, 21))
	var toggle := CheckButton.new()
	toggle.text = "Enabled"
	toggle.button_pressed = r.enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.custom_minimum_size = Vector2(0, UITheme.MIN_TOUCH)
	toggle.name = "Toggle"
	var rid := r.id
	toggle.toggled.connect(func(on: bool) -> void:
		AudioManager.play_ui("click")
		AutomationManager.set_rule_enabled(rid, on))
	head.add_child(toggle)

	var desc := UITheme.label(r.description, 14, UITheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	flow.add_child(_clause("IF", r.trigger_text, UITheme.WARN))
	flow.add_child(_clause("THEN", r.action_text, UITheme.ACCENT))

	var foot := HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 10)
	foot.add_theme_constant_override("v_separation", 8)
	v.add_child(foot)
	var pill := UITheme.pill(r.status, UITheme.GOOD)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(pill)
	var run := UITheme.button("Run scenario")
	run.name = "RunScenario"
	run.pressed.connect(func() -> void: scenario_triggered.emit(AutomationManager.trigger_scenario(rid)))
	foot.add_child(run)
	var last := UITheme.label("Last event: -", 13, UITheme.MUTED)
	last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(last)
	_cards[r.id] = {"pill": pill, "toggle": toggle, "last": last}
	return card


func _clause(tag: String, text: String, color: Color) -> Control:
	var p := UITheme.card(Color(color, 0.12), 10, 10.0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UITheme.label(tag, 13, color, true))
	h.add_child(UITheme.label(text, 15))
	return p


func _update_rule(r: AutomationRule) -> void:
	if not _cards.has(r.id):
		return
	var c: Dictionary = _cards[r.id]
	UITheme.set_pill(c.pill, "Status: " + r.status, UITheme.status_color(r.status))
	(c.toggle as CheckButton).set_pressed_no_signal(r.enabled)
	(c.last as Label).text = "Last event: %s   (triggered %d×)" % [r.last_event, r.fire_count]


func refresh() -> void:
	for r in AutomationManager.rules:
		_update_rule(r)
