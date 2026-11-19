extends Node3D
## Builds the outdoor farm procedurally: terrain + hills, distant mountains,
## gravel paths, fence, water tank station, IoT control station, utility shed,
## crop field, irrigation pipe network, trees, grass, flowers, lamps and props.
##
## Layout (metres, -Z = north):
##   greenhouse  x[-8,8]  z[-19,-9]   (separate Greenhouse scene)
##   field       x[14,33] z[-24,6]
##   tank/pump   around (-16,-8) / (-13,-4.5)
##   control station (-9, 6.3), shed (-17, 11), spawn (0, 20)

const FENCE_MIN := Vector2(-38.0, -34.0)
const FENCE_MAX := Vector2(38.0, 32.0)
const TERRAIN_HALF := 120.0
const TERRAIN_CELLS := 96

const PIPE_R := 0.055

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _blocked: Array[Rect2] = []  ## xz rects where grass / flowers must not spawn
var _grass: MultiMeshInstance3D
var _grass_total := 0
var _details: Array[MultiMeshInstance3D] = []
var _detail_totals: Array[int] = []
var _lamp_lights: Array[OmniLight3D] = []
var _turbine_rotor: Node3D
var _night := 0.0


func _ready() -> void:
	_rng.seed = 2024
	_noise.seed = 11
	_noise.frequency = 0.018
	_noise.fractal_octaves = 4
	_blocked = [
		Rect2(-9.5, -20.5, 19, 13),        # greenhouse + plaza
		Rect2(13.5, -24.5, 20, 31),        # field
		Rect2(-19.5, -11.5, 7.5, 9),       # tank pad + pump
		Rect2(-11.5, 4.5, 5, 3.5),         # control station
		Rect2(-20.5, 8.0, 7, 6),           # shed
	]
	_build_terrain()
	_build_mountains()
	_build_paths()
	_build_fence()
	_build_water_station()
	_build_control_station()
	_build_shed()
	_build_field()
	_build_pipes()
	_build_trees()
	_build_props()
	_build_lamps()
	_build_sign()
	_build_wind_turbine()
	_build_grass()
	_build_flowers()
	GameSettings.quality_changed.connect(func(_p: String) -> void: _apply_quality())
	EnvironmentManager.time_changed.connect(_on_time)
	_apply_quality()
	_on_time(EnvironmentManager.time_of_day)


# --------------------------------------------------------------- terrain ---

func height_at(x: float, z: float) -> float:
	var dx := maxf(maxf(FENCE_MIN.x - 4.0 - x, x - FENCE_MAX.x - 4.0), 0.0)
	var dz := maxf(maxf(FENCE_MIN.y - 4.0 - z, z - FENCE_MAX.y - 4.0), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	if d <= 0.0:
		return 0.0
	var f := smoothstep(0.0, 30.0, d)
	return f * ((_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 18.0 + 3.0 + d * 0.05)


func _terrain_color(x: float, z: float, h: float) -> Color:
	var n := _noise.get_noise_2d(x * 3.0 + 100.0, z * 3.0) * 0.5 + 0.5
	var grass_a := Color(0.25, 0.36, 0.14)
	var grass_b := Color(0.35, 0.42, 0.17)
	var c := grass_a.lerp(grass_b, n)
	if x > 13.0 and x < 34.0 and z > -25.0 and z < 7.0:
		c = c.lerp(Color(0.36, 0.27, 0.17), 0.75)
	if h > 9.0:
		c = c.lerp(Color(0.42, 0.42, 0.36), clampf((h - 9.0) / 10.0, 0.0, 0.6))
	return c


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := TERRAIN_CELLS
	var step := TERRAIN_HALF * 2.0 / n
	var e := 0.5
	for iz in n + 1:
		for ix in n + 1:
			var x := -TERRAIN_HALF + ix * step
			var z := -TERRAIN_HALF + iz * step
			var h := height_at(x, z)
			var nrm := Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()
			st.set_color(_terrain_color(x, z, h))
			st.set_normal(nrm)
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, h, z))
	for iz in n:
		for ix in n:
			var i0 := iz * (n + 1) + ix
			var i1 := i0 + 1
			var i2 := i0 + (n + 1)
			var i3 := i2 + 1
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i1)
			st.add_index(i3)
			st.add_index(i2)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat("terrain")
	add_child(mi)
	# Walkable area is flat: one infinite plane is the cheapest possible collider.
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


func _build_mountains() -> void:
	var mat_a := Mats.std(Color(0.22, 0.30, 0.22), 0.95)
	var mat_b := Mats.std(Color(0.30, 0.34, 0.30), 0.95)
	var parts_a: Array = []
	var parts_b: Array = []
	for i in 22:
		var ang := TAU * i / 22.0 + _rng.randf_range(-0.1, 0.1)
		var dist := _rng.randf_range(150.0, 200.0)
		var hgt := _rng.randf_range(25.0, 65.0)
		var rad := _rng.randf_range(35.0, 55.0)
		var m := ProcMesh.cyl_mesh(rad * 0.08, rad, hgt, 7)
		var t := ProcMesh.xf(Vector3(cos(ang) * dist, hgt * 0.5 - 4.0, sin(ang) * dist), Vector3(0, _rng.randf_range(0, 360), 0))
		if i % 2 == 0:
			parts_a.append([m, t, mat_a])
		else:
			parts_b.append([m, t, mat_b])
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = ProcMesh.merge(parts_a + parts_b)
	mi.cast_shadow = ProcMesh.NO_SHADOW
	add_child(mi)


# ----------------------------------------------------------------- paths ---

func _path(x0: float, z0: float, x1: float, z1: float) -> void:
	var size := Vector3(x1 - x0, 0.04, z1 - z0)
	var c := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	ProcMesh.box(self, size, c, Mats.get_mat("gravel"), Vector3.ZERO, false)
	# timber edging along the long sides
	var edge := Mats.get_mat("wood_dark")
	if size.x > size.z:
		ProcMesh.box(self, Vector3(size.x, 0.08, 0.08), c + Vector3(0, 0.02, -size.z * 0.5), edge, Vector3.ZERO, false)
		ProcMesh.box(self, Vector3(size.x, 0.08, 0.08), c + Vector3(0, 0.02, size.z * 0.5), edge, Vector3.ZERO, false)
	else:
		ProcMesh.box(self, Vector3(0.08, 0.08, size.z), c + Vector3(-size.x * 0.5, 0.02, 0), edge, Vector3.ZERO, false)
		ProcMesh.box(self, Vector3(0.08, 0.08, size.z), c + Vector3(size.x * 0.5, 0.02, 0), edge, Vector3.ZERO, false)
	_blocked.append(Rect2(x0 - 0.3, z0 - 0.3, x1 - x0 + 0.6, z1 - z0 + 0.6))


func _build_paths() -> void:
	_path(-1.2, -6.5, 1.2, 31.0)      # main north-south path
	_path(-3.5, -9.2, 3.5, -6.5)      # greenhouse plaza
	_path(-14.0, 3.0, -1.2, 5.0)      # west branch to control station / shed
	_path(-12.6, -3.2, -10.6, 3.0)    # spur to the pump
	_path(1.2, -3.0, 13.5, -1.0)      # east branch to the field


# ----------------------------------------------------------------- fence ---

func _build_fence() -> void:
	var wood := Mats.get_mat("wood")
	var post_mesh := ProcMesh.box_mesh(Vector3(0.14, 1.3, 0.14))
	post_mesh.material = wood
	var posts: Array = []
	var corners := [Vector2(FENCE_MIN.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MIN.y), Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2(FENCE_MIN.x, FENCE_MAX.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length := a.distance_to(b)
		var count := int(length / 3.0)
		for k in count:
			var p := a.lerp(b, float(k) / count)
			if i == 2 and absf(p.x) < 2.2:
				continue  # gate opening
			posts.append(Transform3D(Basis.IDENTITY, Vector3(p.x, 0.65, p.y)))
		# rails
		for y: float in [0.55, 1.05]:
			if i == 2:
				_rail(Vector2(FENCE_MAX.x, FENCE_MAX.y), Vector2(2.2, FENCE_MAX.y), y)
				_rail(Vector2(-2.2, FENCE_MAX.y), Vector2(FENCE_MIN.x, FENCE_MAX.y), y)
			else:
				_rail(a, b, y)
		# collision
		var mid := (a + b) * 0.5
		var horizontal := absf(a.y - b.y) < 0.01
		ProcMesh.static_box(self, Vector3(length if horizontal else 0.3, 3.0, 0.3 if horizontal else length), Vector3(mid.x, 1.5, mid.y))
	ProcMesh.multimesh(self, post_mesh, posts)
	# closed double gate
	for side: float in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(side * 2.2, 0, FENCE_MAX.y)
		add_child(g)
		ProcMesh.box(g, Vector3(0.18, 1.6, 0.18), Vector3(0, 0.8, 0), Mats.get_mat("wood_dark"))
		for y: float in [0.4, 0.8, 1.2]:
			ProcMesh.box(g, Vector3(2.1, 0.12, 0.06), Vector3(-side * 1.1, y, 0), wood)
		ProcMesh.box(g, Vector3(2.4, 0.1, 0.05), Vector3(-side * 1.1, 0.8, 0.03), wood, Vector3(0, 0, side * 19.0))


func _rail(a: Vector2, b: Vector2, y: float) -> void:
	var d := b - a
	var rail_len := d.length()
	var mid := (a + b) * 0.5
	var horizontal := absf(d.y) < 0.01
	ProcMesh.box(self, Vector3(rail_len if horizontal else 0.06, 0.1, 0.06 if horizontal else rail_len), Vector3(mid.x, y, mid.y), Mats.get_mat("wood"))


# --------------------------------------------------------- water station ---

func _build_water_station() -> void:
	var root := Node3D.new()
	root.name = "WaterStation"
	add_child(root)
	var c := Vector3(-16, 0, -8)
	ProcMesh.box(root, Vector3(6.5, 0.1, 6.5), Vector3(-15.75, 0.05, -7.25), Mats.get_mat("concrete"))
	ProcMesh.cyl(root, 2.35, 2.45, 0.4, c + Vector3(0, 0.3, 0), Mats.get_mat("concrete"), Vector3.ZERO, 32)
	ProcMesh.cyl(root, 2.2, 2.2, 3.4, c + Vector3(0, 2.2, 0), Mats.get_mat("tank"), Vector3.ZERO, 40)
	ProcMesh.cyl(root, 0.35, 2.2, 0.55, c + Vector3(0, 4.17, 0), Mats.get_mat("tank"), Vector3.ZERO, 40)
	ProcMesh.cyl(root, 0.38, 0.38, 0.12, c + Vector3(0, 4.5, 0), Mats.get_mat("metal_dark"), Vector3.ZERO, 16)
	for y: float in [1.0, 2.2, 3.4]:
		ProcMesh.torus(root, 2.19, 2.27, c + Vector3(0, y, 0), Mats.get_mat("metal"))
	# ladder on the east side
	var lx := c.x + 2.32
	for zz: float in [-0.25, 0.25]:
		ProcMesh.box(root, Vector3(0.05, 4.2, 0.05), Vector3(lx, 2.2, c.z + zz), Mats.get_mat("metal"))
	for i in 12:
		ProcMesh.box(root, Vector3(0.04, 0.04, 0.5), Vector3(lx, 0.5 + i * 0.32, c.z), Mats.get_mat("metal"))
	# level gauge
	ProcMesh.box(root, Vector3(0.05, 2.6, 0.12), Vector3(c.x + 1.55, 2.1, c.z + 1.55), Mats.get_mat("plastic_white"), Vector3(0, -45, 0))
	ProcMesh.box(root, Vector3(0.06, 1.8, 0.06), Vector3(c.x + 1.57, 1.7, c.z + 1.57), Mats.emissive(Color(0.2, 0.6, 1.0), 1.5), Vector3(0, -45, 0), false)
	var lbl := ProcMesh.label3d(root, "WATER TANK\n10 000 L", c + Vector3(1.6, 3.0, 1.6), 64, Color(1, 1, 1), false)
	lbl.rotation_degrees = Vector3(0, 45, 0)
	ProcMesh.static_cyl(root, 2.4, 5.0, c + Vector3(0, 2.5, 0))
	# pump pad + roof shelter
	ProcMesh.box(root, Vector3(2.6, 0.12, 2.0), Vector3(-13.2, 0.06, -4.5), Mats.get_mat("concrete"))
	_blocked.append(Rect2(-14.6, -5.6, 3.0, 4.0))


# ------------------------------------------------------- control station ---

func _build_control_station() -> void:
	var root := Node3D.new()
	root.name = "ControlStation"
	root.position = Vector3(-9, 0, 6.3)
	add_child(root)
	ProcMesh.box(root, Vector3(4.6, 0.1, 3.4), Vector3(0, 0.05, 0.2), Mats.get_mat("concrete"))
	# pergola
	for p: Vector2 in [Vector2(-2.0, -1.2), Vector2(2.0, -1.2), Vector2(-2.0, 1.6), Vector2(2.0, 1.6)]:
		ProcMesh.box(root, Vector3(0.14, 2.7, 0.14), Vector3(p.x, 1.35, p.y), Mats.get_mat("wood_painted"))
	ProcMesh.box(root, Vector3(4.6, 0.12, 3.4), Vector3(0, 2.75, 0.2), Mats.get_mat("roof"), Vector3(4, 0, 0))
	ProcMesh.static_box(root, Vector3(4.6, 0.3, 3.4), Vector3(0, 2.8, 0.2))
	for x: float in [-2.0, 2.0]:
		ProcMesh.box(root, Vector3(0.12, 0.18, 3.2), Vector3(x, 2.62, 0.2), Mats.get_mat("wood_painted"))
	# console cabinet + desk
	ProcMesh.box(root, Vector3(2.0, 0.95, 0.7), Vector3(0, 0.5, 0.25), Mats.get_mat("plastic_white"))
	ProcMesh.box(root, Vector3(2.1, 0.06, 0.8), Vector3(0, 1.0, 0.25), Mats.get_mat("metal_dark"))
	ProcMesh.box(root, Vector3(1.9, 0.12, 0.02), Vector3(0, 0.75, -0.105), Mats.emissive(Color(0.12, 0.62, 1.0), 2.0), Vector3.ZERO, false)
	# twin monitors facing north (towards the path)
	for x: float in [-0.5, 0.5]:
		ProcMesh.box(root, Vector3(0.06, 0.4, 0.06), Vector3(x, 1.2, 0.5), Mats.get_mat("metal_dark"))
		var mon := Node3D.new()
		mon.position = Vector3(x, 1.55, 0.5)
		mon.rotation_degrees = Vector3(-10, 180, 0)
		root.add_child(mon)
		ProcMesh.box(mon, Vector3(0.9, 0.56, 0.05), Vector3(0, 0, 0.03), Mats.get_mat("plastic_dark"))
		var q := QuadMesh.new()
		q.size = Vector2(0.84, 0.5)
		var scr := MeshInstance3D.new()
		scr.mesh = q
		scr.material_override = Mats.get_mat("screen")
		scr.position = Vector3(0, 0, 0.0)
		scr.rotation_degrees = Vector3(0, 180, 0)
		scr.cast_shadow = ProcMesh.NO_SHADOW
		mon.add_child(scr)
	ProcMesh.static_box(root, Vector3(2.1, 1.6, 0.8), Vector3(0, 0.8, 0.25))
	var sign := ProcMesh.label3d(root, "IoT CONTROL STATION", Vector3(0, 2.45, -1.27), 54, Color(0.85, 0.95, 1.0), false)
	sign.rotation_degrees = Vector3(0, 180, 0)
	ProcMesh.box(root, Vector3(2.4, 0.3, 0.05), Vector3(0, 2.45, -1.24), Mats.get_mat("plastic_dark"))


# ------------------------------------------------------------------ shed ---

func _build_shed() -> void:
	var root := Node3D.new()
	root.name = "UtilityShed"
	root.position = Vector3(-17, 0, 11)
	add_child(root)
	var w := 6.0
	var d := 5.0
	var h := 2.8
	ProcMesh.box(root, Vector3(w + 0.4, 0.15, d + 0.4), Vector3(0, 0.075, 0), Mats.get_mat("concrete"))
	ProcMesh.box(root, Vector3(w, h, d), Vector3(0, h * 0.5 + 0.15, 0), Mats.get_mat("siding"))
	for cx: float in [-w * 0.5, w * 0.5]:
		for cz: float in [-d * 0.5, d * 0.5]:
			ProcMesh.box(root, Vector3(0.16, h, 0.16), Vector3(cx, h * 0.5 + 0.15, cz), Mats.get_mat("wood_painted"))
	# gable roof along x
	var slope := 22.0
	var half := d * 0.5 + 0.5
	var rl := half / cos(deg_to_rad(slope))
	for s: float in [-1.0, 1.0]:
		ProcMesh.box(root, Vector3(w + 0.8, 0.12, rl), Vector3(0, h + 0.15 + half * tan(deg_to_rad(slope)) * 0.5 + 0.05, s * half * 0.5), Mats.get_mat("roof"), Vector3(s * slope, 0, 0))
	# gable triangles
	var peak := h + 0.15 + (d * 0.5) * tan(deg_to_rad(slope))
	for sx: float in [-1.0, 1.0]:
		var x := sx * w * 0.5
		ProcMesh.triangle(root, Vector3(x, h + 0.15, -d * 0.5), Vector3(x, peak, 0), Vector3(x, h + 0.15, d * 0.5), Mats.get_mat("siding"))
		ProcMesh.triangle(root, Vector3(x, h + 0.15, d * 0.5), Vector3(x, peak, 0), Vector3(x, h + 0.15, -d * 0.5), Mats.get_mat("siding"))
	# window on the north face (the door leaf belongs to the SmartLock device)
	for x: float in [-1.4]:
		ProcMesh.box(root, Vector3(1.4, 1.0, 0.1), Vector3(x, 1.7, -d * 0.5 - 0.02), Mats.get_mat("wood_painted"))
		ProcMesh.box(root, Vector3(1.25, 0.85, 0.12), Vector3(x, 1.7, -d * 0.5 - 0.02), Mats.get_mat("window"))
	# solar panels on the north roof face
	for i in 3:
		var px := -1.9 + i * 1.9
		ProcMesh.box(root, Vector3(1.7, 0.06, 1.9), Vector3(px, h + 0.15 + half * tan(deg_to_rad(slope)) * 0.5 + 0.22, -half * 0.5), Mats.get_mat("solar"), Vector3(-slope, 0, 0))
	# AC / inverter unit on the east wall
	ProcMesh.box(root, Vector3(0.4, 0.7, 0.9), Vector3(w * 0.5 + 0.2, 0.6, 0.8), Mats.get_mat("plastic_white"))
	ProcMesh.cyl(root, 0.28, 0.28, 0.02, Vector3(w * 0.5 + 0.41, 0.6, 0.8), Mats.get_mat("metal_dark"), Vector3(0, 0, 90), 16)
	ProcMesh.static_box(root, Vector3(w, 3.0, d), Vector3(0, 1.5, 0))


# ----------------------------------------------------------------- field ---

func _build_field() -> void:
	var root := Node3D.new()
	root.name = "CropField"
	add_child(root)
	var soil := Mats.get_mat("soil")
	var corn_parts: Array = []
	var leaf := Mats.get_mat("corn")
	var stem := Mats.get_mat("stem")
	corn_parts.append([ProcMesh.cyl_mesh(0.02, 0.03, 1.7, 5), ProcMesh.xf(Vector3(0, 0.85, 0)), stem])
	for i in 6:
		var a := i * 137.0
		var y := 0.35 + i * 0.22
		corn_parts.append([ProcMesh.box_mesh(Vector3(0.05, 0.6, 0.012)), ProcMesh.xf(Vector3(0, y, 0), Vector3(0, a, 0)) * ProcMesh.xf(Vector3(0, 0.22, 0.14), Vector3(55, 0, 0)), leaf])
	corn_parts.append([ProcMesh.cyl_mesh(0.035, 0.035, 0.22, 6), ProcMesh.xf(Vector3(0.05, 1.05, 0.0), Vector3(0, 0, -20)), Mats.get_mat("corn_cob")])
	var corn_mesh := ProcMesh.merge(corn_parts)
	var cabbage_parts: Array = []
	var lettuce := Mats.get_mat("lettuce")
	var leaf_dark := Mats.get_mat("leaf_dark")
	cabbage_parts.append([ProcMesh.sphere_mesh(0.16, 10), ProcMesh.xf(Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1, 0.85, 1)), lettuce])
	for i in 6:
		cabbage_parts.append([ProcMesh.sphere_mesh(0.14, 8), ProcMesh.xf(Vector3(0, 0.1, 0), Vector3(0, i * 60.0, 0)) * ProcMesh.xf(Vector3(0, 0, 0.14), Vector3(-35, 0, 0), Vector3(1, 0.35, 1.3)), leaf_dark])
	var cabbage_mesh := ProcMesh.merge(cabbage_parts)
	var corn_t: Array = []
	var cab_t: Array = []
	for r in 8:
		var x := 15.5 + r * 2.4
		for seg in [[-23.5, -8.0], [-5.0, 5.5]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			ProcMesh.box(root, Vector3(1.1, 0.25, z1 - z0), Vector3(x, 0.08, (z0 + z1) * 0.5), soil, Vector3.ZERO, false)
			var z := z0 + 0.4
			while z < z1 - 0.3:
				var jitter := Vector3(_rng.randf_range(-0.12, 0.12), 0.2, _rng.randf_range(-0.1, 0.1))
				var s := _rng.randf_range(0.8, 1.15)
				var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, 0, z) + jitter)
				if r % 2 == 0:
					corn_t.append(t)
					z += 0.55
				else:
					cab_t.append(t)
					z += 0.6
	_details.append(ProcMesh.multimesh(root, corn_mesh, corn_t))
	_details.append(ProcMesh.multimesh(root, cabbage_mesh, cab_t))
	_detail_totals.append(corn_t.size())
	_detail_totals.append(cab_t.size())
	# hay bales and a tool rack at the field edge
	for p: Vector3 in [Vector3(34.5, 0.6, 3), Vector3(34.5, 0.6, 4.6), Vector3(34.5, 1.65, 3.8)]:
		ProcMesh.cyl(root, 0.6, 0.6, 1.2, p, Mats.std(Color(0.85, 0.72, 0.38), 0.95), Vector3(0, 0, 90), 16)
	ProcMesh.static_box(root, Vector3(1.4, 2.2, 3.0), Vector3(34.5, 1.1, 3.8))


# ----------------------------------------------------------------- pipes ---

func _pipe(points: Array) -> void:
	var mat := Mats.get_mat("pipe")
	var joint := Mats.get_mat("metal_dark")
	for i in points.size() - 1:
		ProcMesh.cyl_between(self, points[i], points[i + 1], PIPE_R, mat, 10)
	for i in range(1, points.size() - 1):
		ProcMesh.sphere(self, PIPE_R * 1.35, points[i], joint, Vector3.ONE, 8)


func _support(p: Vector3) -> void:
	ProcMesh.box(self, Vector3(0.25, p.y, 0.3), Vector3(p.x, p.y * 0.5, p.z), Mats.get_mat("concrete"), Vector3.ZERO, false)


func _build_pipes() -> void:
	# suction: tank -> pump (pump is rotated 180°, inlet faces west)
	_pipe([Vector3(-15.0, 0.33, -6.0), Vector3(-15.0, 0.33, -4.5), Vector3(-13.75, 0.33, -4.5)])
	# discharge riser -> main line
	var y := 0.3
	_pipe([Vector3(-13.22, 0.98, -4.5), Vector3(-13.22, 0.98, -6.5), Vector3(-13.22, y, -6.5), Vector3(-9.6, y, -6.5)])
	ProcMesh.torus(self, 0.08, 0.12, Vector3(-13.22, 0.98, -5.4), Mats.get_mat("red"), Vector3(90, 0, 0))
	# branch into the greenhouse west wall
	_pipe([Vector3(-9.6, y, -6.5), Vector3(-9.6, y, -11.0), Vector3(-8.0, y, -11.0)])
	# main line east with an overhead bridge across the plaza
	_pipe([Vector3(-9.6, y, -6.5), Vector3(-4.0, y, -6.5), Vector3(-4.0, 3.3, -6.5), Vector3(4.0, 3.3, -6.5), Vector3(4.0, y, -6.5), Vector3(31.0, y, -6.5)])
	for x: float in [-4.0, 4.0]:
		ProcMesh.box(self, Vector3(0.12, 3.2, 0.12), Vector3(x, 1.6, -6.75), Mats.get_mat("metal"))
	var x := -12.0
	while x < 31.0:
		if absf(x) > 4.5:
			_support(Vector3(x, y - PIPE_R, -6.5))
		x += 3.0
	# field risers + rotating sprinklers
	for sx: float in [18.0, 24.0, 30.0]:
		_pipe([Vector3(sx, y, -6.5), Vector3(sx, 1.25, -6.5)])
		var s := Sprinkler.new()
		s.rotating = true
		s.with_audio = sx == 24.0
		s.position = Vector3(sx, 1.25, -6.5)
		add_child(s)


# ----------------------------------------------------------------- trees ---

func _tree_mesh(conifer: bool) -> ArrayMesh:
	var parts: Array = []
	var bark := Mats.get_mat("bark")
	if conifer:
		parts.append([ProcMesh.cyl_mesh(0.12, 0.2, 2.0, 7), ProcMesh.xf(Vector3(0, 1.0, 0)), bark])
		for i in 3:
			parts.append([ProcMesh.cyl_mesh(0.05, 1.6 - i * 0.4, 2.2, 8), ProcMesh.xf(Vector3(0, 2.2 + i * 1.2, 0)), Mats.get_mat("foliage")])
	else:
		parts.append([ProcMesh.cyl_mesh(0.14, 0.24, 2.6, 7), ProcMesh.xf(Vector3(0, 1.3, 0)), bark])
		parts.append([ProcMesh.cyl_mesh(0.05, 0.1, 1.2, 5), ProcMesh.xf(Vector3(0.35, 2.6, 0), Vector3(0, 0, -35)), bark])
		parts.append([ProcMesh.sphere_mesh(1.5, 9), ProcMesh.xf(Vector3(0, 3.6, 0), Vector3.ZERO, Vector3(1, 0.85, 1)), Mats.get_mat("foliage_light")])
		parts.append([ProcMesh.sphere_mesh(1.1, 8), ProcMesh.xf(Vector3(0.9, 3.1, 0.3)), Mats.get_mat("foliage")])
		parts.append([ProcMesh.sphere_mesh(1.0, 8), ProcMesh.xf(Vector3(-0.8, 3.3, -0.4)), Mats.get_mat("foliage")])
		parts.append([ProcMesh.sphere_mesh(0.9, 8), ProcMesh.xf(Vector3(0.1, 4.4, 0.5)), Mats.get_mat("foliage_light")])
	return ProcMesh.merge(parts)


func _build_trees() -> void:
	var round_t: Array = []
	var con_t: Array = []
	# outside the fence
	var placed := 0
	var guard := 0
	while placed < 70 and guard < 800:
		guard += 1
		var x := _rng.randf_range(-75.0, 75.0)
		var z := _rng.randf_range(-70.0, 70.0)
		if x > FENCE_MIN.x - 5 and x < FENCE_MAX.x + 5 and z > FENCE_MIN.y - 5 and z < FENCE_MAX.y + 5:
			continue
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.9, 1.6)), Vector3(x, height_at(x, z) - 0.1, z))
		if _rng.randf() < 0.45:
			con_t.append(t)
		else:
			round_t.append(t)
		placed += 1
	# a few shade trees inside the farm (with collision)
	for p: Vector3 in [Vector3(-30, 0, 24), Vector3(-32, 0, -22), Vector3(-26, 0, -28), Vector3(10, 0, 26), Vector3(24, 0, 22), Vector3(-30, 0, 0), Vector3(30, 0, 14), Vector3(-6, 0, 26)]:
		var t2 := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.0, 1.3)), p)
		round_t.append(t2)
		ProcMesh.static_cyl(self, 0.35, 3.0, p + Vector3(0, 1.5, 0))
		_blocked.append(Rect2(p.x - 1.0, p.z - 1.0, 2.0, 2.0))
	ProcMesh.multimesh(self, _tree_mesh(false), round_t)
	ProcMesh.multimesh(self, _tree_mesh(true), con_t)


# ----------------------------------------------------------------- props ---

func _build_props() -> void:
	var wood := Mats.get_mat("wood")
	# crates near the shed
	for p: Vector3 in [Vector3(-13.3, 0.35, 9.4), Vector3(-13.3, 0.35, 10.2), Vector3(-13.3, 1.05, 9.8)]:
		ProcMesh.box(self, Vector3(0.7, 0.7, 0.7), p, wood, Vector3(0, _rng.randf_range(-12, 12), 0))
	ProcMesh.static_box(self, Vector3(0.8, 1.4, 1.6), Vector3(-13.3, 0.7, 9.8))
	# barrels by the pump
	for p: Vector3 in [Vector3(-11.4, 0.45, -8.3), Vector3(-10.7, 0.45, -8.7)]:
		ProcMesh.cyl(self, 0.3, 0.3, 0.9, p, Mats.get_mat("plastic_blue"), Vector3.ZERO, 16)
		ProcMesh.torus(self, 0.29, 0.32, p + Vector3(0, 0.25, 0), Mats.get_mat("metal_dark"))
	ProcMesh.static_box(self, Vector3(1.4, 1.0, 1.0), Vector3(-11.05, 0.5, -8.5))
	# bench beside the main path
	var bench := Node3D.new()
	bench.position = Vector3(-2.3, 0, 10)
	bench.rotation_degrees = Vector3(0, 90, 0)
	add_child(bench)
	ProcMesh.box(bench, Vector3(1.8, 0.06, 0.45), Vector3(0, 0.45, 0), wood)
	ProcMesh.box(bench, Vector3(1.8, 0.4, 0.05), Vector3(0, 0.75, -0.22), wood, Vector3(-10, 0, 0))
	for x: float in [-0.75, 0.75]:
		ProcMesh.box(bench, Vector3(0.08, 0.45, 0.4), Vector3(x, 0.22, 0), Mats.get_mat("metal_dark"))
	ProcMesh.static_box(self, Vector3(0.6, 1.0, 1.9), Vector3(-2.3, 0.5, 10))
	# rocks
	var rock := Mats.get_mat("rock")
	for i in 14:
		var ang := _rng.randf() * TAU
		var p := Vector3(cos(ang) * _rng.randf_range(20, 34), 0.0, sin(ang) * _rng.randf_range(20, 30))
		if _is_blocked(p.x, p.z):
			continue
		var s := _rng.randf_range(0.3, 0.8)
		ProcMesh.sphere(self, s, p + Vector3(0, s * 0.3, 0), rock, Vector3(1.2, 0.65, 1.0), 7)
	# planters with shrubs around the greenhouse plaza
	for x: float in [-5.0, 5.0]:
		ProcMesh.box(self, Vector3(1.2, 0.5, 1.2), Vector3(x, 0.25, -7.6), Mats.get_mat("concrete"))
		ProcMesh.sphere(self, 0.6, Vector3(x, 0.8, -7.6), Mats.get_mat("foliage"), Vector3(1, 0.9, 1), 10)
		ProcMesh.static_box(self, Vector3(1.2, 1.0, 1.2), Vector3(x, 0.5, -7.6))


func _is_blocked(x: float, z: float) -> bool:
	for r in _blocked:
		if r.has_point(Vector2(x, z)):
			return true
	return false


# ----------------------------------------------------------------- lamps ---

func _build_lamps() -> void:
	var glow := Mats.get_mat("lamp_glow")
	var spots := [Vector3(1.8, 0, 24), Vector3(-1.8, 0, 14), Vector3(1.8, 0, 4), Vector3(-6, 0, 2.4), Vector3(8, 0, -3.6), Vector3(-3.8, 0, -9.6)]
	for p in spots:
		ProcMesh.cyl(self, 0.05, 0.07, 3.2, p + Vector3(0, 1.6, 0), Mats.get_mat("metal_dark"), Vector3.ZERO, 8)
		ProcMesh.cyl(self, 0.16, 0.16, 0.08, p + Vector3(0, 0.04, 0), Mats.get_mat("concrete"), Vector3.ZERO, 10)
		ProcMesh.cyl(self, 0.05, 0.22, 0.18, p + Vector3(0, 3.25, 0), Mats.get_mat("metal_dark"), Vector3.ZERO, 12)
		ProcMesh.sphere(self, 0.11, p + Vector3(0, 3.13, 0), glow, Vector3(1, 0.6, 1), 10, false)
		ProcMesh.static_cyl(self, 0.12, 3.2, p + Vector3(0, 1.6, 0))
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 2.9, 0)
		l.light_color = Color(1.0, 0.8, 0.55)
		l.omni_range = 9.0
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lamp_lights.append(l)


# ------------------------------------------------------------------ sign ---

func _build_sign() -> void:
	var root := Node3D.new()
	root.position = Vector3(3.6, 0, 15.5)
	root.rotation_degrees = Vector3(0, -28, 0)
	add_child(root)
	for x: float in [-1.4, 1.4]:
		ProcMesh.box(root, Vector3(0.16, 2.4, 0.16), Vector3(x, 1.2, 0), Mats.get_mat("wood_dark"))
	ProcMesh.box(root, Vector3(3.3, 1.1, 0.1), Vector3(0, 1.75, 0), Mats.get_mat("wood"))
	ProcMesh.box(root, Vector3(3.1, 0.9, 0.02), Vector3(0, 1.75, 0.06), Mats.get_mat("plastic_dark"))
	ProcMesh.label3d(root, "GREEN VALLEY SMART FARM", Vector3(0, 1.95, 0.08), 64, Color(0.75, 1.0, 0.8), false)
	ProcMesh.label3d(root, "Virtual IoT demonstration farm  -  all devices simulated", Vector3(0, 1.62, 0.08), 26, Color(0.8, 0.9, 1.0), false)
	ProcMesh.box(root, Vector3(2.6, 0.04, 0.01), Vector3(0, 1.78, 0.075), Mats.emissive(Color(0.12, 0.62, 1.0), 1.5), Vector3.ZERO, false)
	ProcMesh.static_box(self, Vector3(3.4, 2.4, 0.4), root.position + Vector3(0, 1.2, 0), root.rotation_degrees)


# --------------------------------------------------------- wind turbine ---

func _build_wind_turbine() -> void:
	var root := Node3D.new()
	root.position = Vector3(-27, 0, 16)
	root.rotation_degrees = Vector3(0, 35, 0)
	add_child(root)
	ProcMesh.cyl(root, 0.12, 0.3, 9.0, Vector3(0, 4.5, 0), Mats.get_mat("plastic_white"), Vector3.ZERO, 12)
	ProcMesh.box(root, Vector3(0.35, 0.35, 0.9), Vector3(0, 9.1, -0.1), Mats.get_mat("plastic_white"))
	_turbine_rotor = Node3D.new()
	_turbine_rotor.position = Vector3(0, 9.1, 0.4)
	root.add_child(_turbine_rotor)
	ProcMesh.sphere(_turbine_rotor, 0.18, Vector3.ZERO, Mats.get_mat("plastic_white"), Vector3(1, 1, 1.4), 10)
	for i in 3:
		var p := Node3D.new()
		p.rotation.z = i * TAU / 3.0
		_turbine_rotor.add_child(p)
		ProcMesh.box(p, Vector3(0.22, 2.6, 0.04), Vector3(0, 1.4, 0), Mats.get_mat("plastic_white"), Vector3(0, 12, 0))
	ProcMesh.static_cyl(self, 0.35, 9.0, root.position + Vector3(0, 4.5, 0))


func _process(delta: float) -> void:
	if _turbine_rotor:
		_turbine_rotor.rotate_z(delta * 1.2)


# ----------------------------------------------------- grass and flowers ---

func _grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var ang := _rng.randf() * TAU
		var off := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
		var h := _rng.randf_range(0.16, 0.32)
		var w := 0.045
		var side := Vector3(cos(ang), 0, sin(ang)) * w
		var lean := Vector3(sin(ang), 0, -cos(ang)) * _rng.randf_range(0.05, 0.14)
		var tip := off + Vector3(0, h, 0) + lean
		for v in [[off - side, 0.0], [off + side, 0.0], [tip, 1.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	var m := st.commit()
	m.surface_set_material(0, Mats.get_mat("grass"))
	return m


func _build_grass() -> void:
	var clump := _grass_clump()
	var ts: Array = []
	var target := 14000
	var guard := 0
	while ts.size() < target and guard < target * 3:
		guard += 1
		var x := _rng.randf_range(FENCE_MIN.x - 6.0, FENCE_MAX.x + 6.0)
		var z := _rng.randf_range(FENCE_MIN.y - 6.0, FENCE_MAX.y + 6.0)
		if _is_blocked(x, z):
			continue
		var s := _rng.randf_range(0.7, 1.4)
		ts.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), Vector3(x, height_at(x, z), z)))
	_grass = ProcMesh.multimesh(self, clump, ts, false)
	_grass.name = "Grass"
	_grass_total = ts.size()


func _build_flowers() -> void:
	var cols := ["flower_yellow", "flower_purple", "flower_white"]
	for ci in 3:
		var parts: Array = []
		parts.append([ProcMesh.cyl_mesh(0.008, 0.01, 0.3, 4), ProcMesh.xf(Vector3(0, 0.15, 0)), Mats.get_mat("stem")])
		parts.append([ProcMesh.sphere_mesh(0.045, 6), ProcMesh.xf(Vector3(0, 0.31, 0), Vector3.ZERO, Vector3(1, 0.5, 1)), Mats.get_mat(cols[ci])])
		parts.append([ProcMesh.box_mesh(Vector3(0.08, 0.01, 0.03)), ProcMesh.xf(Vector3(0, 0.12, 0.03), Vector3(0, 30, 20)), Mats.get_mat("leaf")])
		var mesh := ProcMesh.merge(parts)
		var ts: Array = []
		var guard := 0
		while ts.size() < 260 and guard < 3000:
			guard += 1
			# flowers cluster along path edges and near buildings
			var base: Vector2 = [Vector2(_rng.randf_range(-1.8, 1.8), _rng.randf_range(-6, 30)), Vector2(_rng.randf_range(-14, -1), _rng.randf_range(2.2, 5.8)), Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-9.8, -9.2)), Vector2(_rng.randf_range(2, 13), _rng.randf_range(-3.8, -0.2))].pick_random()
			if _is_blocked(base.x, base.y):
				continue
			var s := _rng.randf_range(0.8, 1.3)
			ts.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(base.x, 0, base.y)))
		var mmi := ProcMesh.multimesh(self, mesh, ts, false)
		_details.append(mmi)
		_detail_totals.append(ts.size())


# --------------------------------------------------------------- quality ---

func _apply_quality() -> void:
	if _grass:
		_grass.multimesh.visible_instance_count = int(_grass_total * float(GameSettings.q("grass_density")))
	var dd: float = GameSettings.q("detail_density")
	for i in _details.size():
		_details[i].multimesh.visible_instance_count = int(_detail_totals[i] * dd)
	_on_time(EnvironmentManager.time_of_day)


func _on_time(_h: float) -> void:
	var sun := EnvironmentManager.get_sun_height()
	var night := 1.0 - smoothstep(-0.05, 0.12, sun)
	if absf(night - _night) < 0.01 and night != 0.0 and night != 1.0:
		return
	_night = night
	var glow := Mats.get_mat("lamp_glow") as StandardMaterial3D
	glow.emission_energy_multiplier = night * 5.0
	var use_lights: bool = GameSettings.q("lamp_lights")
	for l in _lamp_lights:
		l.visible = use_lights and night > 0.05
		l.light_energy = night * 1.6
