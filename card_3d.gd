extends Node3D

@onready var main_game = get_node("/root/MainGame")

@export var card_info: CardData
@onready var preview_panel = get_node("/root/MainGame/CanvasLayer/CardPreviewPanel")

# --- NEW HP FLOATING TRACKER NODE ---
@onready var hp_tracker = $HPTracker
var is_opponent: bool = false
var peak_hp: int = 0
var is_dragging: bool = false
var is_on_board: bool = false 
var default_position: Vector3
var is_hovered: bool = false

# Track the actual dynamic current health of this specific card instance
var current_hp: int = 0

func _ready():
	main_game = get_node_or_null("/root/MainGame")
	
	if has_node("Area3D"):
		$Area3D.mouse_entered.connect(_on_mouse_entered)
		$Area3D.mouse_exited.connect(_on_mouse_exited)
		$Area3D.input_event.connect(_on_input_event)
		
	await get_tree().process_frame
	
	if card_info != null:
		# FIX: Set the HP values FIRST!
		current_hp = card_info.max_hp
		peak_hp = current_hp 
		
		# THEN build the card visuals so it uses the real HP!
		load_card_data() 
		
	if hp_tracker:
		hp_tracker.visible = false

# --- NEW FUNCTION TO UPDATE AND DISPLAY HEALTH ---
# --- UPDATE LIVE HP FUNCTION ---
func update_field_hp_display():
	# 1. Update floating 3D tracker & toggle visibility (Fixes Issue #1)
	if hp_tracker and card_info != null:
		if card_info.card_type.to_lower() == "pie":
			hp_tracker.text = str(current_hp)
			hp_tracker.visible = is_on_board # Only show if it's placed on the battlefield!
		else:
			hp_tracker.visible = false
			
	# 2. Update the 2D label directly on the new card face
	var live_hp_label = $MeshInstance3D/SubViewport/PieTemplate/LiveHPLabel
	if live_hp_label != null:
		live_hp_label.text = "HP: " + str(current_hp)
# --- NEW FUNCTION TO HANDLE HEALING / DAMAGE OVER TIME ---

func heal_pie(amount: int):
	current_hp += amount
	# Update Peak HP if we healed over our previous maximum!
	if current_hp > peak_hp:
		peak_hp = current_hp
	update_field_hp_display()

func take_damage(amount: int):
	current_hp -= amount
	# --- ADD THIS LINE HERE ---
	spawn_damage_number(amount)
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

func set_selection_highlight(should_highlight: bool):
	var outline = $MeshInstance3D/SubViewport/PieTemplate/SelectionOutline
	if outline:
		outline.visible = should_highlight

# --- NEW VISUAL WHITE HIGHLIGHT FOR FIELD SELECTION ---
#func set_selection_highlight(should_highlight: bool):
	#var template = $MeshInstance3D/SubViewport/PieTemplate
	#if template:
		#if should_highlight:
			# Over-drive the color values to make it glow bright white!
			#template.modulate = Color(2.0, 2.0, 2.0, 1.0) 
		#else:
			#template.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
	if card_info == null: return
	
	var template = $MeshInstance3D/SubViewport/PieTemplate
	if template == null: return
	
	# --- Fix #3: Update the Top-Left Card Type Label ---
	if template.has_node("Label"):
		template.get_node("Label").text = card_info.card_type
		
	# --- Fix #4: Hide text overlays for Full-Art cards ---
	var is_full_art = not card_info.is_half_art
	
	if template.has_node("NameHP"): template.get_node("NameHP").visible = not is_full_art
	if template.has_node("LiveHPLabel"): template.get_node("LiveHPLabel").visible = not is_full_art
	if template.has_node("VBoxContainer"): template.get_node("VBoxContainer").visible = not is_full_art
	if template.has_node("Label"): template.get_node("Label").visible = not is_full_art
	if template.has_node("Label3"): template.get_node("Label3").visible = not is_full_art
	
	# --- 1. HANDLE CARD ARTWORK & CROPPING ---
	var art_rect = template.get_node_or_null("TextureRect")
	if art_rect and card_info.card_art != null:
		art_rect.texture = card_info.card_art
		
		if card_info.is_half_art:
			# Crop to the top half of the card
			art_rect.size = Vector2(350, 250) 
			art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			# Full art takes up the whole card
			art_rect.position = Vector2(0, 0)
			art_rect.size = Vector2(350, 500)
			art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			
	# --- 2. POPULATE THE PIE DATA (Only if Half-Art) ---
	if card_info.card_type.to_lower() == "pie" and card_info.is_half_art:
		
		# Fix #2: NameHP gets ONLY the name!
		if template.has_node("NameHP"):
			template.get_node("NameHP").text = card_info.card_name
			
		# Bottom Right Label gets the Size
		if template.has_node("Label3"):
			if card_info.pie_size != "":
				template.get_node("Label3").text = card_info.pie_size
			else:
				template.get_node("Label3").text = card_info.attribute
			
		# Live HP setup
		if template.has_node("LiveHPLabel"):
			template.get_node("LiveHPLabel").text = "HP: " + str(current_hp)
			
		# Populate Passive
		if template.has_node("VBoxContainer/PassiveText"):
			var passive = template.get_node("VBoxContainer/PassiveText")
			if card_info.passive_desc != "":
				passive.text = "[b]Passive:[/b] " + card_info.passive_desc
				passive.visible = true
			else:
				passive.visible = false
				
		# --- POPULATE MOVE 1 ---
		var move1_panel = template.get_node_or_null("VBoxContainer/Move1Panel")
		if move1_panel:
			var m1_name = move1_panel.get_node_or_null("MoveVBox/MoveHeader/MoveName")
			var m1_dmg = move1_panel.get_node_or_null("MoveVBox/MoveHeader/MoveDmg")
			var m1_desc = move1_panel.get_node_or_null("MoveVBox/MoveDesc")
			
			if card_info.move1_name != "" or card_info.move1_dmg != "":
				move1_panel.visible = true
				
				# 1. Start with Underline [u] and Bold [b]
				var formatted_name = "[u][b]"
				
				# 2. Add [E] to the front if equippable
				if card_info.move1_is_equippable: formatted_name += "[E] "
				
				# 3. Add the actual name and close the underline/bold tags
				formatted_name += card_info.move1_name + "[/b][/u]"
				
				# 4. Add [CD] to the back if it has a cooldown
				if card_info.move1_has_cooldown: formatted_name += " [CD]"
				
				if m1_name: m1_name.text = formatted_name
				if m1_dmg: m1_dmg.text = "[right][b]" + card_info.move1_dmg + "[/b][/right]"
				if m1_desc: m1_desc.text = card_info.move1_desc
			else:
				move1_panel.visible = false
				
		# --- POPULATE MOVE 2 ---
		var move2_panel = template.get_node_or_null("VBoxContainer/Move2Panel")
		if move2_panel:
			var m2_name = move2_panel.get_node_or_null("MoveVBox/MoveHeader/MoveName")
			var m2_dmg = move2_panel.get_node_or_null("MoveVBox/MoveHeader/MoveDmg")
			var m2_desc = move2_panel.get_node_or_null("MoveVBox/MoveDesc")
			
			if card_info.move2_name != "" or card_info.move2_dmg != "":
				move2_panel.visible = true
				
				var formatted_name = "[u][b]"
				if card_info.move2_is_equippable: formatted_name += "[E] "
				formatted_name += card_info.move2_name + "[/b][/u]"
				if card_info.move2_has_cooldown: formatted_name += " [CD]"
				
				if m2_name: m2_name.text = formatted_name
				if m2_dmg: m2_dmg.text = "[right][b]" + card_info.move2_dmg + "[/b][/right]"
				if m2_desc: m2_desc.text = card_info.move2_desc
			else:
				move2_panel.visible = false

func spawn_damage_number(amount: int):
	var dmg_label = Label3D.new()
	dmg_label.text = "-" + str(amount)
	
	# Style the text: Bright red with a thick black outline
	dmg_label.modulate = Color(1.0, 0.2, 0.2) 
	dmg_label.outline_modulate = Color.BLACK
	dmg_label.outline_size = 12
	dmg_label.font_size = 50 # Make it huge so it's readable in 3D
	
	# Magic Setting: Forces the text to ALWAYS face the camera!
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
	
	# FIX 1: Tell the label to completely ignore the card's rotation and scale
	dmg_label.top_level = true
	
	# Attach it to the card
	add_child(dmg_label)
	
	# FIX 2: Use global_position so it spawns perfectly above the card in world space
	dmg_label.global_position = self.global_position + Vector3(0, 0.2, 0)
	
	# Animate it floating straight up toward the ceiling and fading out over 1.2 seconds
	var tween = create_tween().set_parallel(true)
	
	# FIX 3: Tween the global_position so it travels strictly upward
	var float_target = dmg_label.global_position + Vector3(0, 0.5, 0)
	tween.tween_property(dmg_label, "global_position", float_target, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	
	# Delete the text node automatically when the fade finishes
	tween.chain().tween_callback(dmg_label.queue_free)
