extends MultiMeshInstance3D

@export var camera: Camera3D
@export var root_node: Node3D

@export var splat_material: ShaderMaterial
@export var point_material: ShaderMaterial

var index_indicator: int

func change_render(mode):
	if mode == 0: # Render centers
		self.multimesh.mesh = PointMesh.new()
		self.multimesh.mesh.surface_set_material(0, point_material)
		
	elif mode == 1: # Render 'Gaussians'
		self.multimesh.mesh = QuadMesh.new()
		self.multimesh.mesh.surface_set_material(0, splat_material)


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray = get_ray_from_mouse(mouse_pos)
		var intersection = intersect_ray_with_multimesh(ray[0], ray[1])

		if intersection:
			print("Hit at: ", intersection["position"])
			print("Distance: ", intersection["distance"])
			multimesh.set_instance_color(index_indicator, Color(1.0, 0.0, 1.0, 1.0))


func get_ray_from_mouse(mouse_pos: Vector2) -> Array:
	var from = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	return [from, ray_direction]
	

func intersect_ray_with_multimesh(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	var result = {}
	var closest_distance = INF
	var closest_position = Vector3.ZERO
	var mesh_radius = 0.005 # TODO: make an adaptative mesh to the point size attribute 
	
	for i in range(multimesh.get_instance_count()):
		
		var col = multimesh.get_instance_color(i)
		if col.a8 > 3 : # Only the selected ones
			var instance_transform = multimesh.get_instance_transform(i)
			var instance_origin = instance_transform.origin
			var world_pos = self.global_transform * instance_origin

			var hit_distance = _ray_sphere_intersect(ray_origin, ray_direction, world_pos, mesh_radius)

			if hit_distance > 0.0 and hit_distance < closest_distance:
				closest_distance = hit_distance
				closest_position = ray_origin + ray_direction * hit_distance
				index_indicator = i


		if closest_distance != INF:
			result["position"] = closest_position
			result["distance"] = closest_distance

	return result

func _ray_sphere_intersect(ray_origin: Vector3, ray_dir: Vector3, sphere_center: Vector3, radius: float) -> float:
	var oc := ray_origin - sphere_center
	var b := oc.dot(ray_dir)
	var c := oc.dot(oc) - radius * radius
	var discriminant := b * b - c

	if discriminant < 0.0:
		return -1.0 

	var t := -b - sqrt(discriminant)
	return t if t > 0.0 else -1.0
