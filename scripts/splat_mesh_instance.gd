extends MultiMeshInstance3D

@export var camera: Camera3D

@export var splat_material: ShaderMaterial
@export var point_material: ShaderMaterial

func change_render(mode):
	if mode == 0: # Render centers
		self.multimesh.mesh = PointMesh.new()
		self.multimesh.mesh.surface_set_material(0, point_material)
		
	elif mode == 1: # Render 'Gaussians'
		self.multimesh.mesh = QuadMesh.new()
		self.multimesh.mesh.surface_set_material(0, splat_material)


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray = get_ray_from_mouse(mouse_pos)
		var intersection = intersect_ray_with_multimesh(ray[0], ray[1], self)

		if intersection:
			print("Hit at: ", intersection["position"])
			print("Normal: ", intersection["normal"])
			print("Distance: ", intersection["distance"])


func get_ray_from_mouse(mouse_pos: Vector2) -> Array:
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var ray_direction = (to - from).normalized()
	return [from, ray_direction]
	

func intersect_ray_with_multimesh(ray_origin: Vector3, ray_direction: Vector3, multimesh_instance: MultiMeshInstance3D) -> Dictionary:
	var multimesh = multimesh_instance.multimesh
	var result = {}
	var closest_distance = INF
	var closest_position = Vector3.ZERO
	var closest_normal = Vector3.ZERO

	for i in range(multimesh.get_instance_count()):
		var instance_transform = multimesh.get_instance_transform(i)
		var instance_origin = instance_transform.origin

		var direction_to_instance = (instance_origin - ray_origin).normalized()
		if direction_to_instance.dot(ray_direction) > 0.9:
			var distance = ray_origin.distance_to(instance_origin)
			if distance < closest_distance:
				closest_distance = distance
				closest_position = instance_origin
				closest_normal = -ray_direction

	if closest_distance != INF:
		result["collider"] = multimesh_instance
		result["position"] = closest_position
		result["normal"] = closest_normal
		result["distance"] = closest_distance

	return result
