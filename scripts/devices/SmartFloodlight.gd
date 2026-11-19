class_name SmartFloodlight
extends VirtualDevice
## LED security floodlight above the shed door (SmartThings "switch" +
## "switch level"). Driven by the security-lighting automation when motion
## is detected after dark. A real SpotLight3D is used on Medium/High; Low
## keeps only the emissive lens.

@export var head_position := Vector3(0, 2.75, -0.12)

var brightness := 0.0
var trigger_source := "-"
var _pending_source := ""
var _lens_mat: StandardMaterial3D
var _light: SpotLight3D


func _init() -> void:
	super()
	device_name = "Security Floodlight"
	device_type = "Smart LED Floodlight (30 W)"
	category = "Security"


func is_controllable() -> bool:
	return true


func get_power_label() -> String:
	return "Light"


func get_primary_reading() -> String:
	return "ON - 3000 lm" if power_on else "OFF"


func get_readings() -> Array:
	return [
		["Light", "On" if power_on else "Off"],
		["Brightness", "%d %%" % int(brightness * 100.0)],
		["Output", "3000 lm" if power_on else "0 lm"],
		["Power draw", "%d W" % int(brightness * 30.0)],
		["Last switched by", trigger_source],
	]


func _on_power_changed() -> void:
	trigger_source = _pending_source if not _pending_source.is_empty() else "Manual"


## Used by automations so the panel can show who switched it.
func set_power_from(on: bool, source: String) -> bool:
	_pending_source = source
	var ok := set_power(on)
	_pending_source = ""
	return ok


func _build_model() -> void:
	var dark := Mats.get_mat("metal_dark")
	var h := head_position
	ProcMesh.box(self, Vector3(0.12, 0.12, 0.04), h + Vector3(0, 0.08, 0.1), dark)
	ProcMesh.cyl(self, 0.015, 0.015, 0.16, h + Vector3(0, 0.05, 0.04), dark, Vector3(90, 0, 0), 6, false)
	var head := Node3D.new()
	head.position = h
	head.rotation_degrees = Vector3(-40, 0, 0)
	add_child(head)
	ProcMesh.box(head, Vector3(0.32, 0.22, 0.08), Vector3(0, 0, 0), dark)
	for i in 5:
		ProcMesh.box(head, Vector3(0.012, 0.2, 0.04), Vector3(-0.12 + i * 0.06, 0, 0.055), dark, Vector3.ZERO, false)
	_lens_mat = Mats.emissive(Color(1.0, 0.96, 0.88), 0.0)
	_lens_mat.albedo_color = Color(0.85, 0.85, 0.82)
	ProcMesh.box(head, Vector3(0.28, 0.18, 0.01), Vector3(0, 0, -0.045), _lens_mat, Vector3.ZERO, false)
	_make_led(self, h + Vector3(0.05, 0.13, 0.075), 0.01)
	_light = SpotLight3D.new()
	_light.position = Vector3(0, 0, -0.08)
	_light.light_color = Color(1.0, 0.96, 0.9)
	_light.spot_range = 14.0
	_light.spot_angle = 52.0
	_light.spot_attenuation = 0.8
	_light.shadow_enabled = false
	_light.visible = false
	head.add_child(_light)


func _update_visuals() -> void:
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if power_on else 0.0
	brightness = move_toward(brightness, target, delta * 4.0)
	if _lens_mat:
		_lens_mat.emission_energy_multiplier = brightness * 6.0
	if _light:
		var allow: bool = int(GameSettings.q("greenhouse_lights")) >= 2
		_light.visible = allow and brightness > 0.01
		_light.light_energy = brightness * 5.0
	if is_equal_approx(brightness, target):
		set_process(false)
