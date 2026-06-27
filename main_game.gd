extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
@onready var camera_3d: Camera3D = $Camera3D

@onready var ghost_slots_container = $GhostSlotsContainer
@onready var ghost_slot_active = $GhostSlotsContainer/GhostSlot
@onready var ghost_slot_bench = [
	$GhostSlotsContainer/GhostSlot,
	$GhostSlotsContainer/GhostSlot2,
	$GhostSlotsContainer/GhostSlot3,
]

# --- BOARD SLOT ANCHORS ---
@onready var active_slot_marker = $BoardSlots/ActiveSlot
@onready var bench_markers = [
	$BoardSlots/BenchSlot1,
	$BoardSlots/BenchSlot2,
	$BoardSlots/BenchSlot3
]

# --- DISCARD PILE ---
@onready var discard_pile_marker = $DiscardPileMarker

# --- UI NODES ---
@onready var actions_label = $UI/HUD/ActionsLabel
@onready var hand_count_label = $UI/HUD/HandCountLabel
@onready var end_turn_button = $UI/HUD/EndTurnButton
@onready var preview_panel = $UI/CardPreviewPanel

# --- NEW DISCARD PHASE UI HOOKUPS ---
@onready var discard_overlay = $UI/DiscardOverlay
@onready var confirm_discard_button = $UI/ConfirmDiscardButton

var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null]

# Inside main_game.gd near your other array trackers:
var discard_graveyard_pool: Array[Node3D] = []

# --- GAMEPLAY SYSTEMS ---
var max_hand_size: int = 7
var current_energy: int = 3 : 
	set(value):
		current_energy = value
		update_hud_display()

# Place this at the top of main_game.gd with your other global variables!
var is_dragging_pie: bool = false
var current_hovered_ghost_slot: Area3D = null

# --- NEW STATE TRACKERS ---
var is_discard_phase: bool = false
var marked_for_discard: Array[Node3D] = []

func _ready():
	get_viewport().physics_object_picking = true
	deck_3d.deck_clicked.connect(_on_deck_clicked)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	if confirm_discard_button:
		confirm_discard_button.pressed.connect(_on_confirm_discard_pressed)
		
	if discard_overlay:
		discard_overlay.visible = false
		
	activate_field_drop_zone(false)
	
	# FIX: Start the match with the new turn logic to grant the free card!
	start_new_turn()
	
	# Hide all ghost slots at game start
	if has_node("GhostSlotsContainer"):
		for slot in $GhostSlotsContainer.get_children():
			slot.visible = false

func update_hud_display():
	if actions_label:
		actions_label.text = str(current_energy) + "/3 actions left"
	if hand_count_label and card_manager:
		hand_count_label.text = str(card_manager.get_child_count()) + "/7"

func _on_deck_clicked():
	if is_discard_phase: return # Block drawing while forced to discard!
	
	var draw_cost = 1
	if current_energy < draw_cost:
		print("Not enough actions left to draw!")
		return
		
	if card_pool.is_empty(): return
		
	current_energy -= draw_cost
	var random_data = card_pool.pick_random()
	var new_card = card_manager.card_scene.instantiate()
	new_card.card_info = random_data
	
	if new_card.has_node("Area3D"):
		new_card.get_node("Area3D").input_ray_pickable = false
	
	add_child(new_card)
	new_card.global_position = deck_3d.global_position + Vector3(0, 0.2, 0)
	new_card.global_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	var fly_past_target = deck_3d.global_position + Vector3(0, 0.2, 2.5)
	var fly_tween = create_tween().set_parallel(true)
	fly_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	fly_tween.tween_property(new_card, "global_position", fly_past_target, 0.1)
	fly_tween.tween_property(new_card, "global_rotation", Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0), 0.3)
	
	fly_tween.chain().tween_callback(_add_to_hand_seamlessly.bind(new_card))
	
func _add_to_hand_seamlessly(card_node: Node3D):
	card_node.get_parent().remove_child(card_node)
	card_manager.add_child(card_node)
	card_node.rotation = Vector3.ZERO
	card_node.scale = Vector3(0.75, 0.75, 0.75)
	
	card_manager.arrange_hand()
	update_hud_display()
	
	var collision_timer = create_tween()
	collision_timer.tween_interval(0.15)
	collision_timer.tween_callback(func():
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
	)

func try_place_pie_on_field(card_node: Node3D):
	if is_discard_phase: return
	
	var play_cost = 1
	if current_energy < play_cost:
		if card_node.has_method("_cancel_dragging"): card_node._cancel_dragging()
		return

	var is_pie = card_node.card_info and card_node.card_info.card_type.to_lower() == "pie"
	var target_global_position: Vector3 = Vector3.ZERO
	var placement_successful: bool = false
	
	# --- 1. NON-PIE CARDS FLOW ---
	if not is_pie:
		# Spells and items immediately clear for deployment directly to the graveyard!
		target_global_position = discard_pile_marker.global_position
		placement_successful = true
		
	# --- 2. PIE CARDS FLOW ---
	else: # is_pie
		# Raycast at drop position to find which ghost slot was targeted
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
		var space_state = get_world_3d().direct_space_state
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collide_with_areas = true
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit = result.collider
			# Check if we hit a ghost slot's Area3D
			var slot_node = hit.get_parent() # GhostSlot Node3D is parent of Area3D
			if slot_node and slot_node.has_method("set_slot_highlight"):
				if slot_node.is_active_slot:
					if active_slot_card == null:
						active_slot_card = card_node
						target_global_position = active_slot_marker.global_position
						placement_successful = true
					else:
						print("Active slot occupied!")
				else:
					var idx = slot_node.slot_index
					if idx >= 0 and idx < bench_slot_cards.size():
						if bench_slot_cards[idx] == null:
							bench_slot_cards[idx] = card_node
							target_global_position = bench_markers[idx].global_position
							placement_successful = true
						else:
							print("Bench slot ", idx + 1, " occupied!")
			else:
				print("Dropped a Pie out of bounds!")
		else:
			print("Dropped a Pie out of bounds!")

	# --- 3. ANIMATION EXECUTION PHASE ---
	if placement_successful:
		current_energy -= play_cost
		card_node.is_on_board = true
		card_node.get_parent().remove_child(card_node)
		set_ghost_slots_visible(false, true)
		activate_field_drop_zone(false)
		add_child(card_node)

		var cam_forward = -camera_3d.global_transform.basis.z
		var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3
		var field_scale = Vector3(0.85, 0.85, 0.85)
		
		var tween = create_tween()
		var fly = tween.parallel()
		fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(card_node, "global_position", camera_front_pos, 0.1)
		fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.1)

		tween.chain().tween_interval(0)

		var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		var slam = tween.chain().parallel()
		slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slam.tween_property(card_node, "global_transform:basis", flat_basis, 0.22)
		slam.tween_property(card_node, "global_position", target_global_position + Vector3(0, 0.02, 0), 0.22)
		slam.tween_property(card_node, "scale", field_scale, 0.22)

		card_manager.arrange_hand()
		update_hud_display()

		tween.chain().tween_callback(func():
			card_node.is_on_board = true
			if not is_pie:
				discard_graveyard_pool.append(card_node)
				update_graveyard_mouse_priorities()
			else:
				if card_node.has_node("Area3D"):
					card_node.get_node("Area3D").input_ray_pickable = true
				if card_node.has_method("update_field_hp_display"):
					card_node.update_field_hp_display()
		)
	else:
		if card_node.has_method("_cancel_dragging"): card_node._cancel_dragging()
		
# --- REVISED END TURN BUTTON CLICKED ---
# Find your _on_end_turn_pressed() function and update it to this:
func _on_end_turn_pressed():
	var hand_count = card_manager.get_child_count()
	
	if hand_count > max_hand_size:
		print("Hand size exceeds limit! Entering Discard Phase.")
		is_discard_phase = true
		marked_for_discard.clear()
		if discard_overlay:
			discard_overlay.visible = true
		if confirm_discard_button:
			confirm_discard_button.visible = true
	else:
		# FIX: Proceed cleanly to next turn drawing sequence!
		start_new_turn()

# --- NEW SELECTION CHECKER FOR CARD_3D CLICKS ---
func toggle_card_discard_selection(card_node: Node3D):
	if not is_discard_phase: return
	
	if marked_for_discard.has(card_node):
		marked_for_discard.erase(card_node)
		if card_node.has_method("set_discard_highlight"):
			card_node.set_discard_highlight(false)
	else:
		marked_for_discard.append(card_node)
		if card_node.has_method("set_discard_highlight"):
			card_node.set_discard_highlight(true)

# --- NEW CONFIRM SELECTION BURNING ANIMATION ---
func _on_confirm_discard_pressed():
	var current_hand_count = card_manager.get_child_count()
	var final_calculated_count = current_hand_count - marked_for_discard.size()
	
	if final_calculated_count > max_hand_size:
		print("You still have too many cards! Must discard down to 7.")
		return
		
	print("Processing burning selection...")
	is_discard_phase = false
	
	# Hide BOTH the overlay and the button now!
	if discard_overlay:
		discard_overlay.visible = false
	if confirm_discard_button:
		confirm_discard_button.visible = false
		
	# Loop through our selection array and fly each one straight to the discard pile mesh!
	# Inside your _on_confirm_discard_pressed() function dead_card loop:
	# Update this loop block inside your _on_confirm_discard_pressed() function:
	for dead_card in marked_for_discard:
		if is_instance_valid(dead_card):
			if dead_card.has_method("set_discard_highlight"):
				dead_card.set_discard_highlight(false)
				
			dead_card.get_parent().remove_child(dead_card)
			add_child(dead_card)
			dead_card.is_on_board = true
			
			discard_graveyard_pool.append(dead_card)
			
			# FIX 1: Set a distinct +0.1 vertical lift per card in the stack!
			var height_offset = Vector3(0, 0.021 * discard_graveyard_pool.size(), 0)
			var target_destination = discard_pile_marker.global_position
			
			var burn_tween = create_tween().set_parallel(true)
			burn_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			
			var flat_layout = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
			var target_pile_scale = Vector3(0.85, 0.85, 0.85)
			
			burn_tween.tween_property(dead_card, "global_position", target_destination, 0.25)
			burn_tween.tween_property(dead_card, "global_transform:basis", flat_layout, 0.25)
			burn_tween.tween_property(dead_card, "scale", target_pile_scale, 0.25)
			
			# FIX 2: KEEP input pickable enabled so the mouse raycast can see it!
			if dead_card.has_node("Area3D"):
				dead_card.get_node("Area3D").input_ray_pickable = true
				
	# After adding the cards, update which card is allowed to be hovered
	update_graveyard_mouse_priorities()
	marked_for_discard.clear()
	
	card_manager.arrange_hand()
	
	# FIX: Proceed cleanly to the next turn after forced cleanup phase finishes!
	start_new_turn()

func activate_field_drop_zone(should_activate: bool):
	if has_node("FieldDropZone/CollisionShape3D"):
		$FieldDropZone/CollisionShape3D.disabled = !should_activate

# Add this new function anywhere in your main_game.gd script:
func start_new_turn():
	print("--- STARTING NEW TURN ---")
	# 1. Reset actions/energy pool back to 3
	current_energy = 3
	
	# 2. TRIGGER THE FREE DRAW:
	# We duplicate the card drawing block here, but we DO NOT deduct any energy points!
	if card_pool.is_empty():
		return
		
	var random_data = card_pool.pick_random()
	var new_card = card_manager.card_scene.instantiate()
	new_card.card_info = random_data
	
	if new_card.has_node("Area3D"):
		new_card.get_node("Area3D").input_ray_pickable = false
	
	add_child(new_card)
	new_card.global_position = deck_3d.global_position + Vector3(0, 0.2, 0)
	new_card.global_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	var fly_past_target = deck_3d.global_position + Vector3(0, 0.2, 2.5)
	var fly_tween = create_tween().set_parallel(true)
	fly_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	fly_tween.tween_property(new_card, "global_position", fly_past_target, 0.1)
	fly_tween.tween_property(new_card, "global_rotation", Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0), 0.3)
	
	# Clean, modern lambda format:
	fly_tween.chain().tween_callback(func(): _add_to_hand_seamlessly(new_card))

	# 3. Refresh HUD UI display counters
	update_hud_display()
	
	# ==========================================================
# 💀 BATTLEFIELD PIE DEATH REAPER LOGIC
# ==========================================================
func handle_pie_death(card_node: Node3D):
	print("Pie has fainted! Sweeping: ", card_node.card_info.card_name)
	
	if active_slot_card == card_node:
		active_slot_card = null
	else:
		for i in range(bench_slot_cards.size()):
			if bench_slot_cards[i] == card_node:
				bench_slot_cards[i] = null
				break
				
	if card_node.has_node("HPTracker"):
		card_node.get_node("HPTracker").visible = false
		
	# Add the card to the pool immediately
	discard_graveyard_pool.append(card_node)
	
	var death_tween = create_tween().set_parallel(true)
	death_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	var flat_layout = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	var target_pile_scale = Vector3(0.85, 0.85, 0.85)
	
	# Send it flat to the baseline destination marker
	death_tween.tween_property(card_node, "global_position", discard_pile_marker.global_position, 0.35)
	death_tween.tween_property(card_node, "global_transform:basis", flat_layout, 0.35)
	death_tween.tween_property(card_node, "scale", target_pile_scale, 0.35)
	
	# CRITICAL FIX: Wait for the tween flight to completely finish, THEN run priorities!
	death_tween.chain().tween_callback(func():
		update_graveyard_mouse_priorities()        # THEN reorder
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
	)
	
# --- CHANGE THIS FUNCTION NAME TO _input ---
func _input(event: InputEvent):
	# Test Damage: Pressing "ENTER" will hit your Active Pie for 20 damage!
	if event.is_action_pressed("ui_accept"): # UI_ACCEPT is the Enter/Return key
		if active_slot_card != null and active_slot_card.has_method("take_damage"):
			print("Debug: Attacking Active Pie for 20 damage!")
			active_slot_card.take_damage(20)
			
	# Test Healing: Pressing "H" will heal your Active Pie for 15 health!
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if active_slot_card != null and active_slot_card.has_method("heal_pie"):
			print("Debug: Healing Active Pie for 15 HP!")
			active_slot_card.heal_pie(15)

# ==========================================================
# 🔍 3D IN-GAME HOVER CARD INSPECTION SYSTEM
# ==========================================================
@onready var inspect_anchor = $Camera3D/InspectAnchor
var current_3d_preview: Node3D = null

func show_3d_card_preview(source_card_info: CardData):
	# If a preview is already showing, get rid of it first
	hide_3d_card_preview()
	
	if source_card_info == null or inspect_anchor == null:
		return
		
	# Instantiate a brand new duplicate of your 3D card scene
	var card_scene_path = load("res://card_3d.tscn") # Adjust path if yours is named differently!
	var preview_instance = card_scene_path.instantiate()
	
	# Assign the exact resource data so the art/text matches perfectly!
	preview_instance.card_info = source_card_info
	
	# Attach it right onto our camera's anchor point
	inspect_anchor.add_child(preview_instance)
	current_3d_preview = preview_instance
	
	# CRITICAL SAFETY: Turn off its collisions so it acts like a complete ghost!
	# This stops it from intercepting mouse clicks or breaking hand arrangements.
	if preview_instance.has_node("Area3D"):
		preview_instance.get_node("Area3D").input_ray_pickable = false
		
	# Force its on-field Nextbot HP display to remain invisible up close
	if preview_instance.has_node("HPTracker"):
		preview_instance.get_node("HPTracker").visible = false

func hide_3d_card_preview():
	if is_instance_valid(current_3d_preview):
		current_3d_preview.queue_free()
	current_3d_preview = null
	
func update_graveyard_mouse_priorities():
	if discard_graveyard_pool.is_empty():
		return
		
	var spacing = 0.005  # Very thin gap so cards don't z-fight but stay basically flat
	var top_index = discard_graveyard_pool.size() - 1
	
	for i in range(discard_graveyard_pool.size()):
		var card = discard_graveyard_pool[i]
		if not is_instance_valid(card):
			continue
			
		# Newest card (highest index) sits at the marker, older cards sink below
		var depth = top_index - i
		var target_pos = discard_pile_marker.global_position + Vector3(0, -spacing * depth, 0)
		
		var shift_tween = create_tween()
		shift_tween.tween_property(card, "global_position", target_pos, 0.2)
		
		# Only the top card gets mouse interaction
		if card.has_node("Area3D"):
			card.get_node("Area3D").input_ray_pickable = (i == top_index)

func set_ghost_slots_visible(should_show: bool, is_pie: bool):
	is_dragging_pie = (should_show and is_pie)
	var should_be_visible = (should_show and is_pie)
	
	if has_node("GhostSlotsContainer"):
		for slot in $GhostSlotsContainer.get_children():
			slot.visible = should_be_visible  # ← this must be here
			if slot.has_node("Area3D"):
				slot.get_node("Area3D").monitoring = should_be_visible
				slot.get_node("Area3D").monitorable = should_be_visible
	
	if not should_be_visible:
		current_hovered_ghost_slot = null
