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

@onready var splat_mesh_instance: MultiMeshInstance3D = $"../SplatMeshInstance"


const SCALE_INCREMENT = 0.05
const MOVE_INCREMENT = 0.05

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	process_actions(delta)
	
func process_actions(delta: float):
	if Input.is_action_pressed(scale_up):
		var size = self.mesh.size
		self.mesh.size = Vector3(size.x+SCALE_INCREMENT,size.z+SCALE_INCREMENT,size.z+SCALE_INCREMENT)
	if Input.is_action_pressed(scale_down):
		var size = self.mesh.size
		if size.x >= 0.1:
			self.mesh.size = Vector3(size.x-SCALE_INCREMENT,size.z-SCALE_INCREMENT,size.z-SCALE_INCREMENT)

	# Movement
	if Input.is_action_pressed(move_x):
		translate(Vector3(MOVE_INCREMENT, 0, 0))
	if Input.is_action_pressed(move_minus_x):
		translate(Vector3(-MOVE_INCREMENT, 0, 0))
	if Input.is_action_pressed(move_y):
		translate(Vector3(0, MOVE_INCREMENT, 0))
	if Input.is_action_pressed(move_minus_y):
		translate(Vector3(0, -MOVE_INCREMENT, 0))
	if Input.is_action_pressed(move_z):
		translate(Vector3(0, 0, MOVE_INCREMENT))
	if Input.is_action_pressed(move_minus_z):
		translate(Vector3(0, 0, -MOVE_INCREMENT))
		
	if Input.is_action_just_pressed(select):
		select_points()
	if Input.is_action_just_pressed(cull):
		cull_points()
	if Input.is_action_just_pressed(reset):
		reset_selection()
		
func select_points() -> void:
	var aabb = self.get_aabb()
	
	for i in range(splat_mesh_instance.multimesh.instance_count):
		var instance_transform = splat_mesh_instance.multimesh.get_instance_transform(i)
		var global_pos = to_global(Vector3(instance_transform.origin.x,instance_transform.origin.y,
			instance_transform.origin.z))
		
		if not aabb.has_point(global_pos):
			var initial_color = splat_mesh_instance.multimesh.get_instance_color(i)
			var hidden = initial_color
			hidden.a8 = 3
			splat_mesh_instance.multimesh.set_instance_color(i, hidden)
			
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
		splat_mesh_instance.multimesh.set_instance_color(i, instance_col)
		
