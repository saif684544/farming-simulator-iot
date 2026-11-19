extends TestCase
## Integration tests: hub, DeviceManager, automation driving real devices,
## UI reflecting real state, manual controls, and the full main scene.


func test_hub_recognizes_devices() -> void:
	var d := spawn_all()
	var hub := d.hub as VirtualHub
	check_eq(hub.get_paired_devices().size(), 7, "hub sees all 7 other devices")
	check_eq(hub.get_connected_count(), 7, "all connected")
	d.light_sensor.disconnect_device()
	check_eq(hub.get_connected_count(), 6, "hub notices a disconnect")
	check(hub.get_primary_reading().begins_with("6/7"), "hub summary updates (%s)" % hub.get_primary_reading())
	var names: Array = hub.get_readings().map(func(r: Array) -> String: return r[0].strip_edges())
	check(names.has("Soil Moisture Sensor"), "hub overview lists devices")


func test_device_manager_tracks_status() -> void:
	var d := spawn_all()
	check_eq(DeviceManager.get_online_count(), 8, "8 online")
	var seen: Array = []
	var cb := func(dev: VirtualDevice) -> void: seen.append(dev.device_id)
	DeviceManager.device_state_changed.connect(cb)
	d.vent_fan.disconnect_device()
	check_eq(DeviceManager.get_online_count(), 7, "online count drops")
	check(seen.has("vent_fan"), "manager emitted state change for the fan")
	DeviceManager.device_state_changed.disconnect(cb)
	var ids := DeviceManager.get_all_devices().map(func(x: VirtualDevice) -> String: return x.device_id)
	check_eq(ids[0], "hub", "hub listed first")
	d.vent_fan.free()
	check(DeviceManager.get_device("vent_fan") == null, "freed device unregisters")


func test_automation_controls_real_devices_closed_loop() -> void:
	var d := spawn_all()
	EnvironmentManager.set_time(23.0)  # night: no solar gain
	EnvironmentManager.time_speed = 0.0
	var t := d.temp_sensor as TemperatureSensor
	var fan := d.vent_fan as VentilationFan
	t.temperature = 36.0
	var turned_on := false
	var turned_off_after := false
	for i in 600:
		DeviceManager.step(0.1)
		if fan.power_on:
			turned_on = true
		elif turned_on:
			turned_off_after = true
			break
	check(turned_on, "fan switched on by automation")
	check(turned_off_after, "fan switched off again after cooling")
	check(t.temperature < 28.0, "greenhouse cooled below 28 (%.1f)" % t.temperature)
	# lighting closed loop over a simulated evening
	EnvironmentManager.set_time(16.5)
	EnvironmentManager.time_speed = 1.0
	run_sim(30.0)  # 2 game-hours
	check(d.greenhouse_lights.power_on, "lights turned on as evening falls (%s)" % EnvironmentManager.format_time())


func test_ui_reflects_device_state() -> void:
	var d := spawn_all()
	var dash: Control = spawn("res://scenes/UI/SmartFarmDashboard.tscn")
	dash.open(1)
	var card: Dictionary = dash._device_cards["vent_fan"]
	check_eq((card.power as Button).text, "Turn ON", "card shows fan off")
	d.vent_fan.set_power(true)
	dash.refresh()
	check_eq((card.power as Button).text, "Turn OFF", "card shows fan on")
	check((card.reading as Label).text.begins_with("RUNNING"), "card reading shows running")
	d.vent_fan.disconnect_device()
	dash.refresh()
	check_eq((card.conn as Button).text, "Reconnect", "card shows offline device")
	check((card.power as Button).disabled, "power disabled while offline")
	(d.soil_sensor as MoistureSensor).moisture = 12.3
	dash.refresh()
	check_eq((dash._tiles.soil.value as Label).text, "12.3 %", "overview tile shows live moisture")
	var auto_card: Dictionary = dash._automation_panel._cards["irrigation"]
	AutomationManager.evaluate_all()
	dash.refresh()
	check((auto_card.pill.get_child(0).get_node("Text") as Label).text.contains("irrigating"), "automation card shows active irrigation")

	var panel: Control = spawn("res://scenes/UI/DevicePanel.tscn")
	panel.open(d.smart_plug)
	panel._rebuild_controls()  # normally deferred to the next idle frame
	var power_btn := panel._controls.get_node("Ctl_power") as Button
	check(power_btn != null, "device panel exposes the power control")
	var before: bool = d.smart_plug.power_on
	power_btn.pressed.emit()
	check(d.smart_plug.power_on != before, "pressing the panel button toggles the real plug")
	check(panel._title.text == "Smart Plug", "panel shows device name")


func test_manual_controls() -> void:
	var d := spawn_all()
	d.greenhouse_lights.perform_control("power", true)
	check(d.greenhouse_lights.power_on, "manual power on")
	d.greenhouse_lights.perform_control("connection", false)
	check(not d.greenhouse_lights.online, "manual disconnect")
	d.hub.perform_control("reconnect_all")
	check_eq(DeviceManager.get_online_count(), 8, "hub reconnect-all restores every device")
	d.hub.perform_control("outage")
	check_eq(DeviceManager.get_online_count(), 7, "hub outage simulation disconnects one device")
	for c in d.irrigation_pump.get_controls():
		check(c.has("id") and c.has("label") and c.has("kind"), "control descriptor well-formed")


func test_main_scene_loads() -> void:
	var main: Node = spawn("res://scenes/Main.tscn")
	DeviceManager.auto_simulate = false
	check_eq(DeviceManager.get_device_count(), 19, "main scene registers 19 devices")
	check(main.get_node_or_null("Player") is PlayerController, "player present")
	check(main.get_node_or_null("FarmEnvironment/Terrain") != null, "terrain generated")
	check(main.get_tree().get_nodes_in_group("sprinkler").size() == 8, "8 sprinklers built")
	check(main.get_node("UI/MainHUD") != null and main.get_node("UI/SmartFarmDashboard") != null, "UI present")
	run_sim(5.0)
	check(DeviceManager.get_device("hub").is_running(), "hub running after simulation")
