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
	# 1. Grab references and wire up signals IMMEDIATELY so no inputs are dropped!
	main_game = get_node_or_null("/root/MainGame")
	
	if has_node("Area3D"):
		$Area3D.mouse_entered.connect(_on_mouse_entered)
		$Area3D.mouse_exited.connect(_on_mouse_exited)
		$Area3D.input_event.connect(_on_input_event)
		
	# 2. NOW wait a frame for resources/sub-viewports to cook
	await get_tree().process_frame
	
	# 3. Safely initialize your data structures
	if card_info != null:
		load_card_data()
		current_hp = card_info.max_hp
		
	if hp_tracker:
		hp_tracker.visible = false

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
	if current_hp <= 0:
		current_hp = 0
		update_field_hp_display()
		
		# --- TRIGGER CARD DEATH ROUTINE ---
		# Tell the main game to clean this card up off the board matrix!
		if main_game and main_game.has_method("handle_pie_death"):
			main_game.handle_pie_death(self)
	else:
		update_field_hp_display()

func _on_input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int):
	if is_on_board and event is InputEventMouseMotion:
		if main_game and main_game.get("is_discard_phase") == false:
			is_hovered = true
			_on_mouse_entered()

	if is_on_board and card_info and card_info.card_type.to_lower() != "pie":
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("CLICK DETECTED on: ", card_info.card_name, " | is_on_board: ", is_on_board)  # ADD THIS
		if main_game and main_game.get("is_discard_phase") == true:
			if not is_on_board: 
				main_game.toggle_card_discard_selection(self)
			return

		# Replace your old print statement with this:
		if is_on_board:
			if main_game and main_game.has_method("handle_field_pie_clicked"):
				main_game.handle_field_pie_clicked(self)
			return

		if main_game and main_game.has_node("Camera3D/CardManager"):
			for existing_card in main_game.get_node("Camera3D/CardManager").get_children():
				if existing_card.get("is_dragging") == true:
					print("BLOCKED: another card is dragging")  # ADD THIS
					return

		is_dragging = true
		print("DRAG STARTED")  # ADD THIS
		$Area3D.input_ray_pickable = false 

		var check_is_pie: bool = false
		if card_info and card_info.get("card_type") != null:
			if card_info.card_type.to_lower() == "pie":
				check_is_pie = true

		if main_game and main_game.has_method("set_ghost_slots_visible"):
			main_game.set_ghost_slots_visible(true, check_is_pie)
			
		# Always activate the drop zone so non-pie cards can still be placed
		if main_game and main_game.has_method("activate_field_drop_zone"):
			main_game.activate_field_drop_zone(true)
			
		var manager = get_parent()
		if manager and manager.has_method("arrange_hand"):
			manager.hovered_card_index = -1
			manager.arrange_hand()

# --- NEW VISUAL RED HIGHLIGHT DISCARD FEEDBACK FUNCTION ---
func set_discard_highlight(should_highlight: bool):
	var template = $MeshInstance3D/SubViewport/PieTemplate
	if template:
		if should_highlight:
			# Tint the 2D template background red to act as a prominent selection highlight outline!
			template.modulate = Color(1.0, 0.4, 0.4, 1.0)
		else:
			# Reset texture back to standard white daylight clear illumination
			template.modulate = Color(1.0, 1.0, 1.0, 1.0)

# --- NEW VISUAL WHITE HIGHLIGHT FOR FIELD SELECTION ---
func set_selection_highlight(should_highlight: bool):
	var template = $MeshInstance3D/SubViewport/PieTemplate
	if template:
		if should_highlight:
			# Over-drive the color values to make it glow bright white!
			template.modulate = Color(2.0, 2.0, 2.0, 1.0) 
		else:
			template.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _input(event: InputEvent):
	if is_on_board or !is_dragging:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
		is_dragging = false
		$Area3D.input_ray_pickable = true
		
		var is_pie = card_info and card_info.card_type.to_lower() == "pie"
		
		if is_pie:
			# Hide ghost slots and place via current_hovered_ghost_slot
			if main_game and main_game.has_method("set_ghost_slots_visible"):
				main_game.set_ghost_slots_visible(false, true)
			if main_game and main_game.has_method("try_place_pie_on_field"):
				main_game.try_place_pie_on_field(self)
		else:
			# Non-pie: use the original FieldDropZone raycast
			_check_field_drop()

func _process(delta):
	if is_dragging:
		# --- 1. HANDLE DROP SELECTION ON MOUSE RELEASE ---
		# Input.is_action_just_released check catches when they let go of Left Click!
		# --- GHOST SLOT HIGHLIGHT WHILE DRAGGING ---
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		var result = space_state.intersect_ray(query)
		
		if main_game and main_game.get("is_dragging_pie"):
			var newly_hovered = null
			if result:
				var hit = result.collider
				var slot_node = hit.get_parent()
				if slot_node and slot_node.has_method("set_slot_highlight"):
					newly_hovered = slot_node
			
			# Update highlights — clear old, set new
			var prev = main_game.get("current_hovered_ghost_slot")
			if prev != newly_hovered:
				if prev and is_instance_valid(prev):
					prev.set_slot_highlight(false)
				if newly_hovered:
					newly_hovered.set_slot_highlight(true)
				main_game.current_hovered_ghost_slot = newly_hovered
				
		if Input.is_action_just_pressed("ui_cancel"):
			_cancel_dragging()
			return

		# --- 2. EXISTING MOVEMENT CODE ---
		var project_plane = Plane(Vector3.UP, 0.1)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		
		var intersect_point = project_plane.intersects_ray(ray_origin, ray_dir)
		if intersect_point:
			global_position = global_position.lerp(intersect_point + Vector3(0, 0.2, 0), 25 * delta)
			global_rotation = Vector3(deg_to_rad(-90), 0, 0)

func _cancel_dragging():
	is_dragging = false
	$Area3D.input_ray_pickable = true
	is_hovered = false
	
	if main_game and main_game.has_method("set_ghost_slots_visible"):
		main_game.set_ghost_slots_visible(false, true)
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
	
	# Build exclude list of all ghost slot Area3Ds so non-pie cards ignore them
	var exclude_rids: Array[RID] = []
	if main_game and main_game.has_node("GhostSlotsContainer"):
		for slot in main_game.get_node("GhostSlotsContainer").get_children():
			if slot.has_node("Area3D"):
				exclude_rids.append(slot.get_node("Area3D").get_rid())
	query.exclude = exclude_rids
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.name == "FieldDropZone":
		if main_game and main_game.has_method("try_place_pie_on_field"):
			main_game.try_place_pie_on_field(self)
			if main_game and main_game.has_method("activate_field_drop_zone"):
				main_game.activate_field_drop_zone(false)
			return
			
	_cancel_dragging()

func _on_mouse_entered():
	# --- BLOCK DURING DRAG OR PLACEMENT ANIMATION ---
	# If the card is being dragged, or it's flying to the board, don't show the preview!
	if is_dragging or card_info == null:
		return
		
	is_hovered = true
	
	# --- BATTLEFIELD HOVER INSPECTION OVERLAY ---
	if is_on_board:
		# EXTRA CHECK: If the card is still animating down to the table, abort!
		# This ensures it doesn't pop up until the card is fully resting on the board.
		if main_game and main_game.has_method("show_3d_card_preview"):
			main_game.show_3d_card_preview(card_info)
		return
		
	# --- Standard hand layout hovering alignment ---
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		manager.hovered_card_index = get_index()
		manager.arrange_hand()

func _on_mouse_exited():
	if !is_hovered or is_dragging:
		return
		
	is_hovered = false
	
	# --- BATTLEFIELD LEAVE TRIGGER (NEW 3D REMOVAL) ---
	if is_on_board:
		if main_game and main_game.has_method("hide_3d_card_preview"):
			main_game.hide_3d_card_preview()
		return # Stop here so it doesn't look for the Hand Manager!
		
	# --- Hide the old inspection overlay panel if it was used anywhere else ---
	if preview_panel:
		preview_panel.visible = false
		
	# --- Standard hand layout leaving alignment (STAYS EXACTLY THE SAME) ---
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
