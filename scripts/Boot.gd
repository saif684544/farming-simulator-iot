extends Control
## Loading screen. Loads Main.tscn in the background with visible progress,
## then shows "Building farm..." while the procedural world is generated.
## (On the web, Godot's HTML shell shows engine download progress before this.)

const MAIN_SCENE := "res://scenes/Main.tscn"

var _bar: ProgressBar
var _status: Label
var _started := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(minf(460.0, PlatformManager.get_logical_size().x - 40.0), 0)
	center.add_child(v)
	var cap := UITheme.label("GREEN VALLEY", 14, UITheme.GOOD)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var title := UITheme.label("IoT Smart Farm Simulator", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.show_percentage = false
	v.add_child(_bar)
	_status = UITheme.label("Loading...", 15, UITheme.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var note := UITheme.label("All IoT devices are simulated - no hardware or internet required.", 13, UITheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	_started = true


func _process(_delta: float) -> void:
	if not _started:
		return
	var progress := []
	var st := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
	match st:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = (progress[0] if progress.size() > 0 else 0.0) * 80.0
			_status.text = "Loading resources...  %d%%" % int(_bar.value)
		ResourceLoader.THREAD_LOAD_LOADED:
			_started = false
			_bar.value = 85.0
			_status.text = "Building the farm..."
			_finish.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_started = false
			_status.text = "Failed to load the main scene."
			push_error("Boot: failed to load %s" % MAIN_SCENE)


func _finish() -> void:
	# give the "Building" label two frames to render before the heavy build
	await get_tree().process_frame
	await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
	get_tree().change_scene_to_packed(packed)
