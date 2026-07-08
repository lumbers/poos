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
	
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0, 0.05, 0) 
	
	mat.color = Color(0.05, 0.0, 0.1, 0.8)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.05, 0.0, 0.1, 0.9))
	gradient.add_point(0.6, Color(0.02, 0.0, 0.08, 0.4))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.05, 0.0))
	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp
	
	mat.scale_min = 0.08
	mat.scale_max = 0.25
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.4
	
	aura_particles.process_material = mat
	aura_particles.amount = 60
	aura_particles.lifetime = 1.8
	aura_particles.local_coords = false
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(0.05, 0.0, 0.1, 0.6)
	
	# FIX 1: Change Additive to Mix so dark smoke actually appears
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX 
	# FIX 2: Prevent the smoke from clipping into the card
	draw_mat.no_depth_test = true 
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
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
	
	# FIX 3: Make the red eye particles a little bit bigger
	mat.scale_min = 0.05
	mat.scale_max = 0.10
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.05
	
	eye_particles.process_material = mat
	eye_particles.amount = 20
	eye_particles.lifetime = 0.8
	
	# FIX 4: Pull the particles further forward on the Z axis
	eye_particles.position = Vector3(0, 0.05, 0.1)
	
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	
	# FIX 5: Prevent the eyes from clipping into the card
	draw_mat.no_depth_test = true 
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.04, 0.04)
	mesh.material = draw_mat
	eye_particles.draw_pass_1 = mesh

func _setup_eye_light():
	eye_light.light_color = Color(1.0, 0.0, 0.0)
	eye_light.light_energy = 0.0  # starts off
	eye_light.omni_range = 1.5
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
	# Fade out the light
	var t = create_tween()
	t.tween_property(eye_light, "light_energy", 0.0, 0.5)
	t.tween_callback(func(): visible = false)

func _start_eye_pulse():
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(eye_light, "light_energy", 2.5, 0.6)
	pulse_tween.tween_property(eye_light, "light_energy", 0.8, 0.6)
