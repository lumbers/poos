extends GPUParticles3D

func _ready():
	var mat = ParticleProcessMaterial.new()
	
	# Direction doesn't matter much if we're slashing everywhere in place,
	# but spread + rotation will make it look chaotic!
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 360.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, 0, 0)
	
	# Massive sizing variation
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	
	# Wild, jagged angular rotation so they slice at crazy angles
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	
	# Make them spawn across a vast grid in the background
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(12.0, 6.0, 1.0)
	
	process_material = mat
	amount = 25 # Fewer, larger chunkier cuts look better than tiny noise
	lifetime = 0.4
	explosiveness = 0.95
	
	# --- GENERATE ANIME OUTLINE TEXTURE ---
	# We dynamically create a black slash with a sharp white border
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			# Map to a long thin center line slice
			var dist_to_center_line = abs(y - 32)
			var dist_to_ends = abs(x - 32)
			
			# Sharp procedural cut shape
			if dist_to_center_line < 3 and dist_to_ends < 28:
				img.set_pixel(x, y, Color.BLACK) # Sharp black inner blade
			elif dist_to_center_line < 6 and dist_to_ends < 30:
				img.set_pixel(x, y, Color.WHITE) # High contrast white edge outline
			else:
				img.set_pixel(x, y, Color(0,0,0,0)) # Transparent background
				
	var slash_texture = ImageTexture.create_from_image(img)
	
	# --- MATERIAL SETUP ---
	var draw_mat = StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Mix blend mode lets us overlay pure black over your background textures!
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	draw_mat.albedo_texture = slash_texture
	
	# Ensure the particles face the camera properly like flat cuts
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(2.5, 0.4) # Extra long and wide proportions
	mesh.material = draw_mat
	draw_pass_1 = mesh
