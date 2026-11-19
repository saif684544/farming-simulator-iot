extends Node
## Scripted GUI smoke test + screenshot tour. Run with:
##   godot --path . -- --autotest [--shots=<dir>] [--skip-tutorial]
## Drives the real game through InputManager (movement, camera, interaction),
## triggers each automation scenario, verifies the 3D devices respond, captures
## screenshots and prints "AUTOTEST PASS/FAIL" lines, then quits with an exit
## code equal to the number of failures.

var main: Node
var shots_dir := "user://screenshots"
var failures := 0
var passes := 0
var max_frame_ms := 0.0
var hitches := 0  ## frames slower than 100 ms
var _sim_time := 0.0


func _process(delta: float) -> void:
	max_frame_ms = maxf(max_frame_ms, delta * 1000.0)
	if delta > 0.1:
		hitches += 1


func frame_report(label: String) -> void:
	print("AUTOTEST FRAMES: %s max %.0f ms, %d hitches > 100 ms" % [label, max_frame_ms, hitches])
	max_frame_ms = 0.0
	hitches = 0


func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	DeviceManager.simulation_ticked.connect(func(dt: float) -> void: _sim_time += dt)
	_run.call_deferred()


func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passes += 1
		print("AUTOTEST PASS: %s %s" % [name, detail])
	else:
		failures += 1
		print("AUTOTEST FAIL: %s %s" % [name, detail])


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Wait for an exact amount of *physics* time (frame-rate independent).
func wait_physics(sec: float) -> void:
	for i in int(sec * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## Wait until the IoT simulation has advanced `sec` simulated seconds.
func wait_sim(sec: float) -> void:
	var target := _sim_time + sec
	while _sim_time < target:
		await get_tree().process_frame


## Average frames per second over `sec` real seconds (vsync as configured).
func measure_fps(label: String, sec := 2.0) -> void:
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < int(sec * 1000000.0):
		await get_tree().process_frame
	var fps := (Engine.get_frames_drawn() - f0) / ((Time.get_ticks_usec() - t0) / 1000000.0)
	print("AUTOTEST PERF: %s %.0f FPS (%s quality)" % [label, fps, GameSettings.quality])


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [shots_dir, name]
	img.save_png(path)
	print("AUTOTEST SHOT: ", path)


func dev(id: String) -> VirtualDevice:
	return DeviceManager.get_device(id)


## Device close-up for screenshots: hides the avatar and places the third-person
## camera roughly `dist` m from `target`, on the side `dir` points to.
func frame(player: PlayerController, target: Vector3, dir: Vector3, dist := 5.5, pitch_deg := -14.0) -> void:
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var pos := target + dir * maxf(dist - player.camera_distance, 0.6)
	player.visible = false
	player.teleport(Vector3(pos.x, 0.05, pos.z), atan2(dir.x, dir.z))
	player._pitch.rotation_degrees.x = pitch_deg


func unframe(player: PlayerController) -> void:
	player.visible = true
	player._pitch.rotation_degrees.x = -14.0


## Climate, water, security and safety devices + their automations.
func _smart_home_tour(player: PlayerController) -> void:
	# HVAC heats a cold greenhouse
	var hvac := dev("hvac") as SmartHVAC
	var ts := dev("temp_sensor") as TemperatureSensor
	EnvironmentManager.set_time(15.0)
	ts.temperature = 14.0
	await wait_sim(0.3)
	check("HVAC heats a cold greenhouse", hvac.operating == "Heating", hvac.get_primary_reading())
	frame(player, Vector3(9.4, 0.6, -12.0), Vector3(0.55, 0, 0.85), 5.2, -12.0)
	await wait(1.2)
	await shot("14_hvac_heating")
	ts.temperature = 24.0
	await wait_sim(0.3)
	check("HVAC idles at temperature", hvac.operating == "Idle", hvac.operating)

	# sun shading
	AutomationManager.trigger_scenario("shading")
	await wait_sim(0.3)
	var shade := dev("greenhouse_shade") as SmartShade
	check("strong sun closes the shade", shade.power_on)
	await wait_sim(SmartShade.TRAVEL_TIME + 0.5)
	check("shade fully closed", shade.position_pct >= 99.0, "%d%%" % int(shade.position_pct))
	frame(player, Vector3(1.0, 1.0, -13.5), Vector3(1, 0, -0.15), 6.0, 22.0)
	await wait(1.0)
	await shot("15_shade_closed")

	# leak protection
	var leak := dev("leak_sensor") as LeakSensor
	var valve := dev("water_valve") as SmartValve
	frame(player, Vector3(-11.0, 0.3, -6.7), Vector3(1, 0, -0.35), 5.0, -20.0)
	await wait(0.6)
	AutomationManager.trigger_scenario("leak")
	await wait_sim(0.4)
	check("burst fitting sprays", leak.is_spraying())
	await shot("16_leak_spray")
	await wait_sim(2.0)
	check("leak detected", leak.wet)
	check("leak closes the main valve", not valve.power_on)
	await wait(1.6)
	await shot("17_leak_valve_closed")
	leak.repair_leak()
	var t := 0.0
	while valve.power_on == false and t < 15.0:
		await wait_sim(0.5)
		t += 0.5
	check("valve reopens after repair", valve.power_on, "after %.1f s" % t)

	# security lighting from REAL player movement at night
	EnvironmentManager.set_time(21.0)
	var motion := dev("motion_sensor") as MotionSensor
	var flood := dev("floodlight") as SmartFloodlight
	t = 0.0
	while motion.motion and t < 10.0:
		await wait_sim(0.5)
		t += 0.5
	unframe(player)
	player.teleport(Vector3(-8.0, 0.05, 3.0), PI * 0.5)
	await wait(0.3)
	check("floodlight off before motion", not flood.power_on)
	InputManager.set_virtual_move(Vector2(0, -1))
	await wait_physics(1.0)
	InputManager.set_virtual_move(Vector2.ZERO)
	await wait_sim(0.3)
	check("motion sensor detects the player", motion.motion and motion.last_source == "Person (you)", motion.last_source)
	check("motion after dark turns the floodlight on", flood.power_on)
	check("camera records the motion", (dev("security_camera") as SecurityCamera).recording)
	frame(player, Vector3(-16.2, 1.2, 8.4), Vector3(0.35, 0, -1), 7.0, -10.0)
	await wait(1.0)
	await measure_fps("night, floodlight + shed")
	await shot("18_night_floodlight")
	main.open_device(dev("security_camera"))
	await wait(0.8)
	await shot("19_camera_feed")
	main.device_panel.close_panel()
	await wait(0.3)

	# night lockdown waits for the door to close
	AutomationManager.trigger_scenario("lockdown")
	await wait_sim(0.3)
	var lock := dev("shed_lock") as SmartLock
	check("lockdown waits for the open door", not lock.power_on and AutomationManager.get_rule("lockdown").status.contains("door open"), AutomationManager.get_rule("lockdown").status)
	frame(player, Vector3(-16.0, 1.2, 8.4), Vector3(0.2, 0, -1), 6.0, -10.0)
	await wait(1.0)
	await shot("20_shed_door_open")
	lock.perform_control("door", false)
	await wait_sim(0.3)
	check("door closed -> locked automatically", lock.power_on)

	# smoke alarm
	EnvironmentManager.set_time(15.0)
	AutomationManager.trigger_scenario("smoke")
	var smoke := dev("smoke_detector") as SmokeDetector
	t = 0.0
	while not smoke.alarm and t < 6.0:
		await wait_sim(0.3)
		t += 0.3
	check("smoke detector alarms", smoke.alarm)
	check("siren sounds", dev("siren").power_on)
	check("shed unlocked for escape", not lock.power_on)
	frame(player, Vector3(-8.6, 1.4, 6.6), Vector3(-0.45, 0, -1), 6.0, -8.0)
	await wait(2.0)
	await shot("21_smoke_alarm")
	smoke.clear_smoke()
	await wait_sim(0.3)
	check("siren off when smoke clears", not dev("siren").power_on)
	lock.set_power(true)
	unframe(player)


## Quick responsive-layout check: HUD, device panel, dashboard, tutorial.
func _run_layout() -> void:
	var player: PlayerController = main.player
	var tag := "%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	tag = "%dx%d" % [get_tree().root.size.x, get_tree().root.size.y]
	await wait(1.5)
	player.teleport(Vector3(-9.3, 0.05, 3.6), PI)
	await wait(0.6)
	await shot("layout_%s_hud" % tag)
	InputManager.trigger("interact")
	await wait(0.5)
	await shot("layout_%s_panel" % tag)
	main.device_panel.close_panel()
	main.open_device(dev("hvac"))
	await wait(0.5)
	await shot("layout_%s_hvac" % tag)
	main.device_panel.close_panel()
	main.open_device(dev("security_camera"))
	await wait(0.5)
	await shot("layout_%s_camera" % tag)
	main.device_panel.close_panel()
	await wait(0.2)
	InputManager.trigger("dashboard")
	await wait(0.6)
	await shot("layout_%s_dashboard" % tag)
	main.dashboard.tabs.current_tab = 1
	await wait(0.4)
	await shot("layout_%s_devices" % tag)
	main.dashboard.tabs.current_tab = 2
	await wait(0.4)
	await shot("layout_%s_automations" % tag)
	main.dashboard.close_dashboard()
	main.open_tutorial()
	await wait(0.4)
	await shot("layout_%s_tutorial" % tag)
	check("layout run %s" % tag, true)
	print("AUTOTEST DONE: %d passed, %d failed" % [passes, failures])
	get_tree().quit(failures)


func _run() -> void:
	if OS.get_cmdline_user_args().has("--layout"):
		await _run_layout()
		return
	var player: PlayerController = main.player
	if main.tutorial.visible:
		main.tutorial._finish()
	await wait(1.5)
	check("main scene loaded", DeviceManager.get_device_count() == 19, "devices=%d" % DeviceManager.get_device_count())
	await measure_fps("spawn view")
	await shot("01_spawn")

	# --- movement through InputManager (same path as keyboard / joystick)
	var start := player.global_position
	InputManager.set_virtual_move(Vector2(0, -1))
	await wait_physics(1.2)
	InputManager.set_virtual_move(Vector2.ZERO)
	var moved := player.global_position.distance_to(start)
	check("player movement", moved > 2.0, "moved %.2f m" % moved)
	frame_report("startup+movement")
	var yaw0: float = player.get_camera_yaw()
	InputManager.add_touch_look(Vector2(120, 0))
	await wait(0.2)
	check("camera rotation", absf(player.get_camera_yaw() - yaw0) > 0.3, "yaw delta %.2f" % absf(player.get_camera_yaw() - yaw0))
	InputManager.set_sprint_toggle(true)
	start = player.global_position
	InputManager.set_virtual_move(Vector2(0, -1))
	await wait_physics(0.8)
	InputManager.set_virtual_move(Vector2.ZERO)
	InputManager.set_sprint_toggle(false)
	check("sprint", player.global_position.distance_to(start) > 3.0, "%.2f m in 0.8 s" % player.global_position.distance_to(start))

	# --- interaction: walk up to the hub and open its panel
	player.teleport(Vector3(-9.3, 0.05, 3.6), PI)
	await wait(0.6)
	check("interaction target detected", player.current_target == dev("hub"), str(player.current_target.device_name if player.current_target else "none"))
	InputManager.trigger("interact")
	await wait(0.5)
	check("device panel opens", main.device_panel.visible and main.state == main.UIState.DEVICE)
	await shot("02_hub_panel")
	InputManager.trigger("interact")
	await wait(0.2)
	check("device panel closes", not main.device_panel.visible and main.state == main.UIState.PLAY)

	# --- scenario 1: irrigation
	EnvironmentManager.set_time(11.0)
	AutomationManager.trigger_scenario("irrigation")
	await wait(0.4)
	var pump := dev("irrigation_pump") as IrrigationPump
	check("irrigation automation starts pump", pump.is_running() and dev("smart_plug").power_on)
	player.teleport(Vector3(-10.5, 0.05, -1.0), deg_to_rad(40.0))
	await wait(1.4)
	var spr := get_tree().get_nodes_in_group("sprinkler")
	var emitting := spr.filter(func(s: Node) -> bool: return s.active).size()
	check("sprinklers active", emitting == spr.size() and spr.size() > 0, "%d/%d" % [emitting, spr.size()])
	check("pipe flow animating", pump.flow > 0.5, "flow=%.2f" % pump.flow)
	await measure_fps("pump + sprinklers")
	await shot("03_irrigation_pump")
	player.teleport(Vector3(0, 0.05, -10.0), 0.0)
	await wait(1.0)
	await measure_fps("greenhouse irrigating")
	await shot("04_greenhouse_irrigation")
	player.teleport(Vector3(-2.5, 0.05, -13.6), deg_to_rad(20.0))
	await wait(1.0)
	await shot("04b_sprinklers_closeup")
	EnvironmentManager.set_time_speed(0.0)
	var ms := dev("soil_sensor") as MoistureSensor
	var m0 := ms.moisture
	await wait_sim(1.5)
	check("moisture rises while irrigating", ms.moisture > m0 + 3.0, "%.1f -> %.1f" % [m0, ms.moisture])
	frame_report("irrigation views")
	ms.moisture = 64.9
	await wait(0.5)
	check("irrigation stops at 65%", not pump.is_running(), "moisture %.1f" % ms.moisture)

	# --- scenario 2: temperature
	AutomationManager.trigger_scenario("temperature")
	await wait(0.4)
	var fan := dev("vent_fan") as VentilationFan
	check("heat wave turns fans on", fan.power_on)
	player.teleport(Vector3(1.5, 0.05, -12.6), 0.0)
	await wait(1.6)
	check("fan blades spinning", fan.speed > 0.5, "speed=%.2f" % fan.speed)
	await measure_fps("greenhouse inside, fans")
	await shot("05_fans_running")
	(dev("temp_sensor") as TemperatureSensor).temperature = 27.0
	await wait(0.4)
	check("fans off below 28°C", not fan.power_on)

	# --- scenario 3: lighting
	AutomationManager.trigger_scenario("lighting")
	await wait(0.4)
	var lights := dev("greenhouse_lights") as SmartLight
	check("dusk turns grow lights on", lights.power_on)
	await wait(1.0)
	player.teleport(Vector3(6, 0.05, -1.5), deg_to_rad(-20.0))
	await wait(0.8)
	await shot("06_dusk_lights")
	EnvironmentManager.set_time(22.5)
	await wait(1.0)
	await measure_fps("night, grow lights on")
	await shot("07_night")
	AutomationManager.trigger_scenario("daytime")
	await wait(0.5)
	check("daylight turns grow lights off", not lights.power_on)

	# --- offline device handling
	ms.disconnect_device()
	await wait(0.3)
	check("offline sensor pauses automation", AutomationManager.get_rule("irrigation").status.contains("offline"), AutomationManager.get_rule("irrigation").status)
	ms.connect_device()

	await _smart_home_tour(player)

	# --- dashboard
	EnvironmentManager.set_time(15.0)
	player.teleport(Vector3(0, 0.05, 20.0), 0.0)
	InputManager.trigger("dashboard")
	await wait(0.6)
	check("dashboard opens", main.dashboard.visible and main.state == main.UIState.DASHBOARD)
	await shot("08_dashboard_overview")
	main.dashboard.tabs.current_tab = 1
	await wait(0.4)
	await shot("09_dashboard_devices")
	main.dashboard.tabs.current_tab = 2
	await wait(0.4)
	await shot("10_dashboard_automations")
	# UI reflects real device state: toggle the fan from code, read the card
	fan.set_power(true)
	await wait(0.4)
	var card: Dictionary = main.dashboard._device_cards["vent_fan"]
	check("dashboard reflects device state", (card.power as Button).text == "Turn OFF")
	fan.set_power(false)
	main.dashboard.tabs.current_tab = 3
	await wait(0.4)
	await shot("11_dashboard_settings")
	InputManager.trigger("dashboard")
	await wait(0.3)
	check("dashboard closes", not main.dashboard.visible and main.state == main.UIState.PLAY)

	# --- pause menu
	InputManager.trigger("pause")
	await wait(0.3)
	check("pause menu", get_tree().paused and main.pause_menu.visible)
	await shot("12_pause")
	InputManager.trigger("pause")
	await wait(0.3)
	check("resume", not get_tree().paused)

	# --- quality presets + uncapped frame-rate measurement from a busy viewpoint
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	player.teleport(Vector3(0, 0.05, 20.0), 0.0)
	for q: String in ["low", "medium", "high"]:
		GameSettings.set_quality(q)
		await wait(1.0)
		var frames := Engine.get_frames_drawn()
		var t0 := Time.get_ticks_msec()
		await wait(2.0)
		var fps := (Engine.get_frames_drawn() - frames) * 1000.0 / maxf(Time.get_ticks_msec() - t0, 1.0)
		check("quality preset %s applied" % q, GameSettings.quality == q, "avg %.0f FPS uncapped" % fps)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	player.teleport(Vector3(10, 0.05, 6), deg_to_rad(-140.0))
	await wait(1.0)
	await shot("13_overview_east")
	frame_report("rest of tour")
	print("AUTOTEST FPS: %d" % Engine.get_frames_per_second())
	print("AUTOTEST DONE: %d passed, %d failed" % [passes, failures])
	get_tree().quit(failures)
