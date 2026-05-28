extends MultiMeshInstance3D

@export var splat_material: ShaderMaterial
@export var point_material: ShaderMaterial

func change_render(mode):
	if mode == 0: # Render centers
		self.multimesh.mesh = PointMesh.new()
		self.multimesh.mesh.surface_set_material(0, point_material)
		
	elif mode == 1: # Render 'Gaussians'
		self.multimesh.mesh = QuadMesh.new()
		self.multimesh.mesh.surface_set_material(0, splat_material)
