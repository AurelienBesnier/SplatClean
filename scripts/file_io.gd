extends Control

@onready var open_file_dialog: FileDialog = $OpenFileDialog
@onready var open_camera_dialog: FileDialog = $OpenCameraDialog
@onready var save_file_dialog: FileDialog = $SaveFileDialog
@onready var open_button: Button = $"VBoxContainer/TopMenu/OpenButton"
@onready var camera_button: Button = $"VBoxContainer/TopMenu/CameraButton"
@onready var save_button: Button = $"VBoxContainer/TopMenu/SaveButton"
@onready var render_mode: OptionButton = $"VBoxContainer/ToolContainer/RenderOptions"

@onready var splat_mesh_instance: MultiMeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/Objects/Splat/SplatMeshInstance
@onready var camera_mesh_instance: MultiMeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/Objects/CameraMeshInstance
@onready var crop_box: MeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/CropBox/CropBox
@onready var crop_sphere: MeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/CropSphere

@onready var point_size_slider: HSlider = $"VBoxContainer/TopMenu/HSlider"
@onready var number_label: Label = $"VBoxContainer/SubViewportContainer/SubViewport/StatContainer/NumberLabel"
@onready var scale_spin_box: SpinBox = $"VBoxContainer/TopMenu/ScaleSpinBox"

@onready var process_button: Button = $"VBoxContainer/ToolContainer/AnalysisContainer/ProcessButton"
@onready var object_name: LineEdit = $"VBoxContainer/ToolContainer/AnalysisContainer/NameEdit"
@onready var spinner: Control = $VBoxContainer/ToolContainer/AnalysisContainer/SpinnerWrapper
@onready var crop_box_button: Button = $"VBoxContainer/ToolContainer/CropBoxButton"
@onready var crop_sphere_button: Button = $"VBoxContainer/ToolContainer/CropSphereButton"


# Struct to hold parsed metadata
var vertex_count: int = 0
var property_list: Array[String] = []
var is_binary: bool = false
var bytes_per_splat: int = 0
var x_offset: int = -1
var y_offset: int = -1
var z_offset: int = -1
var r_offset: int = -1
var g_offset: int = -1
var b_offset: int = -1
var opacity_offset: int = -1

# .splat format stuff
const position_offset = 0
const scale_offset = 12
const color_offset = 24
const rotation_offset = 28
const splat_size = 32

var scales: Array[float] = []
var rotations: Array[int] = []

var camera_file_path: String

var file_data: PackedByteArray # For web version
var file_name_web: String # For web version
var js_callback: JavaScriptObject # For web version

# Spherical Harmonics constant used to normalize base color
const SH_C0: float = 0.28209479177387814

func _ready() -> void:
	#### File Dialogs
	open_button.pressed.connect(func(): handle_open_dialog(open_file_dialog))
	open_file_dialog.file_selected.connect(_on_file_selected)
	
	camera_button.pressed.connect(func(): handle_open_dialog(open_camera_dialog))
	open_camera_dialog.file_selected.connect(_camera_selected)
	
	save_button.pressed.connect(func(): handle_save_dialog(save_file_dialog))
	save_file_dialog.confirmed.connect(_save_file)
	
	#### Buttons
	crop_box_button.pressed.connect(_box_select)
	crop_sphere_button.pressed.connect(_sphere_select)
	process_button.pressed.connect(_process_selection)
	scale_spin_box.value_changed.connect(_on_scale_changed)
	render_mode.item_selected.connect(_change_render_mode)
	
	# Connect slider to function
	point_size_slider.value_changed.connect(_on_h_slider_value_changed)
	
	
func _change_render_mode(mode):
	splat_mesh_instance.change_render(mode)
	
func _on_scale_changed(value):
	splat_mesh_instance.scale = Vector3(value,value,value)

#region WebInterface
func handle_open_dialog(dialog):
	if OS.has_feature("web"):
		trigger_web_upload() # Custom JS implementation
	else:
		dialog.popup_centered_ratio(0.7)
		
func handle_save_dialog(dialog):
	if OS.has_feature("web"):
		trigger_web_download() # Custom JS implementation
	else:
		dialog.popup_centered_ratio(0.7)

func trigger_web_download():
	# TODO: download result
	var content = PackedByteArray() # fill array
	var file_name = ""
	
	var js_code = """
	(function(filename, text) {
		let blob = new Blob([text], {type: 'text/plain'}); // content of the file
		let element = document.createElement('a');
		element.setAttribute('href', URL.createObjectURL(blob));
		element.setAttribute('download', filename);
		
		element.style.display = 'none';
		document.body.appendChild(element);
		
		element.click();
		
		document.body.removeChild(element);
		})
	"""
	JavaScriptBridge.eval(js_code)
	
	# Fetch the anonymous function
	var _window = JavaScriptBridge.get_interface("window")
	js_code.call(file_name, content)
		
func read_bytes_as_splat(data: PackedByteArray) -> void:
	is_binary = true
	var max_points_to_load = int(float(len(data)) / splat_size) # to make godot happy
	vertex_count = max_points_to_load
	
	var multimesh: MultiMesh = splat_mesh_instance.multimesh
	multimesh.instance_count = max_points_to_load
	
	print("got ", max_points_to_load, " to load")
	print("Reading points and colors...")
	var i = 0
	var instance_idx = 0
	while i < len(data):
		var x = data.decode_float(i)
		var y = data.decode_float(i+4)
		var z = data.decode_float(i+8)
		
		i += 12 # advance 3 float
		var scale_x = data.decode_float(i)
		var scale_y = data.decode_float(i+4)
		var scale_z = data.decode_float(i+8)
		scales.push_back(scale_x)
		scales.push_back(scale_y)
		scales.push_back(scale_z)
		
		i += 12 # advance 3 float
		var r = data.decode_u8(i) / 255.0
		var g = data.decode_u8(i+1) / 255.0
		var b = data.decode_u8(i+2) / 255.0
		var a = data.decode_u8(i+3) / 255.0
		
		i += 4 # advance 4 bytes
		var rot_x = data.decode_u8(i)
		var rot_y = data.decode_u8(i+1)
		var rot_z = data.decode_u8(i+2)
		var rot_t = data.decode_u8(i+3)
		rotations.push_back(rot_x)
		rotations.push_back(rot_y)
		rotations.push_back(rot_z)
		rotations.push_back(rot_t)
		i += 4 # adding the last 4 byte offset
		
		var tx = Transform3D(Basis(), Vector3(x, y, z))
		multimesh.set_instance_transform(instance_idx, tx)
		multimesh.set_instance_color(instance_idx, Color(r, g, b, a))
		
		instance_idx += 1
	print("Done !")
	
func trigger_web_upload():
	# JavaScript to inject a hidden file input and trigger it
	var js_code = """
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = '.splat,.ply,.json';
	
	input.onchange = e => { 
		var file = e.target.files[0]; 
		var reader = new FileReader();
		
		reader.onload = readerEvent => {
			var content = readerEvent.target.result; // This is an ArrayBuffer
			// Send the file name and content back to Godot
			window.godot_file_callback(file.name, new Uint8Array(content));
		}
		reader.readAsArrayBuffer(file);
	}
	input.click();
	"""
	var window = JavaScriptBridge.get_interface("window")
	js_callback = JavaScriptBridge.create_callback(_on_file_loaded)

	window.godot_file_callback = js_callback
	
	JavaScriptBridge.eval(js_code)


func _on_file_loaded(args) -> void:
	var file_name = args[0]
	var js_array = args[1]
	file_name_web = file_name
	
	file_data = PackedByteArray()
	file_data.resize(js_array.length)
	for i in range(js_array.length):
		file_data[i] = js_array[i]
		
	if file_name_web.ends_with('.splat'):
		read_bytes_as_splat(file_data)
	elif file_name_web.ends_with('.json'):
		read_bytes_as_cam(file_data)

func read_bytes_as_cam(data: PackedByteArray) -> void:
	var json_string = data.get_string_from_utf8()
	var json = JSON.new()
	var result = json.parse(json_string)
	
	if result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	camera_mesh_instance.multimesh.instance_count = len(json.data)
	
	var i: int = 0
	for key in json.data:
		var cam_pos = key['position']
		
		var tx = Transform3D(Basis(), Vector3(cam_pos[0], cam_pos[1], cam_pos[2]))
		camera_mesh_instance.multimesh.set_instance_transform(i, tx)
		i+=1
#endregion
func _box_select() -> void:
	crop_box.visible = true
	crop_sphere.visible = false
	
	crop_box.position = Vector3(0,0,0)

func _sphere_select() -> void:
	crop_box.visible = false
	crop_sphere.visible = true
	
	crop_sphere.position = Vector3(0,0,0)

#region Processing 
func _process_selection() -> void:
	# Prepare data in temporary directory (eg. /tmp)
	var tmp_file_path = OS.get_temp_dir() + '/splat_clean_tmp.splat'
	var splat_tmp = FileAccess.open(tmp_file_path, FileAccess.WRITE)
	if not splat_tmp: 
		print("Failed to create file: ", tmp_file_path)
		return
	save_splat_to_file(splat_tmp)
	spinner.visible = true
	var process_thread = Thread.new()
	# Start the thread and point it to our function
	var thread_callable = _process_in_background.bind(tmp_file_path)
	process_thread.start(thread_callable)
	
func _process_in_background(file_path):
	var output = []
	var platform = OS.get_name()
	var exit_code
	if platform == "Windows":
		# TODO: make a powershell version
		print("Cannot run bash scripts on windows")
		exit_code = 1
	else:
		exit_code = OS.execute("bash", ["./scripts/processing.sh", file_path, camera_file_path, object_name.text], output, true, false)
	_on_process_finished.call_deferred(exit_code, output)

func _on_process_finished(exit_code: int, output: Array):
	spinner.visible = false
	print("exit code: ", exit_code)
	if output.size() > 0:
		print("Output:\n", output[0])
	if FileAccess.file_exists("Archicrop.obj"): # Display result in seperate window
		var scene_resource = load("res://scenes/MeshView.tscn")
		var scene_instance = scene_resource.instantiate()
		
		var new_window = Window.new()
		new_window.title = "Mesh Viewer"
		new_window.size = Vector2i(800, 600)
		new_window.transient = false 
		new_window.world_3d = World3D.new()
		new_window.add_child(scene_instance)
		new_window.close_requested.connect(func(): new_window.queue_free())
		get_tree().root.add_child(new_window)
		new_window.position = DisplayServer.window_get_position() + Vector2i(50, 50)
#endregion

func _on_h_slider_value_changed(value) -> void:
	if render_mode.selected == 0:	# Only change the size of the point mesh
		var mat: ShaderMaterial = splat_mesh_instance.multimesh.mesh.surface_get_material(0)
		mat.set_shader_parameter("point_size", value)
	
func _camera_selected(path: String) -> void:
	print("Selected camera file: ", path)
	camera_file_path = path
	# Get contents
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var result = json.parse(json_string)
	if result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	camera_mesh_instance.multimesh.instance_count = len(json.data)
	
	var i: int = 0
	for key in json.data:
		var cam_pos = key['position']
		var cam_rotation = key['rotation']
		var row_0 = Vector3(cam_rotation[0][0], cam_rotation[0][1], cam_rotation[0][2])
		var row_1 = Vector3(cam_rotation[1][0], cam_rotation[1][1], cam_rotation[1][2])
		var row_2 = Vector3(cam_rotation[2][0], cam_rotation[2][1], cam_rotation[2][2])
		
		var tx = Transform3D(Basis(row_0, row_1, row_2), Vector3(cam_pos[0], cam_pos[1], cam_pos[2]))
		camera_mesh_instance.multimesh.set_instance_transform(i, tx)
		i+=1

func _on_file_selected(path: String) -> void:
	print("Attempting to open: ", path)
	if path.ends_with(".ply"):
		parse_ply_header(path)
	elif path.ends_with(".splat"):
		parse_splat(path)
	
	number_label.text = "Number of Gaussians: " + str(vertex_count)
	
func save_splat_to_file(file):
	for i in range(vertex_count):		
		var col = splat_mesh_instance.multimesh.get_instance_color(i)
		if col.a8 > 3 :
			var pos = splat_mesh_instance.multimesh.get_instance_transform(i).origin
			# Position
			file.store_float(pos.x)
			file.store_float(pos.y)
			file.store_float(pos.z)
			
			# Scale
			file.store_float(scales[i*3+0])
			file.store_float(scales[i*3+1])
			file.store_float(scales[i*3+2])
			
			# Color
			file.store_8(col.r8)
			file.store_8(col.g8)
			file.store_8(col.b8)
			file.store_8(col.a8)
			
			# Rotation
			file.store_8(rotations[i*4+0])
			file.store_8(rotations[i*4+1])
			file.store_8(rotations[i*4+2])
			file.store_8(rotations[i*4+3])

	file.close()
	
func _save_file() -> void:
	print("saving file")
	var save_path = save_file_dialog.current_path

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file: 
		print("Failed to create file: ", save_path)
		return

	save_splat_to_file(file)

func parse_splat(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	
	# Get object name from path (very specific to my layout)
	var splits = path.split("/")
	if len(splits) > 3:
		object_name.text = path.split("/")[-3]

	is_binary = true
	var max_points_to_load = int(float(file.get_length()) / splat_size) # to make godot happy
	vertex_count = max_points_to_load
	
	var multimesh: MultiMesh = splat_mesh_instance.multimesh
	multimesh.instance_count = max_points_to_load
	
	print("Reading points and colors...")
	for i in range(max_points_to_load):
		var splat_start_pos = file.get_position()
		file.seek(splat_start_pos + position_offset)
		
		var x = file.get_float()
		var y = file.get_float()
		var z = file.get_float()
		
		file.seek(splat_start_pos + scale_offset)
		var scale_x = file.get_float()
		var scale_y = file.get_float()
		var scale_z = file.get_float()
		scales.push_back(scale_x)
		scales.push_back(scale_y)
		scales.push_back(scale_z)
		
		file.seek(splat_start_pos + color_offset)
		var r = file.get_8() / 255.0
		var g = file.get_8() / 255.0
		var b = file.get_8() / 255.0
		var a = file.get_8() / 255.0
		
		file.seek(splat_start_pos + rotation_offset)
		var rot_x = file.get_8()
		var rot_y = file.get_8()
		var rot_z = file.get_8()
		var rot_w = file.get_8()
		rotations.push_back(rot_x)
		rotations.push_back(rot_y)
		rotations.push_back(rot_z)
		rotations.push_back(rot_w)
		
		var tx = Transform3D(Basis(Quaternion(rot_x, rot_y, rot_z, rot_w)).scaled(Vector3(scale_x,scale_y,scale_z)), Vector3(x, y, z))
		multimesh.set_instance_transform(i, tx)
		multimesh.set_instance_color(i, Color(r, g, b, a))
		
		file.seek(splat_start_pos + splat_size)

	file.close()
	

func parse_ply_header(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	if file.get_line().strip_edges() != "ply": return
	
	property_list.clear()
	vertex_count = 0
	is_binary = false
	
	while file.get_position() < file.get_length():
		var line = file.get_line().strip_edges()
		if line == "end_header": break
		var tokens = line.split(" ")
		if tokens[0] == "format" and "binary_little_endian" in tokens[1]:
			is_binary = true
		elif tokens[0] == "element" and tokens[1] == "vertex":
			vertex_count = int(tokens[2])
		elif tokens[0] == "property":
			property_list.append(tokens[2])

	calculate_property_offsets()
	_prepare_binary_reading(file)

func calculate_property_offsets() -> void:
	bytes_per_splat = 0
	x_offset = -1; y_offset = -1; z_offset = -1
	r_offset = -1; g_offset = -1; b_offset = -1
	opacity_offset = -1
	
	for i in range(property_list.size()):
		var prop = property_list[i]
		
		if prop == "x": x_offset = bytes_per_splat
		elif prop == "y": y_offset = bytes_per_splat
		elif prop == "z": z_offset = bytes_per_splat
		# 3DGS stores primary colors as f_dc_0, 1, 2 or red, green, blue
		elif prop == "f_dc_0" or prop == "red": r_offset = bytes_per_splat
		elif prop == "f_dc_1" or prop == "green": g_offset = bytes_per_splat
		elif prop == "f_dc_2" or prop == "blue": b_offset = bytes_per_splat
		elif prop == "opacity": opacity_offset = bytes_per_splat
		
		bytes_per_splat += 4 

func _prepare_binary_reading(file: FileAccess) -> void:
	if not is_binary:
		file.close()
		return
		
	print("Reading points and colors...")
	var max_points_to_load = vertex_count # Change to limit number of loaded splats
	
	var multimesh: MultiMesh = splat_mesh_instance.multimesh
	multimesh.instance_count = max_points_to_load
	
	for i in range(max_points_to_load):
		var splat_start_pos = file.get_position()
		
		file.seek(splat_start_pos + x_offset)
		var x = file.get_float()
		var y = file.get_float()
		var z = file.get_float()
		
		# Splat colors are Spherical Harmonics coefficients; we convert them to RGB
		file.seek(splat_start_pos + r_offset)
		var r_dc = file.get_float()
		var g_dc = file.get_float()
		var b_dc = file.get_float()
		
		var r = clampi(int((0.5 + SH_C0 * r_dc) * 255), 0, 255) / 255.0
		var g = clampi(int((0.5 + SH_C0 * g_dc) * 255), 0, 255) / 255.0
		var b = clampi(int((0.5 + SH_C0 * b_dc) * 255), 0, 255) / 255.0

		file.seek(splat_start_pos + opacity_offset)
		var raw_opacity = file.get_float()
		# Sigmoid formula: 1 / (1 + exp(-x))
		var alpha = 1.0 / (1.0 + exp(-raw_opacity))
		
		var tx = Transform3D(Basis(), Vector3(x, y, z))
		multimesh.set_instance_transform(i, tx)
		multimesh.set_instance_color(i, Color(r, g, b, alpha))
		
		# get next splat
		file.seek(splat_start_pos + bytes_per_splat)
		
	file.close()
	print("Rendered with colors and opacity successfully!")
