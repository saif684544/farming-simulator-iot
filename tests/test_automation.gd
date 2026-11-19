extends TestCase
## Automation engine tests for the three predefined scenarios.


func _setup() -> Dictionary:
	var d := spawn_all()
	EnvironmentManager.set_time(12.0)
	d.light_sensor.simulate(0.0)
	AutomationManager.evaluate_all()
	return d


func test_moisture_below_30_activates_irrigation() -> void:
	var d := _setup()
	check(not d.irrigation_pump.is_running(), "pump idle at 45%")
	(d.soil_sensor as MoistureSensor).moisture = 29.0
	AutomationManager.evaluate_all()
	check(d.smart_plug.power_on, "smart plug switched on")
	check(d.irrigation_pump.power_on, "pump switched on")
	check(d.irrigation_pump.is_running(), "pump running")
	check_eq(AutomationManager.get_rule("irrigation").status, "Active - irrigating", "rule status")
	check_eq(AutomationManager.get_rule("irrigation").fire_count, 1, "rule fired once")


func test_moisture_reaching_65_deactivates_irrigation() -> void:
	var d := _setup()
	var soil := d.soil_sensor as MoistureSensor
	soil.moisture = 25.0
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "irrigation started")
	# let the closed loop run: moisture must climb gradually and stop at >= 65
	var seen_mid := false
	for i in 300:
		DeviceManager.step(0.1)
		if soil.moisture > 40.0 and soil.moisture < 60.0 and d.irrigation_pump.is_running():
			seen_mid = true
		if not d.irrigation_pump.is_running():
			break
	check(seen_mid, "moisture rises gradually while irrigating")
	check(not d.irrigation_pump.is_running(), "pump stopped")
	check(not d.irrigation_pump.power_on, "pump switched off")
	check(not d.smart_plug.power_on, "plug switched off")
	check(soil.moisture >= 65.0 and soil.moisture < 68.0, "stopped right at the 65%% threshold (%.1f)" % soil.moisture)
	check_eq(AutomationManager.get_rule("irrigation").status, "Monitoring", "rule back to monitoring")


func test_temperature_above_32_activates_fan() -> void:
	var d := _setup()
	(d.temp_sensor as TemperatureSensor).temperature = 32.5
	AutomationManager.evaluate_all()
	check(d.vent_fan.power_on, "fan on above 32°C")
	check_eq(AutomationManager.get_rule("temperature").status, "Active - fans running", "rule status")


func test_temperature_exactly_32_does_not_trigger() -> void:
	var d := _setup()
	(d.temp_sensor as TemperatureSensor).temperature = 32.0
	AutomationManager.evaluate_all()
	check(not d.vent_fan.power_on, "fan stays off at exactly 32°C (rule is > 32)")


func test_temperature_below_28_deactivates_fan() -> void:
	var d := _setup()
	var t := d.temp_sensor as TemperatureSensor
	t.temperature = 34.0
	AutomationManager.evaluate_all()
	check(d.vent_fan.power_on, "fan on")
	t.temperature = 29.0
	AutomationManager.evaluate_all()
	check(d.vent_fan.power_on, "fan stays on in the 28-32 hysteresis band")
	t.temperature = 27.9
	AutomationManager.evaluate_all()
	check(not d.vent_fan.power_on, "fan off below 28°C")


func test_low_ambient_light_activates_lighting() -> void:
	var d := _setup()
	check(not d.greenhouse_lights.power_on, "lights off at noon")
	EnvironmentManager.set_time(17.6)
	d.light_sensor.simulate(0.0)
	AutomationManager.evaluate_all()
	check(d.greenhouse_lights.power_on, "lights on at dusk (light %.0f%%)" % (d.light_sensor as LightSensor).light_level)
	EnvironmentManager.set_time(9.0)
	d.light_sensor.simulate(0.0)
	AutomationManager.evaluate_all()
	check(not d.greenhouse_lights.power_on, "lights off again in the morning")


func test_disabled_rule_does_not_act_and_releases_devices() -> void:
	var d := _setup()
	var soil := d.soil_sensor as MoistureSensor
	soil.moisture = 20.0
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "irrigation running")
	AutomationManager.set_rule_enabled("irrigation", false)
	check(not d.irrigation_pump.is_running(), "disabling the rule stops what it started")
	check_eq(AutomationManager.get_rule("irrigation").status, "Disabled", "status Disabled")
	soil.moisture = 10.0
	AutomationManager.evaluate_all()
	check(not d.irrigation_pump.power_on, "disabled rule ignores dry soil")
	AutomationManager.set_rule_enabled("irrigation", true)
	check(d.irrigation_pump.is_running(), "re-enabling re-evaluates the current condition")


func test_offline_sensor_pauses_rule() -> void:
	var d := _setup()
	d.temp_sensor.disconnect_device()
	(d.temp_sensor as TemperatureSensor).temperature = 40.0
	AutomationManager.evaluate_all()
	check(not d.vent_fan.power_on, "no action on an offline sensor")
	check(AutomationManager.get_rule("temperature").status.contains("offline"), "status mentions offline")
	d.temp_sensor.connect_device()
	AutomationManager.evaluate_all()
	check(d.vent_fan.power_on, "acts once sensor reconnects")


func test_hub_offline_pauses_all_rules() -> void:
	var d := _setup()
	d.hub.set_power(false)
	(d.soil_sensor as MoistureSensor).moisture = 10.0
	AutomationManager.evaluate_all()
	check(not d.irrigation_pump.power_on, "no irrigation while hub is off")
	for r in AutomationManager.rules:
		check(r.status.contains("hub offline"), "%s paused" % r.id)
	d.hub.set_power(true)
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "irrigation resumes with the hub")


func test_manual_override_between_thresholds_is_respected() -> void:
	var d := _setup()
	d.greenhouse_lights.set_power(true)  # manual ON at noon
	AutomationManager.evaluate_all()
	check(d.greenhouse_lights.power_on, "manual ON is not immediately undone (edge-triggered rules)")
	d.smart_plug.set_power(true)
	d.irrigation_pump.set_power(true)    # manual watering at 45 %
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "manual irrigation keeps running")
	run_sim(10.0)
	check(not d.irrigation_pump.is_running(), "automation still stops manual irrigation at 65%")


func test_scenarios_trigger_rules() -> void:
	var d := _setup()
	AutomationManager.trigger_scenario("irrigation")
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "dry-soil scenario starts irrigation")
	AutomationManager.trigger_scenario("temperature")
	AutomationManager.evaluate_all()
	check(d.vent_fan.power_on, "heat-wave scenario starts fans")
	AutomationManager.trigger_scenario("lighting")
	AutomationManager.evaluate_all()
	check(d.greenhouse_lights.power_on, "dusk scenario turns lights on")
