extends MeshInstance3D

@export
var material: ShaderMaterial

@export
var camera: Camera3D

func _ready() -> void:
	var test_path := "res://assets/Archicrop.obj"
	var imported_mesh = load_obj_at_runtime(test_path)
	if imported_mesh:
		self.mesh = imported_mesh
		self.mesh.surface_set_material(0, material)
		update_camera_position()
	else:
		print("Error reading OBJ file")

func update_camera_position():
	var max_position = self.mesh.get_aabb().get_longest_axis_size()
	var initial_position = camera.position
	camera.position = Vector3(initial_position.x,initial_position.y,max_position)

func load_obj_at_runtime(file_path: String) -> ArrayMesh:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file: return
	var text = file.get_as_text()
	file.close()

	var vertices: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var normals: PackedVector3Array = []
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var lines = text.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
			
		var parts = line.split(" ", false)
		var line_type = parts[0]

		match line_type:
			"v": # Position
				vertices.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vt": # UVs
				# OBJ Y-axis for UVs is inverted compared to Godot
				uvs.append(Vector2(float(parts[1]), 1.0 - float(parts[2])))
			"vn": # Normal
				normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"f": # Faces
				if parts.size() == 4:
					_add_face_vertex(parts[1], vertices, uvs, normals, st)
					_add_face_vertex(parts[2], vertices, uvs, normals, st)
					_add_face_vertex(parts[3], vertices, uvs, normals, st)
				elif parts.size() == 5:
					_add_face_vertex(parts[1], vertices, uvs, normals, st)
					_add_face_vertex(parts[2], vertices, uvs, normals, st)
					_add_face_vertex(parts[3], vertices, uvs, normals, st)
					
					_add_face_vertex(parts[1], vertices, uvs, normals, st)
					_add_face_vertex(parts[3], vertices, uvs, normals, st)
					_add_face_vertex(parts[4], vertices, uvs, normals, st)

	if normals.is_empty():
		st.generate_normals()
	if not uvs.is_empty():
		st.generate_tangents()

	return st.commit()

func _add_face_vertex(token: String, vertices: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array, st: SurfaceTool) -> void:
	var indices = token.split("/")
	if indices.size() > 1 and not indices[1].is_empty():
		var uv_index = int(indices[1]) - 1
		if uv_index < uvs.size():
			st.set_uv(uvs[uv_index])

	if indices.size() > 2 and not indices[2].is_empty():
		var normal_index = int(indices[2]) - 1
		if normal_index < normals.size():
			st.set_normal(normals[normal_index])

	var vertex_index = int(indices[0]) - 1
	if vertex_index < vertices.size():
		st.add_vertex(vertices[vertex_index])
