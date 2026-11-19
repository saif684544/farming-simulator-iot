extends Node
## Rule-based automation engine with three predefined scenarios.
##
## Rules are edge-triggered with hysteresis: they act when a reading *enters*
## a zone (e.g. moisture drops below 30 %), which mirrors how SmartThings-style
## routines behave and leaves room for manual overrides in between.

signal rule_updated(rule: AutomationRule)
signal rule_fired(rule: AutomationRule, message: String)

const IRRIGATION_START := 30.0
const IRRIGATION_STOP := 65.0
const FAN_ON := 32.0
const FAN_OFF := 28.0
const LIGHT_ON := 35.0   ## ambient light % below which lights switch on
const LIGHT_OFF := 40.0  ## ambient light % at/above which lights switch off
const SHADE_CLOSE := 80.0  ## ambient light % at/above which the shade closes
const SHADE_OPEN := 60.0   ## ambient light % below which it opens again
const FLOOD_HOLD := 30.0   ## seconds the floodlight stays on after the last motion

var rules: Array[AutomationRule] = []


func _ready() -> void:
	_create_rules()


func _create_rules() -> void:
	rules.clear()
	rules.append(AutomationRule.new("irrigation", "Smart Irrigation",
		"Soil moisture < %d%%" % IRRIGATION_START,
		"Smart plug + irrigation pump ON; OFF at %d%%" % IRRIGATION_STOP,
		"Waters the greenhouse beds and outdoor field when the soil gets dry."))
	rules.append(AutomationRule.new("temperature", "Smart Temperature Control",
		"Greenhouse temp > %d°C" % FAN_ON,
		"Ventilation fans ON; OFF below %d°C" % FAN_OFF,
		"Keeps the greenhouse from overheating on hot afternoons."))
	rules.append(AutomationRule.new("lighting", "Smart Lighting",
		"Ambient light < %d%%" % LIGHT_ON,
		"Greenhouse grow lights ON; OFF at %d%%" % LIGHT_OFF,
		"Extends the growing day automatically at dusk and switches off at dawn."))
	rules.append(AutomationRule.new("shading", "Smart Sun Shading",
		"Ambient light >= %d%%" % SHADE_CLOSE,
		"Greenhouse shade screen CLOSES; OPENS below %d%%" % SHADE_OPEN,
		"Blocks part of the midday solar gain so the greenhouse runs cooler."))
	rules.append(AutomationRule.new("leak", "Leak Protection",
		"Water leak sensor detects water",
		"Main water valve CLOSES + pump OFF; reopens once dry and repaired",
		"Stops a burst fitting from emptying the tank and flooding the pump pad."))
	rules.append(AutomationRule.new("security_light", "Security Lighting",
		"Motion at the shed while ambient light < %d%%" % LIGHT_ON,
		"Floodlight ON; OFF after %d s without motion" % int(FLOOD_HOLD),
		"Lights up the yard when someone moves near the shed after dark. The camera records the clip."))
	rules.append(AutomationRule.new("smoke", "Smoke Alarm",
		"Smoke / CO alarm triggered",
		"Siren + strobe ON, shed door UNLOCKED; siren OFF when clear",
		"Raises the alarm and opens the escape route if the control-station cabinet smoulders."))
	rules.append(AutomationRule.new("lockdown", "Night Lockdown",
		"Ambient light drops below %d%% (dusk)" % LIGHT_ON,
		"Lock the shed door - waits until the contact sensor reports it closed",
		"Secures the shed every evening, even if somebody left the door open."))


func reset() -> void:
	_create_rules()


func get_rule(id: String) -> AutomationRule:
	for r in rules:
		if r.id == id:
			return r
	return null


func get_enabled_count() -> int:
	var c := 0
	for r in rules:
		if r.enabled:
			c += 1
	return c


func set_rule_enabled(id: String, enabled: bool) -> void:
	var r := get_rule(id)
	if r == null or r.enabled == enabled:
		return
	r.enabled = enabled
	r.zone = ""  # re-evaluate current conditions from scratch
	if not enabled and r.engaged:
		_release(r)
	r.engaged = false
	_evaluate(r)
	rule_updated.emit(r)


func evaluate_all(dt := 0.0) -> void:
	for r in rules:
		_evaluate(r, dt)


func _set_status(r: AutomationRule, s: String) -> void:
	if r.status != s:
		r.status = s
		rule_updated.emit(r)


func _fire(r: AutomationRule, message: String) -> void:
	r.fire_count += 1
	r.last_event = "%s  %s" % [EnvironmentManager.format_time(), message]
	rule_fired.emit(r, message)
	rule_updated.emit(r)


func _devices_for(r: AutomationRule) -> Array:
	match r.id:
		"irrigation":
			return [DeviceManager.get_device("soil_sensor"), DeviceManager.get_device("smart_plug"), DeviceManager.get_device("irrigation_pump")]
		"temperature":
			return [DeviceManager.get_device("temp_sensor"), DeviceManager.get_device("vent_fan")]
		"lighting":
			return [DeviceManager.get_device("light_sensor"), DeviceManager.get_device("greenhouse_lights")]
		"shading":
			return [DeviceManager.get_device("light_sensor"), DeviceManager.get_device("greenhouse_shade")]
		"leak":
			return [DeviceManager.get_device("leak_sensor"), DeviceManager.get_device("water_valve")]
		"security_light":
			return [DeviceManager.get_device("motion_sensor"), DeviceManager.get_device("light_sensor"), DeviceManager.get_device("floodlight")]
		"smoke":
			return [DeviceManager.get_device("smoke_detector"), DeviceManager.get_device("siren")]
		"lockdown":
			return [DeviceManager.get_device("light_sensor"), DeviceManager.get_device("door_contact"), DeviceManager.get_device("shed_lock")]
	return []


## Turn off whatever the rule switched on (used when a rule is disabled).
func _release(r: AutomationRule) -> void:
	var ds := _devices_for(r)
	if ds.has(null):
		return
	match r.id:
		"irrigation":
			ds[2].set_power(false)
			ds[1].set_power(false)
		"temperature":
			ds[1].set_power(false)
		"lighting", "shading":
			ds[1].set_power(false)
		"leak":
			ds[1].set_power(true)  # releasing leak protection reopens the valve
		"security_light":
			(ds[2] as SmartFloodlight).set_power_from(false, "Automation disabled")
		"smoke":
			ds[1].set_power(false)
		"lockdown":
			pass  # never unlock a door just because a rule was switched off


func _evaluate(r: AutomationRule, dt := 0.0) -> void:
	if not r.enabled:
		_set_status(r, "Disabled")
		return
	if not DeviceManager.is_hub_online():
		r.zone = ""
		_set_status(r, "Paused - hub offline")
		return
	var ds := _devices_for(r)
	if ds.has(null):
		_set_status(r, "Missing device")
		return
	for d in ds:
		if not d.online:
			r.zone = ""
			_set_status(r, "Waiting - %s offline" % d.device_name)
			return
	match r.id:
		"irrigation":
			_eval_irrigation(r, ds[0], ds[1], ds[2])
		"temperature":
			_eval_temperature(r, ds[0], ds[1])
		"lighting":
			_eval_lighting(r, ds[0], ds[1])
		"shading":
			_eval_shading(r, ds[0], ds[1])
		"leak":
			_eval_leak(r, ds[0], ds[1])
		"security_light":
			_eval_security_light(r, ds[0], ds[1], ds[2], dt)
		"smoke":
			_eval_smoke(r, ds[0], ds[1])
		"lockdown":
			_eval_lockdown(r, ds[0], ds[1], ds[2])


func _eval_irrigation(r: AutomationRule, soil: MoistureSensor, plug: SmartPlug, pump: IrrigationPump) -> void:
	var m: float = soil.moisture
	var z := "dry" if m < IRRIGATION_START else ("wet" if m >= IRRIGATION_STOP else "ok")
	if z != r.zone:
		r.zone = z
		if z == "dry" and not pump.is_running():
			plug.set_power(true)
			pump.set_power(true)
			r.engaged = true
			_fire(r, "Soil moisture %.0f%% - irrigation started" % m)
		elif z == "wet" and (pump.power_on or plug.power_on):
			pump.set_power(false)
			plug.set_power(false)
			r.engaged = false
			_fire(r, "Soil moisture %.0f%% - irrigation stopped" % m)
	if not pump.is_running():
		r.engaged = false
	if pump.power_on and not pump.has_water():
		_set_status(r, "Waiting - main water valve closed")
	else:
		_set_status(r, "Active - irrigating" if pump.is_running() else "Monitoring")


func _eval_temperature(r: AutomationRule, sensor: TemperatureSensor, fan: VentilationFan) -> void:
	var t: float = sensor.temperature
	var z := "hot" if t > FAN_ON else ("cool" if t < FAN_OFF else "ok")
	if z != r.zone:
		r.zone = z
		if z == "hot" and not fan.power_on:
			fan.set_power(true)
			r.engaged = true
			_fire(r, "Greenhouse %.1f°C - ventilation ON" % t)
		elif z == "cool" and fan.power_on:
			fan.set_power(false)
			r.engaged = false
			_fire(r, "Greenhouse %.1f°C - ventilation OFF" % t)
	if not fan.power_on:
		r.engaged = false
	_set_status(r, "Active - fans running" if fan.power_on else "Monitoring")


func _eval_lighting(r: AutomationRule, sensor: LightSensor, lights: SmartLight) -> void:
	var l: float = sensor.light_level
	var z := "dark" if l < LIGHT_ON else ("bright" if l >= LIGHT_OFF else "ok")
	if z != r.zone:
		r.zone = z
		if z == "dark" and not lights.power_on:
			lights.set_power(true)
			r.engaged = true
			_fire(r, "Ambient light %.0f%% - grow lights ON" % l)
		elif z == "bright" and lights.power_on:
			lights.set_power(false)
			r.engaged = false
			_fire(r, "Ambient light %.0f%% - grow lights OFF" % l)
	if not lights.power_on:
		r.engaged = false
	_set_status(r, "Active - lights on" if lights.power_on else "Monitoring")


func _eval_shading(r: AutomationRule, sensor: LightSensor, shade: SmartShade) -> void:
	var l: float = sensor.light_level
	var z := "bright" if l >= SHADE_CLOSE else ("dim" if l < SHADE_OPEN else "ok")
	if z != r.zone:
		r.zone = z
		if z == "bright" and not shade.power_on:
			shade.set_power(true)
			r.engaged = true
			_fire(r, "Strong sun (%.0f%%) - shade screen closing" % l)
		elif z == "dim" and shade.power_on:
			shade.set_power(false)
			r.engaged = false
			_fire(r, "Light %.0f%% - shade screen opening" % l)
	if not shade.power_on:
		r.engaged = false
	_set_status(r, "Active - shading" if shade.power_on else "Monitoring")


func _eval_leak(r: AutomationRule, leak: LeakSensor, valve: SmartValve) -> void:
	var z := "wet" if leak.wet else "dry"
	if z != r.zone:
		r.zone = z
		if z == "wet":
			var pump := DeviceManager.get_device("irrigation_pump")
			if pump and pump.online:
				pump.set_power(false)
			if valve.power_on:
				valve.set_power(false)
			r.engaged = true
			_fire(r, "Water leak detected - main valve closed, pump stopped")
	# Reopen only once the ground is dry AND the fitting is repaired;
	# reopening earlier would just restart the leak.
	if r.engaged and not leak.wet and not leak.leak_source:
		if valve.set_power(true):
			r.engaged = false
			_fire(r, "Leak cleared and repaired - main valve reopened")
	if r.engaged:
		_set_status(r, "Active - valve closed (leak)" if leak.wet else "Active - valve closed, repair the fitting")
	else:
		_set_status(r, "Monitoring")


func _eval_security_light(r: AutomationRule, motion: MotionSensor, sensor: LightSensor, flood: SmartFloodlight, dt: float) -> void:
	var dark: bool = sensor.light_level < LIGHT_ON
	var z := "triggered" if motion.motion and dark else "idle"
	if z != r.zone:
		r.zone = z
		if z == "triggered" and not flood.power_on:
			flood.set_power_from(true, "Automation (motion)")
			r.engaged = true
			r.timer = 0.0
			_fire(r, "Motion at the shed after dark - floodlight ON")
	if r.engaged:
		if motion.motion and dark:
			r.timer = 0.0
		else:
			r.timer += dt
			if r.timer >= FLOOD_HOLD or not dark:
				flood.set_power_from(false, "Automation (no motion)")
				r.engaged = false
				r.timer = 0.0
				_fire(r, ("No motion for %d s - floodlight OFF" % int(FLOOD_HOLD)) if dark else "Daylight - floodlight OFF")
		if not flood.power_on:
			r.engaged = false
	if r.engaged:
		_set_status(r, "Active - floodlight on" + ("" if motion.motion else " (off in %d s)" % ceili(FLOOD_HOLD - r.timer)))
	else:
		_set_status(r, "Monitoring" if dark else "Monitoring (armed after dark)")


func _eval_smoke(r: AutomationRule, detector: SmokeDetector, siren: SmartSiren) -> void:
	var z := "alarm" if detector.alarm else "clear"
	if z != r.zone:
		r.zone = z
		if z == "alarm":
			siren.set_power(true)
			var lock := DeviceManager.get_device("shed_lock") as SmartLock
			var extra := ""
			if lock and lock.online and lock.power_on:
				lock.set_power(false)
				extra = ", shed door unlocked"
			r.engaged = true
			_fire(r, "SMOKE DETECTED - siren ON%s" % extra)
		elif r.engaged and siren.power_on:
			siren.set_power(false)
			r.engaged = false
			_fire(r, "Smoke cleared - siren OFF")
	if not siren.power_on:
		r.engaged = false
	_set_status(r, "Active - ALARM sounding" if siren.power_on and detector.alarm else "Monitoring")


func _eval_lockdown(r: AutomationRule, sensor: LightSensor, contact: ContactSensor, lock: SmartLock) -> void:
	var l: float = sensor.light_level
	var z := "dark" if l < LIGHT_ON else ("bright" if l >= LIGHT_OFF else "ok")
	if z != r.zone:
		r.zone = z
		if z == "dark" and not lock.power_on:
			r.engaged = true  # lock pending
			if contact.contact_open:
				_fire(r, "Dusk - shed door is open, will lock once it closes")
		elif z == "bright":
			r.engaged = false
	if r.engaged:
		if lock.power_on:
			r.engaged = false
		elif not contact.contact_open and lock.set_power(true):
			r.engaged = false
			_fire(r, "Dusk - shed door locked")
	if r.engaged:
		_set_status(r, "Waiting - shed door open")
	else:
		_set_status(r, "Monitoring - door locked" if lock.power_on else "Monitoring")


# ------------------------------------------------------------ scenarios ---

## Push the simulation into a state that triggers the given automation.
func trigger_scenario(id: String) -> String:
	match id:
		"irrigation":
			var soil := DeviceManager.get_device("soil_sensor") as MoistureSensor
			if soil:
				soil.moisture = 22.0
				soil.notify_reading()
			return "Scenario: soil dried out to 22%"
		"temperature":
			EnvironmentManager.trigger_heat_wave()
			var ts := DeviceManager.get_device("temp_sensor") as TemperatureSensor
			if ts:
				ts.temperature = 35.5
				ts.notify_reading()
			return "Scenario: heat wave - greenhouse at 35.5°C"
		"lighting":
			EnvironmentManager.set_time(17.6)
			_refresh_light_sensor()
			return "Scenario: time jumped to dusk (17:36)"
		"daytime":
			EnvironmentManager.set_time(10.0)
			_refresh_light_sensor()
			return "Time set to 10:00"
		"shading":
			EnvironmentManager.set_time(12.0)
			_refresh_light_sensor()
			return "Scenario: midday sun (12:00) on the greenhouse"
		"leak":
			var ls := DeviceManager.get_device("leak_sensor") as LeakSensor
			if ls:
				ls.start_leak()
			return "Scenario: a fitting on the irrigation main burst"
		"security_light":
			EnvironmentManager.set_time(21.0)
			_refresh_light_sensor()
			var mo := DeviceManager.get_device("motion_sensor") as MotionSensor
			if mo:
				mo.simulate_motion("Simulated intruder")
			return "Scenario: 21:00 - something moves near the shed"
		"smoke":
			var sd := DeviceManager.get_device("smoke_detector") as SmokeDetector
			if sd:
				sd.start_smoke()
			return "Scenario: a cable smoulders in the control-station cabinet"
		"lockdown":
			var lock := DeviceManager.get_device("shed_lock") as SmartLock
			if lock:
				lock.set_power(false)
				lock.set_door_open(true)
			var rule := get_rule("lockdown")
			if rule:
				rule.zone = ""  # re-arm the dusk edge even if it is already dark
			EnvironmentManager.set_time(17.6)
			_refresh_light_sensor()
			return "Scenario: shed door left open at dusk (17:36) - close it and watch it lock"
	return ""


func _refresh_light_sensor() -> void:
	var ls := DeviceManager.get_device("light_sensor")
	if ls:
		ls.simulate(0.0)
