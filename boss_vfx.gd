extends Node3D

@onready var aura_particles: GPUParticles3D = $AuraParticles
@onready var eye_light: OmniLight3D = $EyeLight
@onready var eye_particles: GPUParticles3D = $EyeParticles

var pulse_tween: Tween

func _ready():
	visible = false
	_setup_aura_particles()
	_setup_eye_particles()
	_setup_eye_light()

func _setup_aura_particles():
	var mat = ParticleProcessMaterial.new()
	
	# Shoot outward from center, NOT forward toward camera
	mat.direction = Vector3(0, 1, 0)  # push backward away from camera
	mat.spread = 180.0  # full spread but constrained by emission shape
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0, 0.3, 0)
	
	# Keep same dark gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.639, 0.0, 0.043, 0.255))
	gradient.add_point(0.2, Color(0.084, 0.0, 0.003, 0.85))
	gradient.add_point(1.0, Color(0.298, 0.0, 0.004, 0.38))
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	mat.scale_min = 0.4
	mat.scale_max = 1.2
	
	# Emit from a thin ring around the card EDGES, not the center face
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.55, 0.75, 0.01)  # flat box = card outline
	
	aura_particles.process_material = mat
	aura_particles.amount = 80
	aura_particles.lifetime = 2.0
	aura_particles.local_coords = true  # ← important: moves with card
	
	# Push emitter BEHIND the card face
	aura_particles.position = Vector3(0, 0, -0.3)  # further behind card
	
	# And reduce particle scale so they don't wrap around front
	mat.scale_min = 0.3
	mat.scale_max = 0.9
	
	# Same smoke texture setup as before
	var smoke_grad = Gradient.new()
	smoke_grad.add_point(0.0, Color(1, 1, 1, 1))
	smoke_grad.add_point(0.4, Color(1.0, 1.0, 1.0, 0.6))
	smoke_grad.add_point(1.0, Color(0.637, 0.132, 0.089, 0.0))
	
	var smoke_tex = GradientTexture2D.new()
	smoke_tex.gradient = smoke_grad
	smoke_tex.fill = GradientTexture2D.FILL_RADIAL
	smoke_tex.fill_from = Vector2(0.5, 0.5)
	smoke_tex.fill_to = Vector2(0.9, 0.9)
	smoke_tex.width = 64
	smoke_tex.height = 64
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # additive = glows behind naturally
	draw_mat.albedo_texture = smoke_tex
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.no_depth_test = false  # ← respect depth so card renders in front
	draw_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = draw_mat
	aura_particles.draw_pass_1 = mesh

func _setup_eye_particles():
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.3
	mat.gravity = Vector3(0, 0.1, 0)
	mat.color = Color(1.0, 0.0, 0.0, 1.0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.1, 0.0, 1.0))
	gradient.add_point(1.0, Color(1.0, 0.0, 0.0, 0.0))
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	mat.scale_min = 0.05
	mat.scale_max = 0.10
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.05
	
	eye_particles.process_material = mat
	eye_particles.amount = 20
	eye_particles.lifetime = 0.8
	
	# In _setup_eye_particles, change position to:
	eye_particles.position = Vector3(0, 0.15, 0.06)  # tweak Y to match eye height
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	
	draw_mat.no_depth_test = true 
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.04, 0.04)
	mesh.material = draw_mat
	eye_particles.draw_pass_1 = mesh

func _setup_eye_light():
	eye_light.light_color = Color(1.0, 0.0, 0.0)
	eye_light.light_energy = 0.0  
	eye_light.omni_range = 3
	eye_light.position = Vector3(0, 0.05, 0.05)

func activate():
	visible = true
	aura_particles.emitting = true
	eye_particles.emitting = true
	_start_eye_pulse()

func deactivate():
	aura_particles.emitting = false
	eye_particles.emitting = false
	if pulse_tween:
		pulse_tween.kill()
	var t = create_tween()
	t.tween_property(eye_light, "light_energy", 0.0, 0.5)
	t.tween_callback(func(): visible = false)

func _start_eye_pulse():
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(eye_light, "light_energy", 2.5, 0.6)
	pulse_tween.tween_property(eye_light, "light_energy", 0.8, 0.6)
