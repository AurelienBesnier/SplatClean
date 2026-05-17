extends MeshInstance3D

@export var scale_up := &"crop_box_scale_up"
@export var scale_down := &"crop_box_scale_down"
@export var move_x := &"crop_box_move_x+"
@export var move_minus_x := &"crop_box_move_x-"

const SCALE_INCREMENT = 0.01
const MOVE_INCREMENT = 0.01

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

	if Input.is_action_pressed(move_x):
		var pos = self.transform.origin
		self.transform.origin.x += MOVE_INCREMENT
	if Input.is_action_pressed(move_minus_x):
		var pos = self.transform.origin
		self.transform.origin.x -= MOVE_INCREMENT
