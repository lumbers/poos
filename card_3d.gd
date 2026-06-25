extends Node3D

var is_dragging: bool = false
var is_on_board: bool = false 

@onready var main_game = get_node("/root/MainGame")

@export var card_info: CardData
@onready var preview_panel = get_node("/root/MainGame/CanvasLayer/CardPreviewPanel")

# --- NEW HP FLOATING TRACKER NODE ---
@onready var hp_tracker = $HPTracker

var default_position: Vector3
var is_hovered: bool = false

# Track the actual dynamic current health of this specific card instance
var current_hp: int = 0

func _ready():
	await get_tree().process_frame
	if card_info != null:
		load_card_data()
		# Initialize our health using the card resource base stat
		current_hp = card_info.max_hp
		
	# Start with the floating UI hidden because the card is in the player's hand!
	if hp_tracker:
		hp_tracker.visible = false
		
	$Area3D.mouse_entered.connect(_on_mouse_entered)
	$Area3D.mouse_exited.connect(_on_mouse_exited)
	$Area3D.input_event.connect(_on_input_event)

# --- NEW FUNCTION TO UPDATE AND DISPLAY HEALTH ---
func update_field_hp_display():
	if hp_tracker and card_info:
		# Check if it's a Pie card (since only Pies have HP values)
		if card_info.card_type.to_lower() == "pie":
			# Display just the raw current HP number cleanly
			hp_tracker.text = str(current_hp)
			# Make it visible only if the card has officially been placed on the board
			hp_tracker.visible = is_on_board
		else:
			hp_tracker.visible = false

# --- NEW FUNCTION TO HANDLE HEALING / DAMAGE OVER TIME ---
func heal_pie(amount: int):
	# Because Pies can be over-healed past their starting max_hp baseline,
	# we simply add directly to the current pool with no upper ceiling clamping!
	current_hp += amount
	update_field_hp_display()

func take_damage(amount: int):
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0
	update_field_hp_display()

func _on_input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int):
	if is_on_board:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if main_game and main_game.has_node("Camera3D/CardManager"):
			for existing_card in main_game.get_node("Camera3D/CardManager").get_children():
				if existing_card.get("is_dragging") == true:
					return

		if card_info and card_info.card_type.to_lower() == "pie":
			is_dragging = true
			$Area3D.input_ray_pickable = false 
			
			if main_game and main_game.has_method("activate_field_drop_zone"):
				main_game.activate_field_drop_zone(true)
			
			var manager = get_parent()
			if manager and manager.has_method("arrange_hand"):
				manager.hovered_card_index = -1
				manager.arrange_hand()

func _input(event: InputEvent):
	if is_on_board or !is_dragging:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
		is_dragging = false
		$Area3D.input_ray_pickable = true
		_check_field_drop()

func _process(delta):
	if is_dragging:
		if Input.is_action_just_pressed("ui_cancel"):
			_cancel_dragging()
			return

		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		
		var project_plane = Plane(Vector3.UP, 0.1)
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		
		var intersect_point = project_plane.intersects_ray(ray_origin, ray_dir)
		if intersect_point:
			global_position = global_position.lerp(intersect_point + Vector3(0, 0.2, 0), 25 * delta)
			global_rotation = Vector3(deg_to_rad(-90), 0, 0)

func _cancel_dragging():
	is_dragging = false
	$Area3D.input_ray_pickable = true
	is_hovered = false
	
	if main_game and main_game.has_method("activate_field_drop_zone"):
		main_game.activate_field_drop_zone(false)
	
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
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
			if main_game and main_game.has_method("activate_field_drop_zone"):
				main_game.activate_field_drop_zone(false)
			return
			
	_cancel_dragging()

func _on_mouse_entered():
	if is_on_board or is_dragging or card_info == null or get_parent() == get_node("/root/MainGame"):
		return
	is_hovered = true
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		manager.hovered_card_index = get_index()
		manager.arrange_hand()

func _on_mouse_exited():
	if is_on_board or !is_hovered or is_dragging:
		return
	is_hovered = false
	if preview_panel:
		preview_panel.visible = false
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		if manager.hovered_card_index == get_index():
			manager.hovered_card_index = -1
			manager.arrange_hand()

func load_card_data():
	var template = $MeshInstance3D/SubViewport/PieTemplate
	
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
	else:
		template.get_node("Label").visible = true
		template.get_node("RichTextLabel").visible = true
		template.get_node("Label3").visible = true
		template.get_node("NameHP").visible = true
		
		var art_rect = template.get_node("TextureRect")
		art_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		if card_info.card_art != null:
			art_rect.texture = card_info.card_art
			
		template.get_node("Label").text = card_info.card_type
		template.get_node("Label3").text = card_info.attribute
		
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
