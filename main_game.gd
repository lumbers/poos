extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
@onready var camera_3d: Camera3D = $Camera3D

@onready var switch_button = $UI/SwitchButton
@onready var free_move_up_button = $UI/FreeMoveUpButton
@onready var cancel_button = $UI/CancelButton

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

# Add this at the top of main_game.gd with your other @onready variables
@onready var field_drop_mesh = $FieldDropZone/MeshInstance3D # Make sure this matches your scene tree path!

# --- DISCARD PILE ---
@onready var discard_pile_marker = $DiscardPileMarker

# --- UI NODES ---
@onready var actions_label = $UI/HUD/ActionsLabel
@onready var hand_count_label = $UI/HUD/HandCountLabel
@onready var end_turn_button = $UI/HUD/EndTurnButton
@onready var preview_panel = $UI/CardPreviewPanel

@onready var discard_title = $UI/DiscardOverlay/DiscardTitle
@onready var discard_counter = $UI/DiscardOverlay/DiscardCounter

@onready var player_lp_label = $UI/HUD/PlayerLPLabel
@onready var opponent_lp_label = $UI/HUD/OpponentLPLabel
@onready var attack_button = $UI/AttackButton
@onready var opponent_active_marker = $BoardSlots/OpponentActiveSlot

# --- NEW FIELD SELECTION TRACKERS ---
var selected_field_pie: Node3D = null
var target_field_pie: Node3D = null
var target_ghost_slot: Node3D = null

# --- NEW DISCARD PHASE UI HOOKUPS ---
@onready var discard_overlay = $UI/DiscardOverlay
@onready var confirm_discard_button = $UI/ConfirmDiscardButton

@onready var attack_overlay = $AttackOverlay
@onready var move1_button = $AttackOverlay/Control/VBoxContainer/Move1Button
@onready var move2_button = $AttackOverlay/Control/VBoxContainer/Move2Button

var original_camera_pos: Vector3
var original_camera_rot: Vector3
var is_in_attack_phase: bool = false

# --- ADD THESE NEAR YOUR OTHER MARKERS AND POOLS ---
@onready var opponent_discard_pile_marker = $BoardSlots/OpponentDiscardPileMarker
var opponent_graveyard_pool: Array[Node3D] = []

var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null]

# --- ADD THESE NEW LP & OPPONENT TRACKERS ---
var player_lp: int = 1500
var opponent_lp: int = 1500
var opponent_active_card: Node3D = null

# Inside main_game.gd near your other array trackers:
var discard_graveyard_pool: Array[Node3D] = []

# --- GAMEPLAY SYSTEMS ---
var max_hand_size: int = 7
var current_energy: int = 3 : 
	set(value):
		current_energy = value
		update_hud_display()

var has_attacked_this_turn: bool = false # <--- ADD THIS NEW TRACKER

# Place this at the top of main_game.gd with your other global variables!
var is_dragging_pie: bool = false
var current_hovered_ghost_slot: Area3D = null

# --- NEW STATE TRACKERS ---
var is_discard_phase: bool = false
var marked_for_discard: Array[Node3D] = []

# --- NEW DISCARD & SWITCHING STATES ---
enum DiscardMode { NONE, HAND_LIMIT, SWITCHING }
var current_discard_mode: DiscardMode = DiscardMode.NONE

var is_rearranging_field: bool = false
var is_free_move_active: bool = false

func _ready():
	# Add these near the top of _ready()
	original_camera_pos = camera_3d.global_position
	original_camera_rot = camera_3d.rotation
	
	if attack_overlay: attack_overlay.visible = false
	get_viewport().physics_object_picking = true
	
	# --- 1. SAFELY CONNECT ALL BUTTONS & SIGNALS ---
	if deck_3d and not deck_3d.deck_clicked.is_connected(_on_deck_clicked):
		deck_3d.deck_clicked.connect(_on_deck_clicked)
		
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		
	# FIX: Re-connected your Confirm Discard button!
	if confirm_discard_button and not confirm_discard_button.pressed.is_connected(_on_confirm_discard_pressed):
		confirm_discard_button.pressed.connect(_on_confirm_discard_pressed)
		
	# FIX: Removed the duplicate Attack button connections!
	if attack_button and not attack_button.pressed.is_connected(execute_basic_attack):
		attack_button.pressed.connect(execute_basic_attack)
		
	if switch_button and not switch_button.pressed.is_connected(initiate_paid_switch):
		switch_button.pressed.connect(initiate_paid_switch)
		
	if free_move_up_button and not free_move_up_button.pressed.is_connected(execute_free_move_up):
		free_move_up_button.pressed.connect(execute_free_move_up)
		
	if cancel_button and not cancel_button.pressed.is_connected(cancel_switching_discard):
		cancel_button.pressed.connect(cancel_switching_discard)
		
	# --- 2. INITIALIZE CLEAN UI VISIBILITY ---
	if discard_overlay: discard_overlay.visible = false
	if attack_button: attack_button.visible = false
	if switch_button: switch_button.visible = false
	if free_move_up_button: free_move_up_button.visible = false
	if cancel_button: cancel_button.visible = false
	if is_instance_valid(field_drop_mesh): field_drop_mesh.visible = false
	
	if has_node("GhostSlotsContainer"):
		for slot in $GhostSlotsContainer.get_children():
			slot.visible = false
			
	# --- 3. START THE MATCH (Exactly Once!) ---
	activate_field_drop_zone(false)
	start_new_turn()
	spawn_dummy_opponent()

func update_hud_display():
	if actions_label:
		actions_label.text = str(current_energy) + "/3 actions left"
	if hand_count_label and card_manager:
		hand_count_label.text = str(card_manager.get_child_count()) + "/7"
	# --- NEW LP DISPLAYS ---
	if player_lp_label:
		player_lp_label.text = "Player LP: " + str(player_lp)
	if opponent_lp_label:
		opponent_lp_label.text = "Enemy LP: " + str(opponent_lp)

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
	# --- FIX 1: IMMEDIATELY CANCEL ANY SWITCHING/SELECTION ---
	if current_discard_mode == DiscardMode.SWITCHING:
		cancel_switching_discard()
	clear_field_selection()
	
	var hand_count = card_manager.get_child_count()
	
	if hand_count > max_hand_size:
		print("Hand size exceeds limit! Entering Discard Phase.")
		is_discard_phase = true
		current_discard_mode = DiscardMode.HAND_LIMIT 
		marked_for_discard.clear()
		if discard_overlay:
			discard_overlay.visible = true
		if confirm_discard_button:
			confirm_discard_button.visible = true
		update_discard_ui_counters() # Make sure to update the text!
	else:
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
			
	update_discard_ui_counters()

# --- NEW CONFIRM SELECTION BURNING ANIMATION ---
func _on_confirm_discard_pressed():
	# --- 1. ENFORCE RULES BASED ON CURRENT MODE ---
	if current_discard_mode == DiscardMode.HAND_LIMIT:
		var current_hand_count = card_manager.get_child_count()
		var final_calculated_count = current_hand_count - marked_for_discard.size()
		if final_calculated_count > max_hand_size:
			print("You still have too many cards! Must discard down to 7.")
			return
			
	elif current_discard_mode == DiscardMode.SWITCHING:
		if marked_for_discard.size() != 2:
			print("You MUST discard exactly 2 cards to switch!")
			return
		# Successfully paid! Deduct 1 energy.
		current_energy -= 1 

	print("Processing burning selection...")
	var finished_mode = current_discard_mode # Save the mode so we know what to do at the end
	
	is_discard_phase = false
	current_discard_mode = DiscardMode.NONE
	
	if discard_overlay:
		discard_overlay.visible = false
	if confirm_discard_button:
		confirm_discard_button.visible = false
		
	# --- 2. FLY CARDS TO DISCARD PILE ---
	for dead_card in marked_for_discard:
		if is_instance_valid(dead_card):
			if dead_card.has_method("set_discard_highlight"):
				dead_card.set_discard_highlight(false)
				
			dead_card.get_parent().remove_child(dead_card)
			add_child(dead_card)
			dead_card.is_on_board = true
			
			discard_graveyard_pool.append(dead_card)
			
			var height_offset = Vector3(0, 0.021 * discard_graveyard_pool.size(), 0)
			var target_destination = discard_pile_marker.global_position
			
			var burn_tween = create_tween().set_parallel(true)
			burn_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			
			var flat_layout = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
			var target_pile_scale = Vector3(0.85, 0.85, 0.85)
			
			burn_tween.tween_property(dead_card, "global_position", target_destination, 0.25)
			burn_tween.tween_property(dead_card, "global_transform:basis", flat_layout, 0.25)
			burn_tween.tween_property(dead_card, "scale", target_pile_scale, 0.25)
			
			if dead_card.has_node("Area3D"):
				dead_card.get_node("Area3D").input_ray_pickable = true
				
	update_graveyard_mouse_priorities()
	marked_for_discard.clear()
	card_manager.arrange_hand()
	
	# --- 3. ROUTE THE GAME STATE ---
	if finished_mode == DiscardMode.HAND_LIMIT:
		start_new_turn()
	elif finished_mode == DiscardMode.SWITCHING:
		# FIRE THE SWAP ANIMATION HERE!
		execute_paid_switch()

func activate_field_drop_zone(should_activate: bool):
	if has_node("FieldDropZone/CollisionShape3D"):
		$FieldDropZone/CollisionShape3D.disabled = !should_activate

# Add this new function anywhere in your main_game.gd script:
func start_new_turn():
	print("--- STARTING NEW TURN ---")
	current_energy = 3
	has_attacked_this_turn = false # <--- RESET THE ATTACK LOCKOUT HERE
	
	# --- 1. HARD RESET ALL SELECTION STATES ---
	is_discard_phase = false
	current_discard_mode = DiscardMode.NONE
	clear_field_selection() # Forces the UI and highlights to reset!
	
	# --- 2. PROTECTED DUMMY RESPAWN ---
	# This ensures a new dummy ONLY spawns if the old one was actually killed!
	if opponent_active_card == null:
		spawn_dummy_opponent()
	
	# --- 3. THE FREE DRAW (Keep your existing draw code here!) ---
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
	
	# FIX: Instantly hide the HP tracker so a "0" doesn't float into the graveyard
	if card_node.has_node("HPTracker"):
		card_node.get_node("HPTracker").visible = false
	
	var penalty = card_node.get("peak_hp")
	if penalty == null: penalty = 0
	
	var is_enemy = card_node.get("is_opponent") == true
	var target_destination: Vector3
	var flat_layout = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	var target_pile_scale = Vector3(0.85, 0.85, 0.85)
	
	if is_enemy:
		opponent_lp -= penalty
		opponent_active_card = null
		opponent_graveyard_pool.append(card_node)
		if opponent_discard_pile_marker:
			target_destination = opponent_discard_pile_marker.global_position
		print("Opponent loses ", penalty, " LP! Remaining: ", opponent_lp)
	else:
		player_lp -= penalty
		discard_graveyard_pool.append(card_node)
		target_destination = discard_pile_marker.global_position
		print("Player loses ", penalty, " LP! Remaining: ", player_lp)
		
		# Clear slot references for player
		if active_slot_card == card_node:
			active_slot_card = null
		else:
			for i in range(bench_slot_cards.size()):
				if bench_slot_cards[i] == card_node:
					bench_slot_cards[i] = null
					break
					
	update_hud_display()
	
	var death_tween = create_tween().set_parallel(true)
	death_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	death_tween.tween_property(card_node, "global_position", target_destination, 0.35)
	death_tween.tween_property(card_node, "global_transform:basis", flat_layout, 0.35)
	death_tween.tween_property(card_node, "scale", target_pile_scale, 0.35)
	
	death_tween.chain().tween_callback(func():
		if not is_enemy:
			update_graveyard_mouse_priorities()
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
	
	# QoL FIX: The pink mat ONLY appears for non-pies! Pies stay completely clean!
	if is_instance_valid(field_drop_mesh):
		field_drop_mesh.visible = (should_show and not is_pie)
	
	if has_node("GhostSlotsContainer"):
		for slot in $GhostSlotsContainer.get_children():
			slot.visible = should_be_visible
			if slot.has_node("Area3D"):
				slot.get_node("Area3D").monitoring = should_be_visible
				slot.get_node("Area3D").monitorable = should_be_visible
	
	if not should_be_visible:
		current_hovered_ghost_slot = null

func initiate_paid_switch():
	if current_energy < 1:
		print("Not enough energy to switch!")
		# Trigger the spammable floating text right over the Switch button!
		if switch_button:
			spawn_floating_error_text("You have no more actions left!", switch_button.global_position)
		return
		
	if card_manager.get_child_count() < 2:
		print("You need at least 2 cards in your hand to pay for a switch!")
		# You can also add another text spawn here for "Not enough cards!" if you want!
		return
		
	is_discard_phase = true
	current_discard_mode = DiscardMode.SWITCHING
	marked_for_discard.clear()
	
	if switch_button: switch_button.visible = false
	if discard_overlay: discard_overlay.visible = true
	if confirm_discard_button: confirm_discard_button.visible = true
	update_discard_ui_counters()

func _unhandled_input(event: InputEvent):
	# ui_cancel is the default Godot action for the Escape key
	if event.is_action_pressed("ui_cancel"): 
		if is_discard_phase and current_discard_mode == DiscardMode.SWITCHING:
			cancel_switching_discard()

func cancel_switching_discard():
	print("Action cancelled!")
	is_discard_phase = false
	current_discard_mode = DiscardMode.NONE
	
	for card in marked_for_discard:
		if is_instance_valid(card) and card.has_method("set_discard_highlight"):
			card.set_discard_highlight(false)
	marked_for_discard.clear()
	
	if discard_overlay: discard_overlay.visible = false
	if confirm_discard_button: confirm_discard_button.visible = false
	
	# QoL FIX: Hitting escape/cancel purges the entire board layout state!
	clear_field_selection()
	
# ==========================================================
# 🔄 FIELD SWITCHING & MOVEMENT LOGIC
# ==========================================================

func handle_field_pie_clicked(pie: Node3D):
	if is_discard_phase: return
	
	# FIX: Completely ignore clicks on the opponent's cards!
	if pie.get("is_opponent") == true:
		print("You cannot select the opponent's cards!")
		return
	
	# 1. DESELECTING THE PRIMARY CARD
	if selected_field_pie == pie:
		pie.set_selection_highlight(false)
		if target_field_pie != null:
			selected_field_pie = target_field_pie
			target_field_pie = null
			target_ghost_slot = null
			evaluate_switch_validity()
		else:
			clear_field_selection()
		return
		
	# 2. DESELECTING THE TARGET CARD
	if target_field_pie == pie:
		pie.set_selection_highlight(false)
		target_field_pie = null
		evaluate_switch_validity()
		return
		
	# 3. SELECTING THE FIRST CARD
	if selected_field_pie == null:
		selected_field_pie = pie
		pie.set_selection_highlight(true)
		set_ghost_slots_visible(true, true) 
		
		# FIX: Removed the isolated button logic here. 
		# We just call the evaluator to handle all UI perfectly!
		evaluate_switch_validity()
		
	# 4. SELECTING A NEW TARGET CARD
	else:
		if target_field_pie != null:
			target_field_pie.set_selection_highlight(false)
		target_field_pie = pie
		target_ghost_slot = null
		pie.set_selection_highlight(true)
		evaluate_switch_validity()

func handle_ghost_slot_clicked(slot: Node3D):
	if selected_field_pie != null:
		
		# --- NEW: IS THERE A PIE SITTING IN THIS GHOST SLOT? ---
		var occupied_pie = null
		if slot.is_active_slot and active_slot_card != null:
			occupied_pie = active_slot_card
		elif not slot.is_active_slot and bench_slot_cards[slot.slot_index] != null:
			occupied_pie = bench_slot_cards[slot.slot_index]
			
		# FIX: Removed the restriction! If a pie is here, pass the click straight to it!
		if occupied_pie != null:
			handle_field_pie_clicked(occupied_pie)
			return
			
		# Otherwise, standard empty slot logic
		target_ghost_slot = slot
		if target_field_pie != null:
			target_field_pie.set_selection_highlight(false)
			target_field_pie = null
		evaluate_switch_validity()

func evaluate_switch_validity():
	# 1. Hide everything by default
	if switch_button: switch_button.visible = false
	if free_move_up_button: free_move_up_button.visible = false
	if attack_button: attack_button.visible = false
	if cancel_button: cancel_button.visible = true 
	
	# 2. RULE: FREE MOVE UP
	# Trigger: Active slot is empty, Bench pie is selected, NO target is selected.
	if active_slot_card == null and selected_field_pie != null and bench_slot_cards.has(selected_field_pie) and target_field_pie == null and target_ghost_slot == null:
		if free_move_up_button: free_move_up_button.visible = true
		return # Stop checking! We don't want other buttons fighting this.
		
	# 3. RULE: ATTACK
	# Trigger: Active pie is selected, NO target is selected, Opponent exists.
	if active_slot_card != null and selected_field_pie == active_slot_card and target_field_pie == null and target_ghost_slot == null:
		if opponent_active_card != null:
			if attack_button: attack_button.visible = true
		return # Stop checking!
		
	# 4. RULE: SWITCH
	# Trigger: A primary pie AND a target (pie or ghost) are selected.
	if target_field_pie != null or target_ghost_slot != null:
		var is_start_active = (selected_field_pie == active_slot_card)
		var is_target_active = false
		
		if target_field_pie != null:
			is_target_active = (target_field_pie == active_slot_card)
		elif target_ghost_slot != null:
			is_target_active = target_ghost_slot.is_active_slot
			
		# Exactly one selected slot must be the active slot
		if (is_start_active and not is_target_active) or (not is_start_active and is_target_active):
			if switch_button: switch_button.visible = true

func clear_field_selection():
	if selected_field_pie: selected_field_pie.set_selection_highlight(false)
	if target_field_pie: target_field_pie.set_selection_highlight(false)
	
	selected_field_pie = null
	target_field_pie = null
	target_ghost_slot = null
	
	if switch_button: switch_button.visible = false
	if free_move_up_button: free_move_up_button.visible = false
	if attack_button: attack_button.visible = false
	if cancel_button: cancel_button.visible = false
	
	set_ghost_slots_visible(false, true)
	if is_instance_valid(field_drop_mesh): field_drop_mesh.visible = false
	
func execute_free_move_up():
	print("Executing Free Move to Active Slot!")
	if selected_field_pie != null:
		# Remove from bench array
		for i in range(bench_slot_cards.size()):
			if bench_slot_cards[i] == selected_field_pie:
				bench_slot_cards[i] = null
				break
		# Assign to active
		active_slot_card = selected_field_pie
		
		# Animate
		var tween = create_tween()
		tween.tween_property(selected_field_pie, "global_position", active_slot_marker.global_position + Vector3(0, 0.02, 0), 0.3)
		
	clear_field_selection()

# --- UPDATE DISCARD TEXT UI ---
func update_discard_ui_counters():
	# Get a reference to your old Hand Limit label (check this node path matches yours!)
	var old_hand_label = get_node_or_null("UI/DiscardOverlay/DiscardInstructionLabel")
	
	if current_discard_mode == DiscardMode.SWITCHING:
		if old_hand_label: old_hand_label.visible = false
		if discard_title: 
			discard_title.text = "Discard 2 cards to switch your pie"
			discard_title.visible = true
		if discard_counter: 
			discard_counter.text = str(marked_for_discard.size()) + " / 2"
			discard_counter.visible = true
			
	elif current_discard_mode == DiscardMode.HAND_LIMIT:
		if old_hand_label: old_hand_label.visible = true
		if discard_title: discard_title.visible = false
		if discard_counter: discard_counter.visible = false

func execute_paid_switch():
	print("Executing Paid Switch!")
	var pie1 = selected_field_pie
	
	# --- CASE A: SWAPPING TWO PIES ---
	if target_field_pie != null:
		var pie2 = target_field_pie
		var pie1_is_active = (pie1 == active_slot_card)
		
		# Find their bench positions (returns -1 if not on bench)
		var pie1_bench_idx = bench_slot_cards.find(pie1)
		var pie2_bench_idx = bench_slot_cards.find(pie2)
		
		# Update the tracking arrays
		if pie1_is_active:
			active_slot_card = pie2
			bench_slot_cards[pie2_bench_idx] = pie1
		else:
			active_slot_card = pie1
			bench_slot_cards[pie1_bench_idx] = pie2
			
		# Animate the swap
		var p1_target = active_slot_marker.global_position if not pie1_is_active else bench_markers[pie2_bench_idx].global_position
		var p2_target = active_slot_marker.global_position if pie1_is_active else bench_markers[pie1_bench_idx].global_position
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(pie1, "global_position", p1_target + Vector3(0, 0.02, 0), 0.3)
		tween.tween_property(pie2, "global_position", p2_target + Vector3(0, 0.02, 0), 0.3)

	# --- CASE B: MOVING ACTIVE PIE TO EMPTY BENCH ---
	elif target_ghost_slot != null:
		var pie1_is_active = (pie1 == active_slot_card)
		var pie1_bench_idx = bench_slot_cards.find(pie1)
		
		if target_ghost_slot.is_active_slot:
			bench_slot_cards[pie1_bench_idx] = null
			active_slot_card = pie1
			var tween = create_tween()
			tween.tween_property(pie1, "global_position", active_slot_marker.global_position + Vector3(0, 0.02, 0), 0.3)
		else:
			if pie1_is_active: active_slot_card = null
			else: bench_slot_cards[pie1_bench_idx] = null
			
			bench_slot_cards[target_ghost_slot.slot_index] = pie1
			var tween = create_tween()
			tween.tween_property(pie1, "global_position", bench_markers[target_ghost_slot.slot_index].global_position + Vector3(0, 0.02, 0), 0.3)

	# --- FIX 4: CLEAN UP ALL HIGHLIGHTS AND GHOST GRIDS ---
	clear_field_selection()
	set_ghost_slots_visible(false, true)

func spawn_dummy_opponent():
	if card_pool.is_empty() or opponent_active_marker == null: return
	
	# FIX: Filter the deck so we ONLY grab Pie cards!
	var possible_dummies = []
	for card_data in card_pool:
		if card_data.card_type.to_lower() == "pie":
			possible_dummies.append(card_data)
			
	if possible_dummies.is_empty():
		print("No pies in deck to use as dummy!")
		return
		
	var dummy_data = possible_dummies.pick_random() 
	var dummy_card = card_manager.card_scene.instantiate()
	
	dummy_card.card_info = dummy_data
	dummy_card.is_opponent = true # Tags it as enemy property
	add_child(dummy_card)
	
	dummy_card.load_card_data()
	
	dummy_card.global_position = opponent_active_marker.global_position
	dummy_card.global_transform.basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90))).rotated(Vector3.UP, deg_to_rad(180))
	dummy_card.scale = Vector3(0.85, 0.85, 0.85)
	
	dummy_card.is_on_board = true
	opponent_active_card = dummy_card
	
	await get_tree().process_frame
	if dummy_card.has_method("update_field_hp_display"):
		dummy_card.update_field_hp_display()

func execute_basic_attack():
	# 1. ENFORCE LIMITS
	if has_attacked_this_turn:
		if attack_button: spawn_floating_error_text("You can only attack once per turn!", attack_button.global_position)
		return
	if current_energy < 1:
		if attack_button: spawn_floating_error_text("You have no more actions left!", attack_button.global_position)
		return
	if active_slot_card == null:
		return
		
	# 2. INITIATE CINEMATIC PHASE
	is_in_attack_phase = true
	$UI.visible = false # Hide standard UI (End turn, cards in hand, etc.)
	clear_field_selection() # Drop the highlights
	
	# 3. TWEEN THE CAMERA TO LOOK AT THE CARD
	var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Hover slightly above and back from the active slot, looking almost straight down
	var target_pos = active_slot_marker.global_position + Vector3(0, 1.8, 0.4) 
	var target_rot = Vector3(deg_to_rad(-75), 0, 0) 
	
	cam_tween.tween_property(camera_3d, "global_position", target_pos, 0.6)
	cam_tween.tween_property(camera_3d, "rotation", target_rot, 0.6)
	
	# 4. SHOW THE MOVES OVERLAY WHEN FINISHED
	cam_tween.chain().tween_callback(func():
		attack_overlay.visible = true
		
		# Optional: You can dynamically pull the names of the moves from the card here
		# to update the UI buttons if you decide to make them visible instead of transparent!
		var card_data = active_slot_card.card_info
		if card_data.move1_name == "": move1_button.visible = false
		else: move1_button.visible = true
		
		if card_data.move2_name == "": move2_button.visible = false
		else: move2_button.visible = true
	)

func cancel_attack_phase():
	# SWOOP CAMERA BACK TO NORMAL
	attack_overlay.visible = false
	var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	cam_tween.tween_property(camera_3d, "global_position", original_camera_pos, 0.6)
	cam_tween.tween_property(camera_3d, "rotation", original_camera_rot, 0.6)
	
	cam_tween.chain().tween_callback(func():
		is_in_attack_phase = false
		$UI.visible = true
	)

func spawn_floating_error_text(message: String, spawn_pos: Vector2):
	var error_label = Label.new()
	error_label.text = message
	
	# Style it with bright red and a thick black outline
	error_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) 
	error_label.add_theme_font_size_override("font_size", 22)
	error_label.add_theme_color_override("font_outline_color", Color.BLACK)
	error_label.add_theme_constant_override("outline_size", 5)
	
	# Attach it to the UI and place it over the button
	if has_node("UI"):
		$UI.add_child(error_label)
	error_label.global_position = spawn_pos
	
	# Animate it floating up and fading out
	var tween = create_tween().set_parallel(true)
	tween.tween_property(error_label, "global_position", spawn_pos + Vector2(0, -60), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(error_label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	
	# Delete it automatically when the animation finishes so it doesn't leak memory
	tween.chain().tween_callback(error_label.queue_free)
