class_name SmartSiren
extends VirtualDevice
## Outdoor siren + strobe on the control-station post (SmartThings "alarm"
## capability). power_on = sounding. The smoke-alarm automation drives it;
## it can also be silenced or tested manually.

@export var head_position := Vector3(0, 2.35, -0.1)

var strobe := 0.0
var activations := 0
var _beacon: Node3D
var _beacon_mat: StandardMaterial3D
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _t := 0.0


func _init() -> void:
	super()
	device_name = "Outdoor Siren"
	device_type = "Smart Siren + Strobe"
	category = "Safety"


func is_controllable() -> bool:
	return true


func is_alert() -> bool:
	return power_on


func get_power_label() -> String:
	return "Siren"


func get_power_state_text(on: bool) -> String:
	return "SOUNDING" if on else "SILENT"


func get_power_action_text(on: bool) -> String:
	return "Sound siren" if on else "Silence"


func _status_online() -> String:
	return "SOUNDING" if power_on else "Standby"


func get_primary_reading() -> String:
	return "ALARM - siren + strobe" if power_on else "Standby"


func get_readings() -> Array:
	return [
		["Siren", "Sounding" if power_on else "Silent"],
		["Strobe", "Flashing" if power_on else "Off"],
		["Volume", "105 dB (simulated)"],
		["Activations", str(activations)],
		["Backup battery", "100 %"],
	]


func _on_power_changed() -> void:
	if power_on:
		activations += 1


func _build_model() -> void:
	var h := head_position
	var white := Mats.get_mat("plastic_white")
	ProcMesh.box(self, Vector3(0.24, 0.28, 0.1), h, white)
	for i in 4:
		ProcMesh.box(self, Vector3(0.18, 0.012, 0.01), h + Vector3(0, -0.09 + i * 0.045, -0.052), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_make_led(self, h + Vector3(0.09, 0.11, -0.052), 0.008)
	_beacon_mat = Mats.emissive(Color(1.0, 0.12, 0.08), 0.0)
	_beacon_mat.albedo_color = Color(0.7, 0.1, 0.08)
	_beacon = Node3D.new()
	_beacon.position = h + Vector3(0, 0.2, 0)
	add_child(_beacon)
	ProcMesh.cyl(_beacon, 0.06, 0.07, 0.12, Vector3.ZERO, _beacon_mat, Vector3.ZERO, 16, false)
	ProcMesh.box(_beacon, Vector3(0.02, 0.1, 0.13), Vector3(0, 0, 0), Mats.get_mat("metal"), Vector3.ZERO, false)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.15, 0.1)
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.visible = false
	_beacon.add_child(_light)
	_audio = AudioManager.make_3d_player("siren", self, -12.0, 40.0)
	_audio.position = h


func _update_visuals() -> void:
	if _audio == null:
		return
	if power_on and not _audio.playing:
		_audio.play()
	elif not power_on:
		_audio.stop()
	set_process(power_on)
	if not power_on:
		_beacon_mat.emission_energy_multiplier = 0.0
		_light.visible = false


func _process(delta: float) -> void:
	_t += delta
	_beacon.rotate_y(delta * 9.0)
	var flash := 1.0 if fmod(_t, 0.6) < 0.25 else 0.15
	_beacon_mat.emission_energy_multiplier = 6.0 * flash
	_light.visible = int(GameSettings.q("greenhouse_lights")) >= 2
	_light.light_energy = 2.5 * flash
