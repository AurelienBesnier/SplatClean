extends Control

@onready var open_file_dialog: FileDialog = $OpenFileDialog
@onready var save_file_dialog: FileDialog = $SaveFileDialog
@onready var open_button: Button = $"VBoxContainer/TopMenu/OpenButton"
@onready var save_button: Button = $"VBoxContainer/TopMenu/SaveButton"
@onready var splat_mesh_instance: MultiMeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/SplatMeshInstance
@onready var crop_box: MeshInstance3D = $VBoxContainer/SubViewportContainer/SubViewport/SplatScene/CropBox
@onready var point_size_slider: HSlider = $"VBoxContainer/TopMenu/HSlider"
@onready var number_label: Label = $"VBoxContainer/StatContainer/NumberLabel"

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

const position_offset = 0
const scale_offset = 12
const color_offset = 24
const rotation_offset = 28
const splat_size = 32

# Spherical Harmonics constant used to normalize base color
const SH_C0: float = 0.28209479177387814

func _ready() -> void:
	# Connect the button to open the file dialog
	open_button.pressed.connect(func(): open_file_dialog.popup_centered_ratio(0.7))
	# Connect the file dialog selection event
	open_file_dialog.file_selected.connect(_on_file_selected)
	
	save_button.pressed.connect(func(): save_file_dialog.popup_centered_ratio(0.7))
	save_file_dialog.confirmed.connect(_save_file)
	
	# Connect slider to function
	point_size_slider.value_changed.connect(_on_h_slider_value_changed)
	
	
	
func _on_h_slider_value_changed(value) -> void:
	splat_mesh_instance.multimesh.mesh.radius = value
	splat_mesh_instance.multimesh.mesh.height = value * 2


func _on_file_selected(path: String) -> void:
	print("Attempting to open: ", path)
	if path.ends_with(".ply"):
		parse_ply_header(path)
	elif path.ends_with(".splat"):
		parse_splat(path)
	
	number_label.text = "Number of Gaussians: " + str(vertex_count)
	
func _save_file() -> void:
	print("saving file")
	var save_path = save_file_dialog.current_path

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file: 
		print("Failed to create file: ", save_path)
		return

	for i in range(vertex_count):
		var splat_start_pos = file.get_position()
		
		var col = splat_mesh_instance.multimesh.get_instance_color(i)
		if col.a8 > 3 :
			var pos = splat_mesh_instance.multimesh.get_instance_transform(i).origin
			# Position
			var x = pos.x
			var y = pos.y
			var z = pos.z
			
			file.store_float(x)
			file.store_float(y)
			file.store_float(z)
			
			# Scale
			file.store_float(0.0)
			file.store_float(0.0)
			file.store_float(0.0)
			
			# Color
			file.store_8(col.r8)
			file.store_8(col.g8)
			file.store_8(col.b8)
			file.store_8(col.a8)
			
			# Rotation
			file.store_8(0)
			file.store_8(0)
			file.store_8(0)
			file.store_8(0)
			

	file.close()

func parse_splat(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return

	is_binary = true
	var max_points_to_load = file.get_length() / splat_size # Change to limit number of loaded splats
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
		#var scale_x = file.get_float()
		#var scale_y = file.get_float()
		#var scale_z = file.get_float()
		
		file.seek(splat_start_pos + color_offset)
		var r = file.get_8() / 255.0
		var g = file.get_8() / 255.0
		var b = file.get_8() / 255.0
		
		file.seek(splat_start_pos + rotation_offset)
		#var rot_x = file.get_8()
		#var rot_y = file.get_8()
		#var rot_z = file.get_8()
		
		var tx = Transform3D(Basis(), Vector3(x, y, z))
		multimesh.set_instance_transform(i, tx)
		multimesh.set_instance_color(i, Color(r, g, b, 1.0))
		
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
