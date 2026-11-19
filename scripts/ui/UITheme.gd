class_name UITheme
extends RefCounted
## Smart-home dashboard look: dark translucent cards, rounded corners,
## blue accent. Built in code so every UI scene shares one Theme resource.

const BG := Color(0.07, 0.09, 0.12, 0.88)
const CARD := Color(0.11, 0.14, 0.19, 0.92)
const CARD_HI := Color(0.15, 0.19, 0.26, 0.95)
const ACCENT := Color(0.12, 0.62, 1.0)
const GOOD := Color(0.25, 0.85, 0.45)
const WARN := Color(0.98, 0.72, 0.2)
const BAD := Color(0.95, 0.3, 0.25)
const TEXT := Color(0.93, 0.95, 0.98)
const MUTED := Color(0.62, 0.68, 0.76)
const MIN_TOUCH := 52.0

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func box(color: Color, radius := 14, pad := 12.0, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.75
	s.content_margin_bottom = pad * 0.75
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(CARD, 16, 14.0))
	t.set_stylebox("panel", "Panel", box(CARD, 16, 14.0))
	# buttons
	t.set_stylebox("normal", "Button", box(Color(0.18, 0.22, 0.29), 12, 14.0))
	t.set_stylebox("hover", "Button", box(Color(0.23, 0.29, 0.38), 12, 14.0))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.2), 12, 14.0))
	t.set_stylebox("hover_pressed", "Button", box(ACCENT.darkened(0.1), 12, 14.0))
	t.set_stylebox("disabled", "Button", box(Color(0.14, 0.16, 0.2, 0.7), 12, 14.0))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, 14.0, ACCENT, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_constant("h_separation", "Button", 8)
	# check buttons (toggles)
	for k: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "CheckButton", box(Color(0, 0, 0, 0), 8, 6.0))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	# option button
	t.set_stylebox("normal", "OptionButton", box(Color(0.18, 0.22, 0.29), 12, 14.0))
	t.set_stylebox("hover", "OptionButton", box(Color(0.23, 0.29, 0.38), 12, 14.0))
	t.set_stylebox("pressed", "OptionButton", box(ACCENT.darkened(0.2), 12, 14.0))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), 12, 14.0, ACCENT, 2))
	t.set_stylebox("panel", "PopupMenu", box(Color(0.12, 0.15, 0.2, 0.98), 10, 8.0))
	t.set_font_size("font_size", "PopupMenu", 18)
	# progress bar
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), 6, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 6, 0.0))
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	# slider
	var grab := box(Color(1, 1, 1, 0.12), 4, 0.0)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", grab)
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 4, 0.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), 4, 0.0))
	# tabs
	t.set_stylebox("tab_selected", "TabContainer", box(ACCENT.darkened(0.15), 10, 14.0))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.15, 0.18, 0.24), 10, 14.0))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.2, 0.25, 0.33), 10, 14.0))
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), 0, 4.0))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_constant("side_margin", "TabContainer", 0)
	t.set_font_size("font_size", "TabContainer", 18)
	# scroll bars a bit wider for touch
	var sb := box(Color(1, 1, 1, 0.05), 6, 0.0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.25), 6, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.4), 6, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, 6, 0.0))
	t.set_stylebox("separator", "HSeparator", box(Color(1, 1, 1, 0.08), 0, 0.0))
	t.set_constant("separation", "HSeparator", 10)
	return t


# ----------------------------------------------------------- factories ---

static func label(text: String, size := 17, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", color)
	return l


static func button(text: String, min_h := MIN_TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: AudioManager.play_ui("click"))
	return b


static func accent_button(text: String, color := ACCENT) -> Button:
	var b := button(text)
	b.add_theme_stylebox_override("normal", box(color.darkened(0.25), 12, 14.0))
	b.add_theme_stylebox_override("hover", box(color.darkened(0.1), 12, 14.0))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.4), 12, 14.0))
	return b


## Small rounded status chip: coloured dot + text.
static func pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(color, 0.18), 20, 10.0, Color(color, 0.6), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(dot(color))
	var l := label(text, 14, TEXT)
	l.name = "Text"
	h.add_child(l)
	return p


static func set_pill(p: PanelContainer, text: String, color: Color) -> void:
	p.add_theme_stylebox_override("panel", box(Color(color, 0.18), 20, 10.0, Color(color, 0.6), 1))
	var h := p.get_child(0)
	set_dot(h.get_node("Dot") as Panel, color)
	(h.get_node("Text") as Label).text = text


static func dot(color: Color, size := 10.0) -> Panel:
	var d := Panel.new()
	d.name = "Dot"
	d.custom_minimum_size = Vector2(size, size)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_dot(d, color)
	return d


static func set_dot(d: Panel, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(d.custom_minimum_size.x))
	s.anti_aliasing = true
	d.add_theme_stylebox_override("panel", s)


static func card(color := CARD, radius := 16, pad := 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, pad))
	return p


static func status_color(text: String) -> Color:
	var t := text.to_lower()
	if t.begins_with("disabled") or t.begins_with("off") or t.contains("offline") or t.begins_with("paused") or t.begins_with("waiting") or t.contains("no power") or t.contains("missing") or t.contains("powered off"):
		return BAD if (t.contains("offline") or t.contains("missing")) else (WARN if not t.begins_with("off") else MUTED)
	if t.begins_with("active") or t.begins_with("running") or t.begins_with("on"):
		return ACCENT
	return GOOD
