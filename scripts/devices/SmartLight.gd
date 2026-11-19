class_name SmartLight
extends VirtualDevice
## Greenhouse LED grow-light circuit: several hanging fixtures with emissive
## panels plus a quality-dependent number of real OmniLights. The device origin
## is the greenhouse centre; the wall switch panel is where players interact.

const FIXTURES := [
	Vector3(-5.0, 2.65, -3.2), Vector3(-1.7, 2.65, -3.2), Vector3(1.7, 2.65, -3.2), Vector3(5.0, 2.65, -3.2),
	Vector3(-5.2, 2.65, 2.4), Vector3(-2.9, 2.65, 2.4), Vector3(2.9, 2.65, 2.4), Vector3(5.2, 2.65, 2.4),
]
const LIGHT_POINTS := [Vector3(-3.4, 2.4, -3.2), Vector3(3.4, 2.4, -3.2), Vector3(-4.0, 2.4, 2.4), Vector3(4.0, 2.4, 2.4)]
const LIGHT_COLOR := Color(1.0, 0.78, 0.92)

@export var panel_position := Vector3(2.3, 1.3, 4.82)
@export var ceiling_height := 3.05

var brightness := 0.0
var _panel_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []


func _init() -> void:
	super()
	device_name = "Greenhouse Grow Lights"
	device_type = "Smart LED Lighting (8 fixtures)"
	category = "Lighting"


func is_controllable() -> bool:
	return true


func get_primary_reading() -> String:
	return "ON - 100 %" if power_on else "OFF"


func get_readings() -> Array:
	return [
		["Lights", "ON" if power_on else "OFF"],
		["Fixtures", "%d LED panels" % FIXTURES.size()],
		["Brightness", "%d %%" % int(brightness * 100.0)],
		["Power draw", "%d W" % int(brightness * 8.0 * 120.0)],
	]


func _build_model() -> void:
	_panel_mat = Mats.emissive(LIGHT_COLOR, 0.0)
	_panel_mat.albedo_color = Color(0.85, 0.85, 0.88)
	var housing := Mats.get_mat("metal_dark")
	var cable := Mats.get_mat("rubber")
	for p in FIXTURES:
		ProcMesh.box(self, Vector3(1.3, 0.07, 0.32), p, housing)
		ProcMesh.box(self, Vector3(1.22, 0.012, 0.26), p + Vector3(0, -0.04, 0), _panel_mat, Vector3.ZERO, false)
		for dx: float in [-0.5, 0.5]:
			ProcMesh.cyl_between(self, p + Vector3(dx, 0.03, 0), Vector3(p.x + dx, ceiling_height, p.z), 0.006, cable, 4, false)
	# wall switch panel next to the greenhouse door
	ProcMesh.box(self, Vector3(0.28, 0.4, 0.06), panel_position, Mats.get_mat("plastic_white"))
	ProcMesh.box(self, Vector3(0.18, 0.18, 0.01), panel_position + Vector3(0, 0.05, -0.035), Mats.get_mat("plastic_dark"), Vector3.ZERO, false)
	_make_led(self, panel_position + Vector3(0.0, -0.12, -0.035), 0.018)
	var lbl := ProcMesh.label3d(self, "GROW LIGHTS", panel_position + Vector3(0, -0.07, -0.036), 14, Color(0.15, 0.15, 0.2), false)
	lbl.rotation_degrees = Vector3(0, 180, 0)
	_rebuild_lights()
	GameSettings.quality_changed.connect(func(_p: String) -> void: _rebuild_lights())


func _rebuild_lights() -> void:
	for l in _lights:
		l.queue_free()
	_lights.clear()
	var count: int = GameSettings.q("greenhouse_lights")
	var pts: Array = LIGHT_POINTS.slice(0, count) if count >= 4 else ([Vector3(-3.6, 2.4, -0.4), Vector3(3.6, 2.4, -0.4)] if count == 2 else [])
	for p in pts:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = LIGHT_COLOR
		l.omni_range = 6.5 if count >= 4 else 8.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l)
	_apply_brightness()


func _update_visuals() -> void:
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if power_on else 0.0
	brightness = move_toward(brightness, target, delta * 2.5)
	_apply_brightness()
	if is_equal_approx(brightness, target):
		set_process(false)


func _apply_brightness() -> void:
	if _panel_mat:
		_panel_mat.emission_energy_multiplier = brightness * 4.0
	var per_light := 2.4 if _lights.size() >= 4 else 3.2
	for l in _lights:
		l.light_energy = brightness * per_light
		l.visible = brightness > 0.01
