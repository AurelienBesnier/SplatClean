extends MultiMeshInstance3D

@export
var camera: Camera3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var file_path := "./segmentation.json"
	var segmentation = load_segmentation_at_runtime(file_path)
	if segmentation:
		update_camera_position()
		print("Loaded segmentation")
	else:
		printerr("Error reading JSON file")


func update_camera_position():
	var max_position = self.multimesh.get_aabb().get_longest_axis_size()
	var initial_position = camera.position
	camera.position = Vector3(initial_position.x,max_position/2,max_position)

static func generate_palette(n: int, saturation: float = 0.7, value: float = 0.9):
	var palette: Array[Color] = []

	var step: float = 1.0 / float(n)
	
	for i in range(n):
		var hue: float = fmod(i * step, 1.0)
		var color: Color = Color.from_hsv(hue, saturation, value)
		palette.append(color)
		
	return palette


func load_segmentation_at_runtime(file_path: String):
	# Reading file
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var result = json.parse(json_string)
	if result != OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	var data = json.data

	var num_voxels = 0
	var num_organs = len(data['voxel_organs'])
	var colors = generate_palette(num_organs)
	
	# get number of elements first
	for vo in data['voxel_organs']:
		var segment = vo['voxel_segments']
		#print(segment)
		for element in segment:
			var positions = element['voxels_position']
			num_voxels += len(positions)

	multimesh.instance_count = num_voxels
	var i = 0
	var id_organ = 0
	for vo in data['voxel_organs']:
		var segment = vo['voxel_segments']
		#print(segment)
		for element in segment:
			var positions = element['voxels_position']
			for pos in positions:
				var tx = Transform3D(Basis(), Vector3(pos[0], pos[1], pos[2]))
				multimesh.set_instance_transform(i, tx)
				multimesh.set_instance_color(i, colors[id_organ])
				i+=1
		id_organ+=1

	print("Number of organs: ", num_organs)
	print("Number of voxels: ", multimesh.instance_count)
	
	return true
