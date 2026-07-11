extends Node3D

func _ready():
	# --- 1. SETUP THE METEOR CORE ROCK ---
	var rock_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.15, 0.1, 0.1) # Dark volcanic rock
	rock_mat.roughness = 0.9
	rock_mat.emission_enabled = true
	rock_mat.emission = Color(0.8, 0.2, 0.0) # Magma glowing cracks
	rock_mat.emission_energy_multiplier = 2.0
	sphere.material = rock_mat
	rock_mesh.mesh = sphere
	add_child(rock_mesh)
	
	# --- 2. SETUP THE FLAME TRAIL PARTICLES ---
	var trail = GPUParticles3D.new()
	var mat = ParticleProcessMaterial.new()
	
	# Shoot backwards relative to velocity (assuming moving forward along -Z)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 15.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, 1.0, 0) # Fire rises slightly upward
	
	# Shrink as it burns out
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1, 0.1))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	
	# Intense Psychic Fire Gradient (Bright Violet Core -> Blazing Orange -> Dark Smoke)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.1, 1.0, 1.0)) # Psychic purple core
	gradient.add_point(0.2, Color(1.0, 0.3, 0.0, 1.0)) # Blazing magma orange
	gradient.add_point(0.6, Color(0.4, 0.0, 0.0, 0.6)) # Fading embers dark red
	gradient.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0)) # Faded transparent smoke
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	trail.process_material = mat
	trail.amount = 80
	trail.lifetime = 0.45
	
	# Particle Draw Pass Materials
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD # Glow effect!
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = draw_mat
	trail.draw_pass_1 = quad
	
	add_child(trail)
	trail.emitting = true
