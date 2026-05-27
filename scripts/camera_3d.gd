extends "res://addons/goutte.camera.trackball/trackball_camera.gd"

@export var middle_mouse := &"cam_move"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	super._process(delta)


func process_mouse(_delta: float):
	if Input.is_action_pressed(middle_mouse):
		if self.mouse_enabled and _mouseDragPosition != ABSURD_VECTOR2:
			var _currentDragPosition := get_mouse_position()
			var intent := _currentDragPosition - _mouseDragPosition
			intent *= self.mouse_strength * MOUSE_DRAG_STRENGTH_NORMALIZATION
			if self.mouse_invert_x:
				intent *= Vector2.LEFT
			if self.mouse_invert_y:
				intent *= Vector2.UP
			add_inertia(intent, (_currentDragPosition - HALF_VECTOR2) * MIRRORED_Y)
			_mouseDragPosition = _currentDragPosition
