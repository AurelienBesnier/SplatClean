extends MeshInstance3D

@export var scale_up := &"crop_box_scale_up"
@export var scale_down := &"crop_box_scale_down"
@export var move_x := &"crop_box_move_x+"
@export var move_minus_x := &"crop_box_move_x-"
@export var move_y := &"crop_box_move_y+"
@export var move_minus_y := &"crop_box_move_y-"
@export var move_z := &"crop_box_move_z+"
@export var move_minus_z := &"crop_box_move_z-"
@export var select := &"select"
@export var cull := &"cull"
@export var reset := &"reset"

@onready var splat_mesh_instance: MultiMeshInstance3D = $"../Splat/SplatMeshInstance"
@onready var selected_label : Label = $"../../../../StatContainer/SelectedLabel"

const SCALE_INCREMENT = 0.05
const MOVE_INCREMENT = 0.05

var sphere_center: Vector3
var sphere_radius: float

func _ready() -> void:
	pass

func calculate_bounding_sphere() -> void:
	var local_aabb = get_aabb()
	var local_center = local_aabb.position + (local_aabb.size / 2.0)
	sphere_center = global_transform * local_center
	
	var local_radius = local_center.distance_to(local_aabb.position)
	
	var s = global_transform.basis.get_scale()
	var max_scale = max(s.x, max(s.y, s.z))
	
	sphere_radius = local_radius * max_scale
	
	
func is_point_inside(target_point: Vector3) -> bool:
	var dist_squared: float = sphere_center.distance_squared_to(target_point)
	var radius_squared: float = sphere_radius * sphere_radius
	
	return dist_squared <= radius_squared
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible:
		process_actions(delta)
	
func process_actions(_delta: float):
	if Input.is_action_pressed(scale_up):
		var size = self.mesh.radius
		self.mesh.radius = size + SCALE_INCREMENT
		self.mesh.height = size * 2 + SCALE_INCREMENT
	if Input.is_action_pressed(scale_down):
		var size = self.mesh.radius
		if size >= 0.1:
			self.mesh.radius = size - SCALE_INCREMENT
			self.mesh.height = size * 2 - SCALE_INCREMENT

	# Movement
	if Input.is_action_pressed(move_x):
		translate_object_local(Vector3(-MOVE_INCREMENT, 0, 0))
	if Input.is_action_pressed(move_minus_x):
		translate_object_local(Vector3(MOVE_INCREMENT, 0, 0))
	if Input.is_action_pressed(move_y):
		translate_object_local(Vector3(0, MOVE_INCREMENT, 0))
	if Input.is_action_pressed(move_minus_y):
		translate_object_local(Vector3(0, -MOVE_INCREMENT, 0))
	if Input.is_action_pressed(move_z):
		translate_object_local(Vector3(0, 0, MOVE_INCREMENT))
	if Input.is_action_pressed(move_minus_z):
		translate_object_local(Vector3(0, 0, -MOVE_INCREMENT))
		
	if Input.is_action_just_pressed(select):
		select_points()
	if Input.is_action_just_pressed(cull):
		cull_points()
	if Input.is_action_just_pressed(reset):
		reset_selection()
		
func select_points() -> void:
	calculate_bounding_sphere()
	var number_selected = 0
	
	for i in range(splat_mesh_instance.multimesh.instance_count):
		var global_pos = to_local(splat_mesh_instance.multimesh.get_instance_transform(i).origin)
		var color = splat_mesh_instance.multimesh.get_instance_color(i)

		if not self.is_point_inside(global_pos):
			color.a8 = 3
			splat_mesh_instance.multimesh.set_instance_color(i, color)
		else:
			color.a8 = 255
			splat_mesh_instance.multimesh.set_instance_color(i, color)
			number_selected += 1
	
	selected_label.text = "Selected: " + str(number_selected)

func cull_points() -> void:
	for i in range(splat_mesh_instance.multimesh.instance_count):
		var instance_col = splat_mesh_instance.multimesh.get_instance_color(i)
		if instance_col.a8 == 3:
			instance_col.a8 = 0
			splat_mesh_instance.multimesh.set_instance_color(i, instance_col)
			
func reset_selection() -> void:
	for i in range(splat_mesh_instance.multimesh.instance_count):
		var instance_col = splat_mesh_instance.multimesh.get_instance_color(i)
		instance_col.a8 = 255
