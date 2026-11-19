class_name Sprinkler
extends Node3D
## Water sprinkler head. Not an IoT device on its own - the IrrigationPump
## activates every node in the "sprinkler" group.

@export var rotating := false     ## outdoor impact sprinkler that sweeps around
@export var with_audio := false
@export var reach := 1.0          ## spray strength multiplier

var active := false
var _particles: CPUParticles3D
var _head: Node3D
var _audio: AudioStreamPlayer3D
var _base_amount := 60


func _ready() -> void:
	add_to_group("sprinkler")
	_head = Node3D.new()
	add_child(_head)
	var metal := Mats.get_mat("metal")
	ProcMesh.cyl(self, 0.025, 0.03, 0.12, Vector3(0, 0.06, 0), Mats.get_mat("plastic_dark"), Vector3.ZERO, 8, false)
	if rotating:
		ProcMesh.cyl(_head, 0.02, 0.02, 0.1, Vector3(0, 0.16, 0), metal, Vector3.ZERO, 8, false)
		ProcMesh.cyl(_head, 0.015, 0.02, 0.22, Vector3(0.08, 0.22, 0), metal, Vector3(0, 0, -60), 8, false)
		ProcMesh.box(_head, Vector3(0.12, 0.02, 0.03), Vector3(-0.04, 0.24, 0), Mats.get_mat("red"), Vector3.ZERO, false)
	else:
		ProcMesh.cyl(_head, 0.045, 0.03, 0.04, Vector3(0, 0.14, 0), metal, Vector3.ZERO, 10, false)

	_particles = CPUParticles3D.new()
	_particles.emitting = false
	_particles.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	q.material = Mats.get_mat("water_drop")
	_particles.mesh = q
	_particles.lifetime = 1.0
	_particles.gravity = Vector3(0, -9.8, 0)
	_particles.scale_amount_min = 0.6
	_particles.scale_amount_max = 1.6
	_particles.color = Color(0.72, 0.88, 1.0, 0.9)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	_particles.color_ramp = ramp
	if rotating:
		_base_amount = 90
		_particles.position = Vector3(0.16, 0.3, 0)
		_particles.direction = Vector3(1, 0.55, 0)
		_particles.spread = 9.0
		_particles.initial_velocity_min = 5.0 * reach
		_particles.initial_velocity_max = 6.5 * reach
		_particles.lifetime = 1.2
		_head.add_child(_particles)
	else:
		_base_amount = 50
		_particles.position = Vector3(0, 0.17, 0)
		_particles.direction = Vector3(0, 1, 0)
		_particles.spread = 70.0
		_particles.initial_velocity_min = 1.6 * reach
		_particles.initial_velocity_max = 2.6 * reach
		add_child(_particles)
	_particles.cast_shadow = ProcMesh.NO_SHADOW
	_apply_quality()
	GameSettings.quality_changed.connect(func(_p: String) -> void: _apply_quality())
	if with_audio:
		_audio = AudioManager.make_3d_player("water", self, -6.0, 20.0)
	set_process(false)


func _apply_quality() -> void:
	_particles.amount = maxi(int(_base_amount * float(GameSettings.q("particles"))), 8)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_particles.emitting = on
	set_process(on and rotating)
	if _audio:
		if on:
			_audio.play()
		else:
			_audio.stop()


func _process(delta: float) -> void:
	_head.rotate_y(delta * 1.4)
