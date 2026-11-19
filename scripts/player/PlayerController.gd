class_name PlayerController
extends CharacterBody3D
## Third-person farm technician. Reads input exclusively through InputManager,
## uses a SpringArm3D camera for collision-aware follow, and continuously picks
## the best nearby VirtualDevice as interaction target.

signal interaction_target_changed(device: VirtualDevice)

@export var walk_speed := 4.2
@export var sprint_speed := 7.5
@export var acceleration := 14.0
@export var air_control := 0.35
@export var jump_velocity := 4.6
@export var turn_speed := 10.0
@export var camera_distance := 4.2
@export var pitch_min := -65.0
@export var pitch_max := 30.0

var current_target: VirtualDevice
var camera: Camera3D
var _rig: Node3D
var _pitch: Node3D
var _arm: SpringArm3D
var _model: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _walk_phase := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _target_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	_build_model()
	_build_camera()


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	_rig.top_level = true
	add_child(_rig)
	_rig.global_position = global_position + Vector3(0, 1.55, 0)
	_rig.rotation.y = rotation.y
	_pitch = Node3D.new()
	_pitch.rotation_degrees.x = -14.0
	_rig.add_child(_pitch)
	_arm = SpringArm3D.new()
	_arm.spring_length = camera_distance
	_arm.collision_mask = 1
	_arm.margin = 0.15
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	_arm.shape = sph
	_arm.add_excluded_object(get_rid())
	_arm.position = Vector3(0.45, 0, 0)  # slight over-the-shoulder offset
	_pitch.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 600.0
	camera.current = true
	_arm.add_child(camera)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var jacket := Mats.get_mat("jacket")
	var denim := Mats.get_mat("denim")
	var skin := Mats.get_mat("skin")
	var vest := Mats.get_mat("hivis")
	var boots := Mats.get_mat("rubber")
	# legs (pivot at hip)
	for sx: float in [-0.12, 0.12]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.9, 0)
		_model.add_child(hip)
		ProcMesh.cyl(hip, 0.075, 0.065, 0.8, Vector3(0, -0.42, 0), denim, Vector3.ZERO, 10)
		ProcMesh.box(hip, Vector3(0.14, 0.1, 0.26), Vector3(0, -0.85, 0.04), boots)
		_legs.append(hip)
	# torso
	ProcMesh.cyl(_model, 0.2, 0.17, 0.62, Vector3(0, 1.22, 0), jacket, Vector3.ZERO, 14)
	ProcMesh.cyl(_model, 0.215, 0.185, 0.4, Vector3(0, 1.28, 0), vest, Vector3.ZERO, 14)
	ProcMesh.box(_model, Vector3(0.36, 0.05, 0.02), Vector3(0, 1.3, 0.19), Mats.get_mat("plastic_white"), Vector3.ZERO, false)
	ProcMesh.cyl(_model, 0.19, 0.19, 0.1, Vector3(0, 0.92, 0), denim, Vector3.ZERO, 14)
	# backpack with tablet
	ProcMesh.box(_model, Vector3(0.3, 0.38, 0.14), Vector3(0, 1.28, -0.24), Mats.get_mat("plastic_dark"))
	ProcMesh.box(_model, Vector3(0.26, 0.04, 0.12), Vector3(0, 1.48, -0.24), Mats.get_mat("plastic_blue"))
	# arms (pivot at shoulder)
	for sx: float in [-0.26, 0.26]:
		var sh := Node3D.new()
		sh.position = Vector3(sx, 1.48, 0)
		_model.add_child(sh)
		ProcMesh.cyl(sh, 0.06, 0.055, 0.6, Vector3(0, -0.3, 0), jacket, Vector3.ZERO, 10)
		ProcMesh.sphere(sh, 0.055, Vector3(0, -0.63, 0), skin, Vector3.ONE, 8)
		_arms.append(sh)
	# head + cap
	ProcMesh.cyl(_model, 0.06, 0.07, 0.1, Vector3(0, 1.57, 0), skin, Vector3.ZERO, 8)
	ProcMesh.sphere(_model, 0.13, Vector3(0, 1.72, 0), skin, Vector3(1, 1.1, 1), 14)
	ProcMesh.cyl(_model, 0.135, 0.14, 0.08, Vector3(0, 1.82, 0), Mats.get_mat("plastic_green"), Vector3.ZERO, 14)
	ProcMesh.sphere(_model, 0.135, Vector3(0, 1.84, 0), Mats.get_mat("plastic_green"), Vector3(1, 0.5, 1), 14)
	ProcMesh.box(_model, Vector3(0.22, 0.02, 0.14), Vector3(0, 1.8, 0.16), Mats.get_mat("plastic_green"))
	# eyes
	for sx: float in [-0.045, 0.045]:
		ProcMesh.sphere(_model, 0.016, Vector3(sx, 1.74, 0.12), Mats.get_mat("plastic_dark"), Vector3.ONE, 6, false)


func set_view_yaw(yaw: float) -> void:
	_rig.rotation.y = yaw
	_model.rotation.y = yaw + PI


func _physics_process(delta: float) -> void:
	# camera look
	var look := InputManager.consume_look_delta(delta)
	_rig.rotation.y -= look.x
	_pitch.rotation.x = clampf(_pitch.rotation.x - look.y, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

	# movement relative to camera yaw
	var input := InputManager.get_move_vector()
	var yaw_basis := Basis(Vector3.UP, _rig.rotation.y)
	var dir := yaw_basis * Vector3(input.x, 0, input.y)
	var speed := sprint_speed if InputManager.is_sprinting() else walk_speed
	var target_v := dir * speed
	var accel := acceleration if is_on_floor() else acceleration * air_control
	velocity.x = move_toward(velocity.x, target_v.x, accel * delta * maxf(speed, 1.0))
	velocity.z = move_toward(velocity.z, target_v.z, accel * delta * maxf(speed, 1.0))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif InputManager.consume_jump():
		velocity.y = jump_velocity
	move_and_slide()
	if global_position.y < -10.0:
		global_position = Vector3(0, 1, 20)
		velocity = Vector3.ZERO

	# face movement direction
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.3:
		var target_yaw := atan2(velocity.x, velocity.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	_animate(delta, hv.length())

	# smooth camera follow
	var follow := global_position + Vector3(0, 1.55, 0)
	_rig.global_position = _rig.global_position.lerp(follow, clampf(delta * 14.0, 0.0, 1.0))

	_target_timer -= delta
	if _target_timer <= 0.0:
		_target_timer = 0.1
		_update_target()


func _animate(delta: float, speed: float) -> void:
	var moving := speed > 0.2 and is_on_floor()
	if moving:
		_walk_phase += delta * speed * 2.4
	var amp := clampf(speed / sprint_speed, 0.0, 1.0) * 0.9 if moving else 0.0
	var swing := sin(_walk_phase) * amp
	for i in _legs.size():
		var s := swing if i == 0 else -swing
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, s, clampf(delta * 12.0, 0.0, 1.0))
	for i in _arms.size():
		var s2 := -swing * 0.8 if i == 0 else swing * 0.8
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, s2, clampf(delta * 12.0, 0.0, 1.0))
	_model.position.y = absf(sin(_walk_phase)) * 0.04 * amp


## Pick the best device in range: closest, with a bonus for being in front.
func _update_target() -> void:
	var best: VirtualDevice = null
	var best_score := INF
	var fwd := Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))
	for d in DeviceManager.get_all_devices():
		var p := d.get_interact_position()
		var to := p - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > d.interact_radius:
			continue
		var facing := fwd.dot(to.normalized()) if dist > 0.01 else 1.0
		var score := dist - facing * 0.6
		if score < best_score:
			best_score = score
			best = d
	if best != current_target:
		if current_target and is_instance_valid(current_target):
			current_target.set_highlighted(false)
		current_target = best
		if best:
			best.set_highlighted(true)
		interaction_target_changed.emit(best)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_rig.global_position = pos + Vector3(0, 1.55, 0)
	set_view_yaw(yaw)


func get_camera_yaw() -> float:
	return _rig.rotation.y
