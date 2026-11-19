extends TestCase
## Device-level tests: initialisation, connectivity, signals, sensor ranges.


func test_devices_initialize() -> void:
	var d := spawn_all()
	check_eq(DeviceManager.get_device_count(), 8, "all devices registered")
	for id in d:
		var dev: VirtualDevice = d[id]
		check(DeviceManager.get_device(id) == dev, "%s registered under its id" % id)
		check(dev.online, "%s starts online" % id)
		check(not dev.device_name.is_empty(), "%s has a name" % id)
		check(not dev.device_type.is_empty(), "%s has a type" % id)
	check(d.hub.power_on, "hub starts powered")
	for id in ["smart_plug", "irrigation_pump", "vent_fan", "greenhouse_lights"]:
		check(not d[id].power_on, "%s starts off" % id)
	check_eq((d.soil_sensor as MoistureSensor).moisture, 45.0, "initial soil moisture")


func test_connect_and_disconnect() -> void:
	var plug := spawn_device("smart_plug")
	var events: Array = []
	plug.connection_changed.connect(func(_d: VirtualDevice, c: bool) -> void: events.append(c))
	plug.disconnect_device()
	check(not plug.online, "offline after disconnect")
	check_eq(plug.get_status_text(), "Offline", "status text when offline")
	check(not plug.set_power(true), "offline device rejects commands")
	check(not plug.power_on, "power unchanged while offline")
	plug.disconnect_device()  # no duplicate event
	plug.connect_device()
	check(plug.online, "online after reconnect")
	check_eq(events, [false, true], "connection_changed emitted once per change")
	check(plug.set_power(true), "commands accepted after reconnect")


func test_state_change_emits_signals() -> void:
	var fan := spawn_device("vent_fan")
	var count := [0]
	fan.state_changed.connect(func(_d: VirtualDevice) -> void: count[0] += 1)
	var mgr_count := [0]
	var cb := func(d: VirtualDevice) -> void:
		if d == fan:
			mgr_count[0] += 1
	DeviceManager.device_state_changed.connect(cb)
	fan.set_power(true)
	check_eq(count[0], 1, "state_changed on power on")
	fan.set_power(true)
	check_eq(count[0], 1, "no signal when state unchanged")
	fan.toggle_power()
	check_eq(count[0], 2, "state_changed on toggle")
	check(not fan.power_on, "toggle turned fan off")
	check_eq(mgr_count[0], 2, "DeviceManager re-emits device state changes")
	DeviceManager.device_state_changed.disconnect(cb)


func test_sensor_readings_emit_signal() -> void:
	var soil := spawn_device("soil_sensor")
	var n := [0]
	soil.reading_updated.connect(func(_d: VirtualDevice) -> void: n[0] += 1)
	run_sim(1.0)
	check(n[0] >= 10, "reading_updated emitted each tick (got %d)" % n[0])


func test_sensor_readings_stay_in_valid_ranges() -> void:
	var d := spawn_all()
	var soil := d.soil_sensor as MoistureSensor
	var temp := d.temp_sensor as TemperatureSensor
	var light := d.light_sensor as LightSensor
	AutomationManager.set_rule_enabled("irrigation", false)
	AutomationManager.set_rule_enabled("temperature", false)
	# force extremes: run the pump for a long time, then let everything dry out in a heat wave
	d.smart_plug.set_power(true)
	d.irrigation_pump.set_power(true)
	EnvironmentManager.time_speed = 10.0
	for i in 600:
		DeviceManager.step(0.1)
		check(soil.moisture >= 0.0 and soil.moisture <= 100.0, "moisture in 0..100")
		check(light.light_level >= 0.0 and light.light_level <= 100.0, "light in 0..100")
		check(temp.temperature >= -10.0 and temp.temperature <= 60.0, "temperature in -10..60")
	check_eq(soil.moisture, 100.0, "moisture saturates at 100%")
	d.irrigation_pump.set_power(false)
	EnvironmentManager.trigger_heat_wave(30.0)
	for i in 3000:
		DeviceManager.step(0.1)
		check(soil.moisture >= 0.0 and soil.moisture <= 100.0, "moisture in 0..100 (drying)")
		check(temp.temperature >= -10.0 and temp.temperature <= 60.0, "temperature in -10..60 (heat)")
	check_eq(soil.moisture, 0.0, "moisture bottoms out at 0%")
	check(temp.humidity >= 20.0 and temp.humidity <= 98.0, "humidity in range")


func test_light_sensor_follows_time_of_day() -> void:
	var light := spawn_device("light_sensor") as LightSensor
	EnvironmentManager.set_time(12.0)
	light.simulate(0.0)
	check(light.light_level > 90.0, "bright at noon (%.1f)" % light.light_level)
	EnvironmentManager.set_time(0.0)
	light.simulate(0.0)
	check(light.light_level < 5.0, "dark at midnight (%.1f)" % light.light_level)
	EnvironmentManager.set_time(17.6)
	light.simulate(0.0)
	check(light.light_level < 35.0 and light.light_level > 5.0, "dusk is dim (%.1f)" % light.light_level)


func test_pump_needs_plug_power() -> void:
	var plug := spawn_device("smart_plug")
	var pump := spawn_device("irrigation_pump") as IrrigationPump
	pump.set_power(true)
	check(not pump.is_running(), "pump does not run without plug power")
	check_eq(pump.get_status_text(), "No power (plug off)", "pump status shows missing power")
	check(not DeviceManager.is_irrigating(), "not irrigating")
	plug.set_power(true)
	check(pump.is_running(), "pump runs once plug is on")
	check(DeviceManager.is_irrigating(), "irrigating")
	check(plug.get_load_watts() > 100.0, "plug reports pump load")


func test_moisture_dries_and_rises_with_irrigation() -> void:
	var d := spawn_all()
	AutomationManager.set_rule_enabled("irrigation", false)
	var soil := d.soil_sensor as MoistureSensor
	var m0 := soil.moisture
	run_sim(5.0)
	check(soil.moisture < m0, "soil dries over time (%.1f -> %.1f)" % [m0, soil.moisture])
	var m1 := soil.moisture
	d.smart_plug.set_power(true)
	d.irrigation_pump.set_power(true)
	run_sim(2.0)
	check(soil.moisture > m1 + 5.0, "soil gets wetter while irrigating (%.1f -> %.1f)" % [m1, soil.moisture])


func test_fan_cools_greenhouse() -> void:
	var d := spawn_all()
	AutomationManager.set_rule_enabled("temperature", false)
	EnvironmentManager.time_speed = 0.0
	var t := d.temp_sensor as TemperatureSensor
	t.temperature = 35.0
	run_sim(20.0)
	var without_fan := t.temperature
	t.temperature = 35.0
	d.vent_fan.set_power(true)
	run_sim(20.0)
	check(t.temperature < without_fan - 3.0, "fans cool the greenhouse (%.1f vs %.1f)" % [t.temperature, without_fan])
