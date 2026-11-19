class_name ProcMesh
extends RefCounted
## Procedural modelling helpers. All environment and device models are built
## from these primitives so the project has no external asset dependencies.

const NO_SHADOW := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _inst(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3, shadow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = NO_SHADOW
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _inst(parent, m, pos, mat, rot_deg, shadow)


static func cyl(parent: Node, r_top: float, r_bottom: float, height: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, segments := 16, shadow := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return _inst(parent, m, pos, mat, rot_deg, shadow)


static func sphere(parent: Node, radius: float, pos: Vector3, mat: Material, scale := Vector3.ONE, segments := 16, shadow := true) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	var mi := _inst(parent, m, pos, mat, Vector3.ZERO, shadow)
	mi.scale = scale
	return mi


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 8
	return _inst(parent, m, pos, mat, rot_deg, shadow)


## Cylinder whose local +Y axis runs from `a` to `b` (used for pipes, rails, poles).
static func cyl_between(parent: Node, a: Vector3, b: Vector3, radius: float, mat: Material, segments := 10, shadow := true) -> MeshInstance3D:
	var d := b - a
	var length := d.length()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = segments
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = NO_SHADOW
	var dir := d / length
	var basis := Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.9999:
		basis = Basis(Vector3.RIGHT, PI)
	elif dir.dot(Vector3.UP) < 0.9999:
		basis = Basis(Quaternion(Vector3.UP, dir))
	mi.transform = Transform3D(basis, (a + b) * 0.5)
	parent.add_child(mi)
	return mi


static func static_box(parent: Node, size: Vector3, pos: Vector3, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation_degrees = rot_deg
	parent.add_child(body)
	return body


static func static_cyl(parent: Node, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)
	return body


## Merge primitive parts into one ArrayMesh with one surface per material.
## parts: Array of [Mesh, Transform3D, Material]
static func merge(parts: Array) -> ArrayMesh:
	var groups: Dictionary = {}
	var order: Array = []
	for p in parts:
		var mat: Material = p[2]
		if not groups.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[mat] = st
			order.append(mat)
		var stool: SurfaceTool = groups[mat]
		var mesh: Mesh = p[0]
		for s in mesh.get_surface_count():
			stool.append_from(mesh, s, p[1])
	var out := ArrayMesh.new()
	for mat in order:
		var st2: SurfaceTool = groups[mat]
		st2.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


## Merge the static MeshInstance3D children of `owner` into one mesh per
## (material, shadow) pair to save draw calls. Nodes listed in `keep` (parts a
## script animates or resizes) and children of sub-nodes are left untouched.
## Materials are shared, so e.g. an LED whose material changes colour still
## updates after baking.
static func bake_static(owner: Node3D, keep: Array) -> int:
	var groups: Dictionary = {}  # [material, shadow] -> parts
	var baked: Array[MeshInstance3D] = []
	for c in owner.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi in keep or mi.material_override == null or mi.mesh == null or not mi.visible:
			continue
		if mi.get_child_count() > 0 or mi.visibility_range_end > 0.0:
			continue
		var key := [mi.material_override, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append([mi.mesh, mi.transform, mi.material_override])
		baked.append(mi)
	if baked.size() < 2:
		return 0
	var shadow_parts: Array = []
	var flat_parts: Array = []
	for key in groups:
		if key[1] == NO_SHADOW:
			flat_parts.append_array(groups[key])
		else:
			shadow_parts.append_array(groups[key])
	for parts: Array in [shadow_parts, flat_parts]:
		if parts.is_empty():
			continue
		var mi2 := MeshInstance3D.new()
		mi2.name = "Baked"
		mi2.mesh = merge(parts)
		if parts == flat_parts:
			mi2.cast_shadow = NO_SHADOW
		owner.add_child(mi2)
	for mi in baked:
		owner.remove_child(mi)
		mi.free()
	return baked.size()


static func box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere_mesh(radius: float, segs := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = maxi(segs / 2, 3)
	return m


static func cyl_mesh(r_top: float, r_bottom: float, h: float, segs := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func xf(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


## A MultiMeshInstance3D for many copies of `mesh`.
static func multimesh(parent: Node, mesh: Mesh, transforms: Array, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not shadow:
		mmi.cast_shadow = NO_SHADOW
	parent.add_child(mmi)
	return mmi


## Single flat triangle-prism used for greenhouse gable ends.
static func triangle(parent: Node, a: Vector3, b: Vector3, c: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.y))
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = NO_SHADOW
	parent.add_child(mi)
	return mi


## Label3D billboard helper.
static func label3d(parent: Node, text: String, pos: Vector3, size := 48, color := Color.WHITE, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.75)
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.cast_shadow = NO_SHADOW
	parent.add_child(l)
	return l
