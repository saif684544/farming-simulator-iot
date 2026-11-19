extends Node
## Simulated world state: time of day, ambient light level and the outdoor /
## greenhouse thermal model. Advanced by DeviceManager's fixed simulation tick
## so everything stays deterministic and testable.

signal time_changed(hours: float)
signal phase_changed(phase: String)

const DEFAULT_DAY_SECONDS := 360.0  ## one in-game day = 6 real minutes at 1x

var time_of_day := 14.0
var time_speed := 1.0
var day_length_seconds := DEFAULT_DAY_SECONDS
var heat_boost := 0.0  ## extra degrees C from the "heat wave" scenario, decays over time
var _phase := ""


func advance(dt: float) -> void:
	if time_speed > 0.0:
		time_of_day = fposmod(time_of_day + dt * time_speed * 24.0 / day_length_seconds, 24.0)
	heat_boost = move_toward(heat_boost, 0.0, dt * 0.05)
	time_changed.emit(time_of_day)
	_update_phase()


func set_time(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	time_changed.emit(time_of_day)
	_update_phase()


func set_time_speed(speed: float) -> void:
	time_speed = maxf(speed, 0.0)


## -1 (midnight) .. 1 (noon)
func get_sun_height() -> float:
	return sin((time_of_day - 6.0) / 12.0 * PI)


## 0..1 ambient daylight (outdoor light sensor model).
func get_ambient_light() -> float:
	return clampf(get_sun_height() * 1.3 + 0.1, 0.0, 1.0) * 0.98 + 0.02


func get_light_percent() -> float:
	return get_ambient_light() * 100.0


func get_outdoor_temperature() -> float:
	return 16.0 + 9.0 * maxf(get_sun_height(), 0.0) + heat_boost * 0.5


## Temperature the greenhouse air drifts towards with no ventilation.
func get_greenhouse_target_temperature() -> float:
	return get_outdoor_temperature() + 10.0 * get_ambient_light() + heat_boost


func trigger_heat_wave(boost := 10.0) -> void:
	heat_boost = boost


func get_phase() -> String:
	var t := time_of_day
	if t < 5.0:
		return "Night"
	if t < 7.0:
		return "Dawn"
	if t < 11.0:
		return "Morning"
	if t < 14.0:
		return "Midday"
	if t < 17.0:
		return "Afternoon"
	if t < 19.5:
		return "Evening"
	return "Night"


func format_time() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _update_phase() -> void:
	var p := get_phase()
	if p != _phase:
		_phase = p
		phase_changed.emit(p)
