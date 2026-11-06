class_name Carnelian
extends RefCounted
## Procedural rough carnelian pieces (polish pass).  A piece is a sphere displaced by two octaves of noise and
## chipped by a few random planes, so it reads as a subangular to subrounded nodule like the collected ones
## (paper section 4.3, Fig. 4a), neither a polished ball nor a cut stone.  The material (carnelian.gdshader) is a
## translucent, faintly banded orange-red with light leaking through the edges.  Presentation only (A-G19).

static var _shader: Shader


## `sparkle`: glints and a breathing glow (round 9: on every piece, close-ups included).
static func material(seed: int = 0, size: float = 1.0, sparkle := 1.0) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/carnelian.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("seed", float(seed % 97) * 0.37)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("sparkle", sparkle)
	return m


## A rough piece of the given radius (metres). `chips` = number of flat chipped faces; `rough` scales the
## surface relief (1 = a collected pebble; 0.4 = a nodule still in its vesicle).
static func make_mesh(seed: int, radius: float, chips := 4, rough := 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 14
	var arrays: Array = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n1 := FastNoiseLite.new()
	n1.seed = seed
	n1.frequency = 0.9
	var n2 := FastNoiseLite.new()
	n2.seed = seed + 101
	n2.frequency = 2.6
	var planes: Array = []
	for i in chips:
		var nrm := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		planes.append([nrm, rng.randf_range(0.6, 0.84)])
	var scl := Vector3(1.0, rng.randf_range(0.62, 0.82), rng.randf_range(0.76, 0.96))
	for i in verts.size():
		var dir := verts[i].normalized()
		var r := 1.0 + rough * (0.17 * n1.get_noise_3dv(dir * 2.0) + 0.07 * n2.get_noise_3dv(dir * 5.0))
		var q := dir * r
		for pl in planes:
			var dd: float = q.dot(pl[0])
			if dd > pl[1]:
				q -= pl[0] * (dd - pl[1])
		verts[i] = q * scl * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in verts.size():
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])
	for j in idx.size():
		st.add_index(idx[j])
	st.generate_normals()
	return st.commit()


## A MeshInstance3D of a rough piece with the carnelian material.
static func piece(seed: int, radius: float, chips := 4, rough := 1.0, sparkle := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = make_mesh(seed, radius, chips, rough)
	mi.material_override = material(seed, radius, sparkle)
	return mi
