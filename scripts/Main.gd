extends Node3D
## Top-level game flow: wires the player, HUD, panels and input together and
## manages which UI layer currently owns input (play / device panel /
## dashboard / pause / tutorial).

enum UIState { PLAY, DEVICE, DASHBOARD, PAUSE, TUTORIAL }

@onready var player: PlayerController = $Player
@onready var ui: CanvasLayer = $UI
@onready var hud: Control = $UI/MainHUD
@onready var device_panel: Control = $UI/DevicePanel
@onready var dashboard: Control = $UI/SmartFarmDashboard
@onready var touch: Control = $UI/TouchControls
@onready var pause_menu: Control = $UI/PauseMenu
@onready var tutorial: Control = $UI/Tutorial

var state := UIState.PLAY
var _return_state := UIState.PLAY


func _ready() -> void:
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.apply_viewport(get_viewport())
	DeviceManager.auto_simulate = true
	InputManager.action_pressed.connect(_on_action)
	player.interaction_target_changed.connect(hud.set_target)
	player.set_view_yaw(0.0)
	hud.dashboard_requested.connect(func() -> void: _on_action("dashboard"))
	hud.menu_requested.connect(func() -> void: open_pause())
	hud.interact_requested.connect(func() -> void: _on_action("interact"))
	device_panel.closed.connect(_back_to_play)
	dashboard.closed.connect(_back_to_play)
	dashboard.tutorial_requested.connect(open_tutorial)
	pause_menu.resume_requested.connect(_back_to_play)
	pause_menu.dashboard_requested.connect(func() -> void: open_dashboard(0))
	pause_menu.settings_requested.connect(func() -> void: open_dashboard(3))
	pause_menu.tutorial_requested.connect(open_tutorial)
	tutorial.finished.connect(_back_to_play)
	PlatformManager.layout_changed.connect(_on_layout)
	PlatformManager.focus_lost.connect(_on_focus_lost)
	PlatformManager.app_paused.connect(_on_app_paused)
	GameSettings.settings_changed.connect(_update_touch)
	_on_layout(PlatformManager.get_logical_size(), PlatformManager.is_portrait())
	AudioManager.start_ambient()
	_set_state(UIState.PLAY)
	if not GameSettings.tutorial_seen:
		open_tutorial.call_deferred()
	if OS.get_cmdline_user_args().has("--autotest"):
		var at: Node = load("res://scripts/AutoTest.gd").new()
		at.name = "AutoTest"
		add_child(at)


func _set_state(s: UIState) -> void:
	state = s
	var playing := s == UIState.PLAY
	InputManager.set_gameplay_enabled(playing)
	get_tree().paused = s == UIState.PAUSE
	pause_menu.visible = s == UIState.PAUSE
	hud.set_prompt_visible(playing)
	_update_touch()


func _update_touch() -> void:
	touch.set_active(PlatformManager.touch_enabled and state == UIState.PLAY)
	_on_layout(PlatformManager.get_logical_size(), PlatformManager.is_portrait())


func _back_to_play() -> void:
	if device_panel.visible:
		device_panel.close_panel()
	if dashboard.visible:
		dashboard.close_dashboard()
	tutorial.visible = false
	_set_state(UIState.PLAY)
	if not PlatformManager.touch_enabled and not PlatformManager.is_web():
		InputManager.set_mouse_captured(true)


func _on_action(action: String) -> void:
	match action:
		"interact":
			if state == UIState.PLAY and player.current_target:
				open_device(player.current_target)
			elif state == UIState.DEVICE:
				device_panel.close_panel()
		"dashboard":
			if state == UIState.DASHBOARD:
				dashboard.close_dashboard()
			elif state in [UIState.PLAY, UIState.DEVICE]:
				open_dashboard()
		"pause":
			match state:
				UIState.PLAY:
					open_pause()
				UIState.DEVICE:
					device_panel.close_panel()
				UIState.DASHBOARD:
					dashboard.close_dashboard()
				UIState.TUTORIAL:
					tutorial._finish()
				UIState.PAUSE:
					_back_to_play()


func open_device(d: VirtualDevice) -> void:
	if dashboard.visible:
		dashboard.close_dashboard()
	_set_state(UIState.DEVICE)
	device_panel.open(d)


func open_dashboard(tab := -1) -> void:
	if device_panel.visible:
		device_panel.visible = false
		device_panel.device = null
	pause_menu.visible = false
	_set_state(UIState.DASHBOARD)
	dashboard.open(tab)


func open_pause() -> void:
	if state != UIState.PLAY:
		return
	_set_state(UIState.PAUSE)


func open_tutorial() -> void:
	if dashboard.visible:
		dashboard.visible = false
	pause_menu.visible = false
	_set_state(UIState.TUTORIAL)
	tutorial.open()


func _on_layout(_size: Vector2, portrait: bool) -> void:
	if player and player.camera:
		player.camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
		player.camera.fov = 75.0 if portrait else 68.0


func _on_focus_lost() -> void:
	# Browser tab / window lost focus: release the mouse and pause on PC & web.
	if state == UIState.PLAY and not PlatformManager.touch_enabled and not OS.get_cmdline_user_args().has("--autotest"):
		open_pause()


func _on_app_paused() -> void:
	GameSettings.save()
	if state == UIState.PLAY:
		open_pause()
