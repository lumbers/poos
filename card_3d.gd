extends Node3D

var is_dragging: bool = false
@onready var main_game = get_node("/root/MainGame")

# Drop your sanic.tres file into this slot in the inspector later!
@export var card_info: CardData
@onready var preview_panel = get_node("/root/MainGame/CanvasLayer/CardPreviewPanel")

# --- NEW HOVER CONTROLS ---
var default_position: Vector3
var is_hovered: bool = false

func _ready():
	await get_tree().process_frame
	if card_info != null:
		load_card_data()
	$Area3D.mouse_entered.connect(_on_mouse_entered)
	$Area3D.mouse_exited.connect(_on_mouse_exited)
	# Connect the input event to handle dragging clicks
	$Area3D.input_event.connect(_on_input_event)

# FIXED: Moved completely outside of _ready() so it sits at the proper class level!
func _on_input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int):
	# If left mouse button is pressed down, start dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Safety: Only drag if it's a Pie type card for now!
			if card_info and card_info.card_type.to_lower() == "pie":
				is_dragging = true
				# FIXED: Stripped out the hidden invisible formatting character at the end of this line
				$Area3D.input_ray_pickable = false 
		elif !event.pressed and is_dragging:
			# Released mouse button! Stop dragging and check for placement
			is_dragging = false
			$Area3D.input_ray_pickable = true
			_check_field_drop()

func _process(delta):
	if is_dragging:
		# Dragging math: Project a ray from the camera through the mouse position onto a flat table plane
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Create a mathematical plane sitting at table height (Y = 0.1)
		var project_plane = Plane(Vector3.UP, 0.1)
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		
		var intersect_point = project_plane.intersects_ray(ray_origin, ray_dir)
		if intersect_point:
			# Smoothly lag the card slightly behind the mouse cursor for weight feel
			global_position = global_position.lerp(intersect_point + Vector3(0, 0.2, 0), 25 * delta)
			# Hold it horizontal flat face-up while dragging over the grid
			global_rotation = Vector3(deg_to_rad(-90), 0, 0)
	
func load_card_data():
	var template = $MeshInstance3D/SubViewport/PieTemplate
	
	# ==========================================================
	# RULE 1: FULL PAPER CARDS (Like Fireball)
	# ==========================================================
	if card_info.use_full_paper_image == true:
		template.get_node("Label").visible = false
		template.get_node("NameHP").visible = false
		template.get_node("RichTextLabel").visible = false
		template.get_node("Label3").visible = false
		
		var art_rect = template.get_node("TextureRect")
		art_rect.position = Vector2(0, 0)
		art_rect.size = Vector2(350, 500)
		
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		if card_info.card_art != null:
			art_rect.texture = card_info.card_art

	# ==========================================================
	# RULE 2: SYSTEM CARDS (Dynamic Layouts like Sanic)
	# ==========================================================
	else:
		# Reset visibility defaults
		template.get_node("Label").visible = true
		template.get_node("RichTextLabel").visible = true
		template.get_node("Label3").visible = true
		template.get_node("NameHP").visible = true
		
		var art_rect = template.get_node("TextureRect")
		art_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		if card_info.card_art != null:
			art_rect.texture = card_info.card_art
			
		# Set type text and attribute
		template.get_node("Label").text = card_info.card_type
		template.get_node("Label3").text = card_info.attribute
		
		# ---- THE PIE TYPE SPARK CHECK ----
		var type_check = card_info.card_type.to_lower()
		
		if type_check == "pie":
			template.get_node("NameHP").text = card_info.card_name + "  HP:" + str(card_info.max_hp)
			template.get_node("NameHP").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var raw_text = card_info.passives_and_attacks
			template.get_node("RichTextLabel").text = "[outline_size=5][outline_color=black]" + raw_text + "[/outline_color][/outline_size]"
		
		else:
			template.get_node("NameHP").text = card_info.card_name
			template.get_node("NameHP").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			var raw_text = card_info.passives_and_attacks
			template.get_node("RichTextLabel").text = "[outline_size=5][outline_color=black][center]" + raw_text + "[/center][/outline_color][/outline_size]"

# --- SMOOTH TWEEN ANIMATIONS ---
func _on_mouse_entered():
	if card_info == null or get_parent() == get_node("/root/MainGame"):
		return
		
	is_hovered = true
	
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		manager.hovered_card_index = get_index()
		manager.arrange_hand()

func _on_mouse_exited():
	if !is_hovered:
		return
	is_hovered = false
	
	if preview_panel:
		preview_panel.visible = false
		
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		if manager.hovered_card_index == get_index():
			manager.hovered_card_index = -1
			manager.arrange_hand()

func _check_field_drop():
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.name == "FieldDropZone":
		if main_game and main_game.has_method("try_place_pie_on_field"):
			main_game.try_place_pie_on_field(self)
			return
			
	is_hovered = false
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		manager.hovered_card_index = -1
		manager.arrange_hand()
