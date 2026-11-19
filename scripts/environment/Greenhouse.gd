extends Node3D
## Modern glass greenhouse, built procedurally around its local origin.
## Footprint x[-8,8] z[-5,5], walls 3 m, gable ridge at 5 m along X.
## Door opening in the south wall (local +Z) at x[-1,1].
##
## The IoT devices that live in the greenhouse (fans, grow lights, sensors)
## are separate device scenes placed in Main.tscn.

const W := 16.0
const D := 10.0
const WALL_H := 3.0
const RIDGE_H := 5.0
const DOOR_HALF := 1.0
const DOOR_H := 2.4

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 99
	_build_floor()
	_build_frame()
	_build_glass()
	_build_collision()
	_build_beds()
	_build_irrigation()
	_build_shelves()
	_build_sign()


func _build_floor() -> void:
	ProcMesh.box(self, Vector3(W + 0.4, 0.04, D + 0.4), Vector3(0, 0.0, 0), Mats.get_mat("concrete"), Vector3.ZERO, false)
	# low aluminium kick-plate along the walls
	var kick := Mats.get_mat("metal")
	ProcMesh.box(self, Vector3(W, 0.3, 0.06), Vector3(0, 0.15, -D * 0.5), kick)
	ProcMesh.box(self, Vector3(W * 0.5 - DOOR_HALF, 0.3, 0.06), Vector3(-(W * 0.25 + DOOR_HALF * 0.5), 0.15, D * 0.5), kick)
	ProcMesh.box(self, Vector3(W * 0.5 - DOOR_HALF, 0.3, 0.06), Vector3(W * 0.25 + DOOR_HALF * 0.5, 0.15, D * 0.5), kick)
	for sx: float in [-1.0, 1.0]:
		ProcMesh.box(self, Vector3(0.06, 0.3, D), Vector3(sx * W * 0.5, 0.15, 0), kick)


func _build_frame() -> void:
	var f := Mats.get_mat("frame")
	var t := 0.09
	# columns on the long walls
	var x := -W * 0.5
	while x <= W * 0.5 + 0.01:
		ProcMesh.box(self, Vector3(t, WALL_H, t), Vector3(x, WALL_H * 0.5, -D * 0.5), f)
		if absf(x) > DOOR_HALF + 0.2:
			ProcMesh.box(self, Vector3(t, WALL_H, t), Vector3(x, WALL_H * 0.5, D * 0.5), f)
		x += 2.0
	# door posts + lintel
	for sx: float in [-DOOR_HALF, DOOR_HALF]:
		ProcMesh.box(self, Vector3(t, WALL_H, t), Vector3(sx, WALL_H * 0.5, D * 0.5), f)
	ProcMesh.box(self, Vector3(DOOR_HALF * 2.0, t, t), Vector3(0, DOOR_H, D * 0.5), f)
	# gable end columns
	for sx: float in [-1.0, 1.0]:
		for z: float in [-2.5, 0.0, 2.5]:
			var h := WALL_H + (RIDGE_H - WALL_H) * (1.0 - absf(z) / (D * 0.5))
			ProcMesh.box(self, Vector3(t, h, t), Vector3(sx * W * 0.5, h * 0.5, z), f)
	# eaves, ridge, mid rails
	for sz: float in [-1.0, 1.0]:
		ProcMesh.box(self, Vector3(W + 0.2, 0.12, 0.14), Vector3(0, WALL_H, sz * D * 0.5), f)
		ProcMesh.box(self, Vector3(W, 0.05, 0.05), Vector3(0, 1.0, sz * D * 0.5), f, Vector3.ZERO, false)
		ProcMesh.box(self, Vector3(W, 0.06, 0.06), Vector3(0, (WALL_H + RIDGE_H) * 0.5, sz * D * 0.25), f, Vector3.ZERO, false)
		# gutter
		ProcMesh.box(self, Vector3(W + 0.3, 0.1, 0.14), Vector3(0, WALL_H - 0.08, sz * (D * 0.5 + 0.12)), Mats.get_mat("metal"))
	ProcMesh.box(self, Vector3(W + 0.2, 0.14, 0.14), Vector3(0, RIDGE_H, 0), f)
	# rafters
	var rise := RIDGE_H - WALL_H
	var run := D * 0.5
	var rlen := sqrt(rise * rise + run * run)
	var ang := rad_to_deg(atan2(rise, run))
	x = -W * 0.5
	while x <= W * 0.5 + 0.01:
		ProcMesh.box(self, Vector3(0.07, 0.1, rlen), Vector3(x, (WALL_H + RIDGE_H) * 0.5, -run * 0.5), f, Vector3(-ang, 0, 0))
		ProcMesh.box(self, Vector3(0.07, 0.1, rlen), Vector3(x, (WALL_H + RIDGE_H) * 0.5, run * 0.5), f, Vector3(ang, 0, 0))
		x += 2.0
	# horizontal truss tie-beams the lights hang from
	x = -W * 0.5 + 2.0
	while x < W * 0.5:
		ProcMesh.box(self, Vector3(0.06, 0.08, D), Vector3(x, WALL_H + 0.05, 0), f, Vector3.ZERO, false)
		x += 4.0
	ProcMesh.box(self, Vector3(W, 0.06, 0.06), Vector3(0, WALL_H + 0.05, -3.2), f, Vector3.ZERO, false)
	ProcMesh.box(self, Vector3(W, 0.06, 0.06), Vector3(0, WALL_H + 0.05, 2.4), f, Vector3.ZERO, false)
	# open sliding door leaf (parked to the right of the opening, outside)
	var door := Node3D.new()
	door.position = Vector3(DOOR_HALF * 2.0 + 0.05, 0, D * 0.5 + 0.1)
	add_child(door)
	ProcMesh.box(door, Vector3(2.0, DOOR_H, 0.05), Vector3(0, DOOR_H * 0.5, 0), Mats.get_mat("glass"), Vector3.ZERO, false)
	for sx: float in [-1.0, 1.0]:
		ProcMesh.box(door, Vector3(0.07, DOOR_H, 0.07), Vector3(sx * 1.0, DOOR_H * 0.5, 0), f)
	ProcMesh.box(door, Vector3(2.0, 0.07, 0.07), Vector3(0, DOOR_H, 0), f)
	ProcMesh.box(door, Vector3(2.0, 0.07, 0.07), Vector3(0, 0.05, 0), f)
	ProcMesh.box(self, Vector3(4.2, 0.06, 0.06), Vector3(DOOR_HALF + 0.9, DOOR_H + 0.08, D * 0.5 + 0.1), Mats.get_mat("metal_dark"))


func _glass_panel(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	ProcMesh.box(self, size, pos, Mats.get_mat("glass"), rot, false)


func _build_glass() -> void:
	var gt := 0.02
	_glass_panel(Vector3(W, WALL_H, gt), Vector3(0, WALL_H * 0.5, -D * 0.5))
	var side_w := W * 0.5 - DOOR_HALF
	_glass_panel(Vector3(side_w, WALL_H, gt), Vector3(-(DOOR_HALF + side_w * 0.5), WALL_H * 0.5, D * 0.5))
	_glass_panel(Vector3(side_w, WALL_H, gt), Vector3(DOOR_HALF + side_w * 0.5, WALL_H * 0.5, D * 0.5))
	_glass_panel(Vector3(DOOR_HALF * 2.0, WALL_H - DOOR_H, gt), Vector3(0, (WALL_H + DOOR_H) * 0.5, D * 0.5))
	for sx: float in [-1.0, 1.0]:
		_glass_panel(Vector3(gt, WALL_H, D), Vector3(sx * W * 0.5, WALL_H * 0.5, 0))
		ProcMesh.triangle(self, Vector3(sx * W * 0.5, WALL_H, -D * 0.5), Vector3(sx * W * 0.5, RIDGE_H, 0), Vector3(sx * W * 0.5, WALL_H, D * 0.5), Mats.get_mat("glass"))
	var rise := RIDGE_H - WALL_H
	var run := D * 0.5
	var rlen := sqrt(rise * rise + run * run)
	var ang := rad_to_deg(atan2(rise, run))
	_glass_panel(Vector3(W, gt, rlen), Vector3(0, (WALL_H + RIDGE_H) * 0.5 + 0.03, -run * 0.5), Vector3(-ang, 0, 0))
	_glass_panel(Vector3(W, gt, rlen), Vector3(0, (WALL_H + RIDGE_H) * 0.5 + 0.03, run * 0.5), Vector3(ang, 0, 0))


func _build_collision() -> void:
	var t := 0.25
	ProcMesh.static_box(self, Vector3(W, WALL_H, t), Vector3(0, WALL_H * 0.5, -D * 0.5))
	var side_w := W * 0.5 - DOOR_HALF
	ProcMesh.static_box(self, Vector3(side_w, WALL_H, t), Vector3(-(DOOR_HALF + side_w * 0.5), WALL_H * 0.5, D * 0.5))
	ProcMesh.static_box(self, Vector3(side_w, WALL_H, t), Vector3(DOOR_HALF + side_w * 0.5, WALL_H * 0.5, D * 0.5))
	for sx: float in [-1.0, 1.0]:
		ProcMesh.static_box(self, Vector3(t, WALL_H, D), Vector3(sx * W * 0.5, WALL_H * 0.5, 0))
	# parked door leaf
	ProcMesh.static_box(self, Vector3(2.1, DOOR_H, 0.15), Vector3(DOOR_HALF * 2.0 + 0.05, DOOR_H * 0.5, D * 0.5 + 0.1))


# ------------------------------------------------------------------ beds ---

func _bed(center: Vector3, size: Vector2) -> void:
	var h := 0.55
	var wood := Mats.get_mat("wood")
	var bt := 0.08
	ProcMesh.box(self, Vector3(size.x, h, bt), center + Vector3(0, h * 0.5, -size.y * 0.5), wood)
	ProcMesh.box(self, Vector3(size.x, h, bt), center + Vector3(0, h * 0.5, size.y * 0.5), wood)
	ProcMesh.box(self, Vector3(bt, h, size.y), center + Vector3(-size.x * 0.5, h * 0.5, 0), wood)
	ProcMesh.box(self, Vector3(bt, h, size.y), center + Vector3(size.x * 0.5, h * 0.5, 0), wood)
	ProcMesh.box(self, Vector3(size.x - bt, 0.06, size.y - bt), center + Vector3(0, h - 0.04, 0), Mats.get_mat("soil"), Vector3.ZERO, false)
	ProcMesh.static_box(self, Vector3(size.x, 1.0, size.y), center + Vector3(0, 0.5, 0))


func _tomato_mesh() -> ArrayMesh:
	var parts: Array = []
	var stem := Mats.get_mat("stem")
	var leaf := Mats.get_mat("leaf")
	var leaf_dark := Mats.get_mat("leaf_dark")
	var tom := Mats.get_mat("tomato")
	parts.append([ProcMesh.cyl_mesh(0.012, 0.012, 1.25, 4), ProcMesh.xf(Vector3(0.04, 0.62, 0)), Mats.get_mat("wood_dark")])  # stake
	parts.append([ProcMesh.cyl_mesh(0.012, 0.018, 1.05, 5), ProcMesh.xf(Vector3(0, 0.52, 0)), stem])
	for i in 5:
		var y := 0.3 + i * 0.17
		var a := i * 140.0
		parts.append([ProcMesh.sphere_mesh(0.16 - i * 0.012, 7), ProcMesh.xf(Vector3(0, y, 0), Vector3(0, a, 0)) * ProcMesh.xf(Vector3(0.11, 0.0, 0), Vector3.ZERO, Vector3(1.2, 0.45, 0.8)), leaf if i % 2 == 0 else leaf_dark])
	for p: Vector3 in [Vector3(0.09, 0.45, 0.05), Vector3(-0.07, 0.6, 0.08), Vector3(0.05, 0.75, -0.09), Vector3(-0.1, 0.38, -0.04)]:
		parts.append([ProcMesh.sphere_mesh(0.04, 8), ProcMesh.xf(p), tom])
	return ProcMesh.merge(parts)


func _lettuce_mesh() -> ArrayMesh:
	var parts: Array = []
	var a := Mats.get_mat("lettuce")
	var b := Mats.get_mat("leaf")
	parts.append([ProcMesh.sphere_mesh(0.09, 8), ProcMesh.xf(Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 0.8, 1)), a])
	for i in 7:
		parts.append([ProcMesh.sphere_mesh(0.09, 7), ProcMesh.xf(Vector3(0, 0.05, 0), Vector3(0, i * 51.0, 0)) * ProcMesh.xf(Vector3(0, 0.02, 0.09), Vector3(-30, 0, 0), Vector3(0.9, 0.3, 1.25)), b if i % 2 else a])
	return ProcMesh.merge(parts)


func _build_beds() -> void:
	var north := Vector3(0, 0, -3.2)
	_bed(north, Vector2(13.2, 1.6))
	_bed(Vector3(-4.1, 0, 2.4), Vector2(5.0, 1.6))
	_bed(Vector3(4.1, 0, 2.4), Vector2(5.0, 1.6))
	var tom_t: Array = []
	for z: float in [-3.6, -2.8]:
		var x := -6.2
		while x < 6.3:
			var s := _rng.randf_range(0.85, 1.1)
			tom_t.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x + _rng.randf_range(-0.05, 0.05), 0.52, z)))
			x += 0.62
	ProcMesh.multimesh(self, _tomato_mesh(), tom_t)
	var let_t: Array = []
	for cx: float in [-4.1, 4.1]:
		for z: float in [1.95, 2.4, 2.85]:
			var x2 := cx - 2.2
			while x2 < cx + 2.25:
				var s2 := _rng.randf_range(0.85, 1.2)
				let_t.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s2), Vector3(x2, 0.52, z)))
				x2 += 0.42
	ProcMesh.multimesh(self, _lettuce_mesh(), let_t)


# ------------------------------------------------------------ irrigation ---

func _pipe(points: Array, r := 0.035) -> void:
	for i in points.size() - 1:
		ProcMesh.cyl_between(self, points[i], points[i + 1], r, Mats.get_mat("pipe"), 8, false)
	for i in range(1, points.size() - 1):
		ProcMesh.sphere(self, r * 1.4, points[i], Mats.get_mat("metal_dark"), Vector3.ONE, 6, false)


func _sprinkler(pos: Vector3, audio := false) -> void:
	var s := Sprinkler.new()
	s.with_audio = audio
	s.position = pos
	add_child(s)


func _build_irrigation() -> void:
	var y_floor := 0.06
	var y_bed := 0.6
	# feed from the west wall (outdoor branch arrives at local (-8, 0.3, 3))
	_pipe([Vector3(-8.0, 0.3, 3.0), Vector3(-7.4, 0.3, 3.0), Vector3(-7.4, y_floor, 3.0), Vector3(-7.4, y_floor, -2.3), Vector3(-7.4, y_bed, -2.3), Vector3(6.6, y_bed, -2.3)])
	_pipe([Vector3(-7.4, y_floor, 1.5), Vector3(-7.4, y_bed, 1.5), Vector3(-1.6, y_bed, 1.5), Vector3(-1.6, y_floor, 1.5), Vector3(1.6, y_floor, 1.5), Vector3(1.6, y_bed, 1.5), Vector3(6.6, y_bed, 1.5)])
	ProcMesh.box(self, Vector3(3.4, 0.03, 0.3), Vector3(0, 0.03, 1.5), Mats.get_mat("metal_dark"), Vector3.ZERO, false)
	# risers + sprinkler heads
	var first := true
	for x: float in [-4.5, 0.0, 4.5]:
		_pipe([Vector3(x, y_bed, -2.3), Vector3(x, 1.45, -2.3)], 0.025)
		_sprinkler(Vector3(x, 1.45, -2.3), first)
		first = false
	for x: float in [-4.1, 4.1]:
		_pipe([Vector3(x, y_bed, 1.5), Vector3(x, 0.95, 1.5)], 0.025)
		_sprinkler(Vector3(x, 0.95, 1.5))


func _build_shelves() -> void:
	# two-tier potting shelf on the east gable wall
	var root := Node3D.new()
	root.position = Vector3(7.45, 0, -0.4)
	add_child(root)
	var f := Mats.get_mat("metal")
	for z: float in [-1.2, 1.2]:
		for x: float in [-0.25, 0.25]:
			ProcMesh.box(root, Vector3(0.04, 1.3, 0.04), Vector3(x, 0.65, z), f)
	for y: float in [0.55, 1.15]:
		ProcMesh.box(root, Vector3(0.6, 0.04, 2.5), Vector3(0, y, 0), Mats.get_mat("wood"))
		var z := -1.05
		while z < 1.1:
			ProcMesh.cyl(root, 0.09, 0.07, 0.16, Vector3(0, y + 0.1, z), Mats.get_mat("terracotta"), Vector3.ZERO, 10)
			ProcMesh.sphere(root, 0.1, Vector3(0, y + 0.22, z), Mats.get_mat("leaf"), Vector3(1, 0.8, 1), 7)
			z += 0.35
	ProcMesh.static_box(self, Vector3(0.7, 1.3, 2.6), root.position + Vector3(0, 0.65, 0))


func _build_sign() -> void:
	ProcMesh.box(self, Vector3(2.4, 0.42, 0.06), Vector3(0, 2.7, D * 0.5 + 0.08), Mats.get_mat("plastic_dark"))
	ProcMesh.label3d(self, "SMART GREENHOUSE", Vector3(0, 2.72, D * 0.5 + 0.12), 40, Color(0.75, 1.0, 0.85), false)
	ProcMesh.box(self, Vector3(2.0, 0.025, 0.01), Vector3(0, 2.56, D * 0.5 + 0.115), Mats.emissive(Color(0.25, 0.85, 0.45), 2.0), Vector3.ZERO, false)
