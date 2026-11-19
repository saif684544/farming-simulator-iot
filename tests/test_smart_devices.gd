extends TestCase
## Tests for the SmartThings-style climate, water, security and safety
## devices and the five automations that use them.


func _setup(hour := 12.0) -> Dictionary:
	var d := spawn_everything()
	EnvironmentManager.set_time(hour)
	EnvironmentManager.time_speed = 0.0
	d.light_sensor.simulate(0.0)
	AutomationManager.evaluate_all()
	return d


func _sim_until(cond: Callable, max_seconds: float) -> bool:
	var steps := int(max_seconds / DeviceManager.TICK)
	for i in steps:
		DeviceManager.step(DeviceManager.TICK)
		if cond.call():
			return true
	return false


# ---------------------------------------------------------------- general ---

func test_new_devices_initialize() -> void:
	var d := _setup()
	check_eq(DeviceManager.get_device_count(), 19, "19 devices registered")
	check_eq((d.hub as VirtualHub).get_paired_devices().size(), 18, "hub pairs all 18 other devices")
	for id in SMART_HOME_SCENES:
		var dev: VirtualDevice = d[id]
		check(dev.online, "%s online" % id)
		check(dev.category in VirtualDevice.CATEGORIES, "%s has a known category (%s)" % [id, dev.category])
		for r in dev.get_readings():
			check(r is Array and r.size() == 2, "%s readings are label/value pairs" % id)
		for c in dev.get_controls():
			check(c.has("id") and c.has("label") and c.has("kind"), "%s control descriptor well-formed" % id)
			if c.kind == "choice":
				check(c.has("options") and c.options.has(c.value), "%s choice has options" % id)
			if c.kind == "stepper":
				check(c.has("min") and c.has("max") and c.has("step"), "%s stepper has range" % id)
	check(d.water_valve.power_on, "valve starts open")
	check(d.shed_lock.power_on, "shed starts locked")
	check(not d.siren.power_on, "siren starts silent")


func test_devices_can_go_offline() -> void:
	var d := _setup()
	d.shed_lock.disconnect_device()
	check(not d.shed_lock.set_power(false), "offline lock refuses commands")
	check(d.shed_lock.power_on, "lock state unchanged")
	d.siren.disconnect_device()
	AutomationManager.evaluate_all()
	check(AutomationManager.get_rule("smoke").status.contains("offline"), "smoke rule waits for offline siren")
	d.shed_lock.connect_device()
	check(d.shed_lock.set_power(false), "reconnected lock accepts commands")


# -------------------------------------------------------------------- HVAC ---

func test_hvac_heats_a_cold_greenhouse() -> void:
	var d := _setup(23.0)
	var hvac := d.hvac as SmartHVAC
	var t := d.temp_sensor as TemperatureSensor
	check_eq(hvac.mode, "Auto", "default mode Auto")
	t.temperature = 14.0
	DeviceManager.step(0.1)
	check_eq(hvac.operating, "Heating", "heats below the 18 °C setpoint")
	check(hvac.get_thermal_offset() > 0.0, "heating raises the greenhouse target")
	var reached := _sim_until(func() -> bool: return t.temperature >= 18.0, 120.0)
	check(reached, "greenhouse warmed to 18 °C (%.1f)" % t.temperature)
	_sim_until(func() -> bool: return hvac.operating == "Idle", 30.0)
	check_eq(hvac.operating, "Idle", "goes idle above the setpoint + deadband")
	check(hvac.energy_kwh > 0.0, "energy is metered")


func test_hvac_modes_and_setpoints() -> void:
	var d := _setup(23.0)
	var hvac := d.hvac as SmartHVAC
	var t := d.temp_sensor as TemperatureSensor
	hvac.perform_control("mode", "Cool")
	check_eq(hvac.mode, "Cool", "mode set through the generic control API")
	hvac.perform_control("cool_setpoint", 24.0)
	check_eq(hvac.cool_setpoint, 24.0, "cooling setpoint changed")
	t.temperature = 30.0
	DeviceManager.step(0.1)
	check_eq(hvac.operating, "Cooling", "cools above setpoint")
	check(hvac.get_thermal_offset() < 0.0, "cooling lowers the greenhouse target")
	t.temperature = 10.0
	DeviceManager.step(0.1)
	check(hvac.operating != "Heating", "Cool mode never heats")
	hvac.perform_control("heat_setpoint", 26.0)
	check(hvac.cool_setpoint - hvac.heat_setpoint >= 2.0, "setpoints keep a 2 °C gap (%s/%s)" % [hvac.heat_setpoint, hvac.cool_setpoint])
	hvac.set_power(false)
	DeviceManager.step(0.1)
	check_eq(hvac.operating, "Idle", "system off -> idle")
	check_eq(hvac.get_thermal_offset(), 0.0, "no effect when off")
	hvac.set_power(true)
	hvac.disconnect_device()
	check(not hvac.set_mode("Heat"), "offline thermostat ignores mode changes")


# ------------------------------------------------------------------- shade ---

func test_strong_sun_closes_shade() -> void:
	var d := _setup(12.0)
	var shade := d.greenhouse_shade as SmartShade
	check(shade.power_on, "shade commanded closed in full sun")
	check_eq(AutomationManager.get_rule("shading").fire_count, 1, "shading rule fired")
	run_sim(SmartShade.TRAVEL_TIME + 0.5)
	check_eq(shade.position_pct, 100.0, "screen fully closed")
	check(shade.get_thermal_offset() < -2.0, "screen blocks solar gain (%.2f)" % shade.get_thermal_offset())
	EnvironmentManager.set_time(17.0)
	d.light_sensor.simulate(0.0)
	AutomationManager.evaluate_all()
	check(not shade.power_on, "shade opens when the light drops below 60%")


# ------------------------------------------------------------------ water ---

func test_irrigation_waits_for_closed_valve() -> void:
	var d := _setup()
	d.water_valve.set_power(false)
	(d.soil_sensor as MoistureSensor).moisture = 20.0
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.power_on, "pump commanded on")
	check(not d.irrigation_pump.is_running(), "pump can't run with the valve closed")
	check(AutomationManager.get_rule("irrigation").status.contains("valve closed"), AutomationManager.get_rule("irrigation").status)
	d.water_valve.set_power(true)
	check(d.irrigation_pump.is_running(), "pump runs once the valve opens")


func test_leak_closes_valve_and_reopens_after_repair() -> void:
	var d := _setup()
	var leak := d.leak_sensor as LeakSensor
	var valve := d.water_valve as SmartValve
	(d.soil_sensor as MoistureSensor).moisture = 20.0
	AutomationManager.evaluate_all()
	check(d.irrigation_pump.is_running(), "irrigating before the leak")
	leak.start_leak()
	check(leak.is_spraying(), "burst fitting sprays while the valve is open")
	var detected := _sim_until(func() -> bool: return leak.wet, 10.0)
	check(detected, "sensor detects the water")
	check(not valve.power_on, "automation closed the main valve")
	check(not d.irrigation_pump.power_on, "automation stopped the pump")
	check(not leak.is_spraying(), "spray stops once the valve is closed")
	check(leak.is_alert(), "sensor reports an alert")
	run_sim(60.0)
	check(not leak.wet, "puddle dried out")
	check(not valve.power_on, "valve stays closed until the fitting is repaired")
	leak.perform_control("repair")
	DeviceManager.step(0.1)
	check(valve.power_on, "valve reopened after repair")
	check_eq(AutomationManager.get_rule("leak").fire_count, 2, "closed + reopened events")


# --------------------------------------------------------------- security ---

func test_motion_sensor_field_of_view() -> void:
	var d := _setup()
	var m := d.motion_sensor as MotionSensor
	var fwd := (m.global_transform.basis * m.facing).normalized()
	check(m.sees(m.global_position + fwd * 4.0), "sees a person 4 m in front")
	check(not m.sees(m.global_position - fwd * 4.0), "does not see behind")
	check(not m.sees(m.global_position + fwd * 20.0), "out of range at 20 m")


func test_motion_at_night_turns_floodlight_on_then_off() -> void:
	var d := _setup(21.0)
	var m := d.motion_sensor as MotionSensor
	var flood := d.floodlight as SmartFloodlight
	var cam := d.security_camera as SecurityCamera
	m.simulate_motion()
	DeviceManager.step(0.1)
	check(flood.power_on, "floodlight on after motion in the dark")
	check(flood.trigger_source.begins_with("Automation"), "panel shows automation as the source")
	check(cam.recording, "camera records while motion is active")
	check_eq(cam.clips, 1, "one clip saved")
	run_sim(MotionSensor.HOLD_TIME + 1.0)
	check(not m.motion, "motion clears after the hold time")
	check(flood.power_on, "light holds after motion clears")
	check(not cam.recording, "recording stops")
	run_sim(AutomationManager.FLOOD_HOLD)
	check(not flood.power_on, "floodlight off after %d s without motion" % int(AutomationManager.FLOOD_HOLD))


func test_motion_in_daylight_keeps_floodlight_off() -> void:
	var d := _setup(12.0)
	(d.motion_sensor as MotionSensor).simulate_motion()
	DeviceManager.step(0.1)
	check(not d.floodlight.power_on, "no floodlight in daylight")
	check((d.security_camera as SecurityCamera).recording, "camera still records daytime motion")


func test_lock_and_door_rules() -> void:
	var d := _setup()
	var lock := d.shed_lock as SmartLock
	check(not lock.set_door_open(true), "locked door can't be opened")
	lock.perform_control("power", false)
	check(lock.set_door_open(true), "unlocked door opens")
	DeviceManager.step(0.1)
	check((d.door_contact as ContactSensor).contact_open, "contact sensor reports open")
	check(not lock.set_power(true), "bolt can't be thrown with the door open")
	check(not lock.power_on, "still unlocked")


func test_night_lockdown_waits_for_door_to_close() -> void:
	var d := _setup(12.0)
	var lock := d.shed_lock as SmartLock
	var contact := d.door_contact as ContactSensor
	var msg := AutomationManager.trigger_scenario("lockdown")
	check(not msg.is_empty(), "scenario exists")
	DeviceManager.step(0.1)
	check(contact.contact_open, "door left open")
	check(not lock.power_on, "can't lock an open door")
	check_eq(AutomationManager.get_rule("lockdown").status, "Waiting - shed door open", "rule waits")
	lock.perform_control("door", false)
	DeviceManager.step(0.1)
	check(lock.power_on, "door locked as soon as it closed")
	check(AutomationManager.get_rule("lockdown").last_event.contains("locked"), AutomationManager.get_rule("lockdown").last_event)


# ----------------------------------------------------------------- safety ---

func test_smoke_alarm_sounds_siren_and_unlocks() -> void:
	var d := _setup()
	var smoke := d.smoke_detector as SmokeDetector
	var siren := d.siren as SmartSiren
	var lock := d.shed_lock as SmartLock
	check(lock.power_on, "shed locked before the fire")
	smoke.start_smoke()
	var alarm := _sim_until(func() -> bool: return smoke.alarm, 10.0)
	check(alarm, "detector alarms on smoke")
	check(siren.power_on, "siren sounding")
	check(not lock.power_on, "escape route unlocked")
	check(smoke.get_co_ppm() > 30.0, "CO rises with the smoke (%d ppm)" % int(smoke.get_co_ppm()))
	var cleared := _sim_until(func() -> bool: return not smoke.alarm, 90.0)
	check(cleared, "smoke clears after the source burns out")
	check(not siren.power_on, "siren silenced automatically")
	check_eq(AutomationManager.get_rule("smoke").fire_count, 2, "alarm + clear events")


func test_disabling_rules_releases_devices() -> void:
	var d := _setup(21.0)
	(d.motion_sensor as MotionSensor).simulate_motion()
	DeviceManager.step(0.1)
	check(d.floodlight.power_on, "floodlight on")
	AutomationManager.set_rule_enabled("security_light", false)
	check(not d.floodlight.power_on, "disabling security lighting switches the floodlight off")
	(d.leak_sensor as LeakSensor).start_leak()
	_sim_until(func() -> bool: return not d.water_valve.power_on, 10.0)
	AutomationManager.set_rule_enabled("leak", false)
	check(d.water_valve.power_on, "disabling leak protection reopens the valve")


# --------------------------------------------------------------------- UI ---

func test_dashboard_groups_devices_and_uses_device_wording() -> void:
	var d := _setup()
	var dash: Control = spawn("res://scenes/UI/SmartFarmDashboard.tscn")
	dash.open(1)
	check_eq(dash._device_cards.size(), 19, "a card for every device")
	var lock_card: Dictionary = dash._device_cards["shed_lock"]
	check_eq((lock_card.power as Button).text, "Unlock", "lock card offers Unlock")
	(lock_card.power as Button).pressed.emit()
	check(not d.shed_lock.power_on, "card button unlocks the real lock")
	dash.refresh()
	check_eq((lock_card.power as Button).text, "Lock", "card updates to Lock")
	var valve_card: Dictionary = dash._device_cards["water_valve"]
	check_eq((valve_card.power as Button).text, "Close valve", "valve card wording")
	var auto_cards: Dictionary = dash._automation_panel._cards
	check_eq(auto_cards.size(), 8, "8 automation cards")


func test_device_panel_renders_choice_stepper_and_camera() -> void:
	var d := _setup()
	var panel: Control = spawn("res://scenes/UI/DevicePanel.tscn")
	panel.open(d.hvac)
	panel._rebuild_controls()
	var mode_row: Node = panel._controls.get_node_or_null("Ctl_mode")
	check(mode_row != null, "thermostat mode picker rendered")
	var cool_btn: Button = mode_row.find_child("Opt_Cool", true, false) as Button if mode_row else null
	check(cool_btn != null, "Cool option present")
	if cool_btn:
		cool_btn.pressed.emit()
	check_eq((d.hvac as SmartHVAC).mode, "Cool", "picking Cool changes the real thermostat")
	panel._rebuild_controls()
	var stepper: Node = panel._controls.get_node_or_null("Ctl_heat_setpoint")
	check(stepper != null, "setpoint stepper rendered")
	if stepper:
		(stepper.get_node("Plus") as Button).pressed.emit()
	check_eq((d.hvac as SmartHVAC).heat_setpoint, 19.0, "+ raises the heating setpoint")
	panel.open(d.security_camera)
	panel._refresh_readings()
	check(panel._preview_box.visible, "camera panel shows the live feed area")
	check(panel._preview.texture != null, "camera provides a viewport texture")
	check_eq((d.security_camera as SecurityCamera)._viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "feed renders while viewed")
	panel.close_panel()
	check_eq((d.security_camera as SecurityCamera)._viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "feed stops when the panel closes")
