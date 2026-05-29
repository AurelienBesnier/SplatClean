extends TextureRect

# Speed of the rotation (degrees per second)
@export var rotation_speed: float = 360.0
@onready var controler: Control = $"../"

func _process(delta: float) -> void:
	if controler.visible:
		rotation_degrees -= rotation_speed * delta
