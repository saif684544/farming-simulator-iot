extends Node
## Detects the runtime platform (PC / mobile / web), decides whether touch
## controls are needed, keeps UI scaling responsive and forwards app lifecycle
## events (pause/resume, focus) to the rest of the game.

signal layout_changed(logical_size: Vector2, is_portrait: bool)
signal app_paused
signal app_resumed
signal focus_lost
signal focus_gained

enum Kind { PC, MOBILE, WEB }

const BASE_SIZE := Vector2(1280, 720)

var kind: Kind = Kind.PC
var is_mobile_device := false  ## true on native mobile and on mobile web browsers
var touch_enabled := false
var ui_scale := 1.0
var _forced_touch := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		kind = Kind.WEB
		is_mobile_device = OS.has_feature("web_android") or OS.has_feature("web_ios")
	elif OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		kind = Kind.MOBILE
		is_mobile_device = true
	else:
		kind = Kind.PC
	var args := OS.get_cmdline_user_args()
	_forced_touch = args.has("--touch")
	touch_enabled = is_mobile_device or _forced_touch
	if _forced_touch:
		Input.emulate_touch_from_mouse = true
	get_tree().root.size_changed.connect(_on_resized)
	_on_resized.call_deferred()


func platform_name() -> String:
	match kind:
		Kind.WEB:
			return "Web (mobile)" if is_mobile_device else "Web"
		Kind.MOBILE:
			return OS.get_name()
	return "PC (%s)" % OS.get_name()


func is_web() -> bool:
	return kind == Kind.WEB


func can_quit() -> bool:
	return kind == Kind.PC or OS.get_name() == "Android"


func set_touch_override(mode: String) -> void:
	## mode: "auto", "on", "off"
	match mode:
		"on":
			touch_enabled = true
		"off":
			touch_enabled = false
		_:
			touch_enabled = is_mobile_device or _forced_touch or (kind == Kind.WEB and DisplayServer.is_touchscreen_available())
	_on_resized()


func get_window_size() -> Vector2:
	return Vector2(get_tree().root.size)


func is_portrait() -> bool:
	var s := get_window_size()
	return s.y > s.x


## Logical (UI) size of the viewport after scaling.
func get_logical_size() -> Vector2:
	return get_tree().root.get_visible_rect().size


func _on_resized() -> void:
	var win := get_tree().root
	var s := Vector2(win.size)
	if s.x <= 0 or s.y <= 0:
		return
	# Scale UI by the short side of the window. Touch devices get a larger UI
	# so buttons stay comfortably tappable.
	var reference := 500.0 if touch_enabled else 720.0
	var desired := clampf(minf(s.x, s.y) / reference, 0.5, 3.0)
	var automatic := minf(s.x / BASE_SIZE.x, s.y / BASE_SIZE.y)
	ui_scale = desired
	win.content_scale_factor = desired / maxf(automatic, 0.01)
	layout_changed.emit(get_logical_size(), s.y > s.x)


## Safe-area margins (notches, rounded corners) in logical UI units.
func get_safe_margins() -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if kind != Kind.MOBILE:
		return out
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return out
	var k := get_logical_size().x / float(screen.x)
	out.left = safe.position.x * k
	out.top = safe.position.y * k
	out.right = (screen.x - safe.end.x) * k
	out.bottom = (screen.y - safe.end.y) * k
	return out


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED:
			app_resumed.emit()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			focus_lost.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			focus_gained.emit()
