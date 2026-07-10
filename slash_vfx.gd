extends GPUParticles3D

func _ready():
	var mat = ParticleProcessMaterial.new()
	
	# Slashes shoot out horizontally
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -0.5, 0)
	
	# Dark red/black color like Sukuna's slashes
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.0, 0.0, 1.0))
	gradient.add_point(0.3, Color(0.4, 0.0, 0.0, 0.9))
	gradient.add_point(1.0, Color(0.1, 0.0, 0.0, 0.0))
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	
	# Emit from a wide area across the background
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.0, 1.5, 0.1)
	
	process_material = mat
	amount = 40
	lifetime = 0.6
	explosiveness = 0.8  # burst mode for slash feel
	one_shot = true
	
	# Wide thin quad for slash shape
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.albedo_color = Color(0.8, 0.0, 0.0, 1.0)
	draw_mat.vertex_color_use_as_albedo = true
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.6, 0.04)  # long and thin = slash shape
	mesh.material = draw_mat
	draw_pass_1 = mesh
