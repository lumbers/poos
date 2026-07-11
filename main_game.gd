extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
@onready var camera_3d: Camera3D = $Camera3D
@onready var boss_vignette = $UI/BossVignette  # ColorRect covering full screen

@onready var remove_target_button = $TacticalOverlay/Control/RemoveTargetButton

@onready var switch_button = $UI/SwitchButton
@onready var free_move_up_button = $UI/FreeMoveUpButton
@onready var cancel_button = $UI/CancelButton
@onready var domain_sfx_player = $DomainSFXPlayer
@onready var domain_bgm_player = $DomainBGMPlayer
@onready var sfx_player = $SFXPlayer

# Change this line:
@onready var tactical_overlay = $TacticalOverlay/Control
@onready var target_text = $TacticalOverlay/Control/TargetText
@onready var confirm_button = $TacticalOverlay/Control/ConfirmButton
@onready var cancel_tactical_button = $TacticalOverlay/Control/CancelTacticalButton

@onready var ghost_slots_container = $GhostSlotsContainer
@onready var ghost_slot_active = $GhostSlotsContainer/GhostSlot
@onready var ghost_slot_bench = [
	$GhostSlotsContainer/GhostSlot,
	$GhostSlotsContainer/GhostSlot2,
	$GhostSlotsContainer/GhostSlot3,
]

# --- DOMAIN SYSTEM ---
@onready var domain_slot_marker = $BoardSlots/DomainSlotMarker
@onready var domain_clash_overlay = $UI/DomainClashOverlay
@onready var clash_timer_label = $UI/DomainClashOverlay/Panel/Timer
@onready var clash_result_label = $UI/DomainClashOverlay/ResultLabel
@onready var clash_rock_button = $UI/DomainClashOverlay/Panel/HBoxContainer/RockButton
@onready var clash_paper_button = $UI/DomainClashOverlay/Panel/HBoxContainer/PaperButton
@onready var clash_scissors_button = $UI/DomainClashOverlay/Panel/HBoxContainer/ScissorsButton

# --- CONSTRUCT SYSTEM ---
@onready var construct_slot_marker = $BoardSlots/ConstructSlotMarker
var current_construct_card: Node3D = null

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
var player_can_draw: bool = true

# --- NEW DISCARD PHASE UI HOOKUPS ---
@onready var discard_overlay = $UI/DiscardOverlay
@onready var confirm_discard_button = $UI/ConfirmDiscardButton

@onready var attack_overlay = $AttackOverlay
@onready var move1_button = $AttackOverlay/Control/VBoxContainer/Move1Button
@onready var move2_button = $AttackOverlay/Control/VBoxContainer/Move2Button
@onready var cancel_overlay_button = $AttackOverlay/Control/CancelOverlayButton

@onready var world_environment: WorldEnvironment = $WorldEnvironment
var default_environment: Environment  # saved at game start
var meteor_scene = preload("res://psychic_meteor.tscn")
var original_camera_pos: Vector3
var original_camera_rot: Vector3
var is_in_attack_phase: bool = false
var clash_waiting_for_input: bool = false
var pending_boss_target_pos: Vector3 = Vector3.ZERO
var pending_is_healing: bool = false
var is_in_boss_tribute: bool = false
var current_tributes_selected: Array[Node3D] = []

# --- ADD THESE NEAR YOUR OTHER MARKERS AND POOLS ---
@onready var opponent_discard_pile_marker = $BoardSlots/OpponentDiscardPileMarker
var opponent_graveyard_pool: Array[Node3D] = []

var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null]

# --- ADD THESE NEW LP & OPPONENT TRACKERS ---
var player_lp: int = 1500
var opponent_lp: int = 1500
var opponent_active_card: Node3D = null

var is_in_tactical_targeting: bool = false
var targets_allowed: int = 1
var current_targets_selected: Array = []
var pending_damage_amount: int = 0

var current_domain_card: Node3D = null
var domain_rounds_remaining: int = 0
var round_counter: int = 0
var pending_domain_card: Node3D = null  # the challenger waiting during clash
var is_in_domain_clash: bool = false

var lightning_vfx_scene = preload("res://lightning_effect.tscn")

var reticle_scene = preload("res://target_reticle.tscn") # Make sure you saved your crosshair scene!
var spawned_reticles: Array[Node3D] = []

var lightning_sound = preload("res://sounds/thunda.mp3")
var meteor_sound = preload("res://sounds/meteor.mp3")

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

# Replace your old enum and boss variables with these two lines:
enum DiscardMode { NONE, HAND_LIMIT, SWITCHING, BOSS_TRIBUTE }
var pending_boss_card: Node3D = null

# --- NEW DISCARD & SWITCHING STATES ---
var current_discard_mode: DiscardMode = DiscardMode.NONE

var is_rearranging_field: bool = false
var is_free_move_active: bool = false

func _ready():
	default_environment = world_environment.environment.duplicate()
	# Add these near the top of _ready()
	original_camera_pos = camera_3d.global_position
	original_camera_rot = camera_3d.rotation
	
	var warning = get_node_or_null("UI/HUD/EndTurnWarning")
	if warning:
		warning.visible = false
	
	if attack_overlay: attack_overlay.visible = false
	if tactical_overlay: tactical_overlay.visible = false # <--- ADD THIS LINE
	get_viewport().physics_object_picking = true
	
	# --- 1. SAFELY CONNECT ALL BUTTONS & SIGNALS ---
	if deck_3d and not deck_3d.deck_clicked.is_connected(_on_deck_clicked):
		deck_3d.deck_clicked.connect(_on_deck_clicked)
		
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		
	# FIX: Re-connected your Confirm Discard button!
	if confirm_discard_button and not confirm_discard_button.pressed.is_connected(_on_confirm_discard_pressed):
		confirm_discard_button.pressed.connect(_on_confirm_discard_pressed)
		
	if cancel_tactical_button and not cancel_tactical_button.pressed.is_connected(_on_tactical_cancel_pressed):
		cancel_tactical_button.pressed.connect(_on_tactical_cancel_pressed)
		
	if confirm_button and not confirm_button.pressed.is_connected(_on_tactical_confirm_pressed):
		confirm_button.pressed.connect(_on_tactical_confirm_pressed)
	
	if remove_target_button: remove_target_button.pressed.connect(undo_last_target)
	
	# --- ADD THIS NEW CONNECTION ---
	if confirm_button and not confirm_button.pressed.is_connected(execute_tactical_attack):
		confirm_button.pressed.connect(execute_tactical_attack)
	
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
	
	# --- ATTACK OVERLAY BUTTONS ---
	if move1_button and not move1_button.pressed.is_connected(_on_move1_pressed):
		move1_button.pressed.connect(_on_move1_pressed)
	if move2_button and not move2_button.pressed.is_connected(_on_move2_pressed):
		move2_button.pressed.connect(_on_move2_pressed)
	if cancel_overlay_button and not cancel_overlay_button.pressed.is_connected(cancel_attack_phase):
		cancel_overlay_button.pressed.connect(cancel_attack_phase)

	domain_clash_overlay.visible = false
	clash_rock_button.pressed.connect(func(): _on_clash_choice("rock"))
	clash_paper_button.pressed.connect(func(): _on_clash_choice("paper"))
	clash_scissors_button.pressed.connect(func(): _on_clash_choice("scissors"))

func _on_tactical_confirm_pressed():
	if is_in_tactical_targeting: execute_tactical_attack()
	elif is_in_boss_tribute: finalize_boss_summon()

func _on_tactical_cancel_pressed():
	if is_in_tactical_targeting: cancel_attack_phase()
	elif is_in_boss_tribute: cancel_boss_summon()

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

func show_boss_vignette(show: bool):
	if not boss_vignette:
		return
	boss_vignette.visible = true
	var t = create_tween()
	t.tween_property(boss_vignette, "modulate:a", 1.0 if show else 0.0, 0.6)
	if not show:
		t.tween_callback(func(): boss_vignette.visible = false)
		
func _on_deck_clicked():
	if not player_can_draw:
		spawn_floating_error_text("You are locked from drawing cards!", get_viewport().get_mouse_position())
		return
	# --- THE FIX: Block drawing during ANY special phase or attack! ---
	if is_discard_phase or is_in_attack_phase or is_in_tactical_targeting: 
		return 
	
	var draw_cost = 1
	if current_energy < draw_cost:
		print("Not enough actions left to draw!")
		# Optional: You can spawn your floating error text here too!
		spawn_floating_error_text("Not enough actions!", get_viewport().get_mouse_position())
		return
		
	if card_pool.is_empty(): return
		
	current_energy -= draw_cost
	# ... (Keep the rest of your drawing animation code exactly the same below this!)
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
		var card_type = card_node.card_info.card_type.to_lower()
		if card_type == "domain":
			# Costs 1 energy, handled separately
			current_energy -= play_cost
			try_place_domain(card_node)
			card_manager.arrange_hand()
			update_hud_display()
			return
		elif card_type == "construct":
			# Costs 1 energy, handled separately
			current_energy -= play_cost
			try_place_construct(card_node)
			card_manager.arrange_hand()
			update_hud_display()
			return
		else:
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
		var is_boss = card_node.card_info != null and card_node.card_info.is_boss
		if not is_boss:
			current_energy -= play_cost

		card_node.is_on_board = true
		card_node.get_parent().remove_child(card_node)
		set_ghost_slots_visible(false, true)
		activate_field_drop_zone(false)
		add_child(card_node)

		var cam_forward = -camera_3d.global_transform.basis.z
		var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3
		var field_scale = Vector3(0.85, 0.85, 0.85)
		
		# 1. EVERY card flies up to the camera first
		var tween = create_tween()
		var fly = tween.parallel()
		fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(card_node, "global_position", camera_front_pos, 0.15)
		fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.15)

		if is_boss:
			# --- BOSS HOVER MODE ---
			pending_boss_target_pos = target_global_position + Vector3(0, 0.02, 0)
			
			tween.chain().tween_callback(func():
				if card_node.has_node("Area3D"):
					card_node.get_node("Area3D").input_ray_pickable = true
				if card_node.has_method("update_field_hp_display"):
					card_node.update_field_hp_display()
					
				# --- IDLE BREATHING ANIMATION ---
				var idle_tween = create_tween().set_loops()
				idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				idle_tween.tween_property(card_node, "global_position", camera_front_pos + Vector3(0, 0.04, 0), 1.5)
				idle_tween.tween_property(card_node, "global_position", camera_front_pos - Vector3(0, 0.02, 0), 1.5)
				card_node.set_meta("idle_tween", idle_tween) 
				
				# ---> NEW: TURN ON THE DARK AURA AND VIGNETTE! <---
				if card_node.has_method("activate_boss_vfx"):
					card_node.activate_boss_vfx()
				show_boss_vignette(true)
				
				start_boss_tribute_phase(card_node)
			)
		else:
			# --- NORMAL SLAM MODE ---
			# Instantly chain the downward slam for normal pies
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
	print("END TURN PRESSED | is_in_boss_tribute: ", is_in_boss_tribute, " | current_discard_mode: ", current_discard_mode, " | is_discard_phase: ", is_discard_phase, " | is_in_domain_clash: ", is_in_domain_clash)
	
	if is_in_boss_tribute:
		show_end_turn_warning("Discard cards first!")
		return
	
	if is_in_domain_clash:
		show_end_turn_warning("Resolve domain clash first!")
		return
	# ... rest unchanged
	
	# ... rest unchanged
		
	# ... rest of your existing function
	execute_end_of_turn_passives()
	
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
		update_discard_ui_counters()
	else:
		# Only advance the round and start new turn if no discard needed
		round_counter += 1
		if current_domain_card != null:
			domain_rounds_remaining -= 1
			if domain_rounds_remaining <= 0:
				expire_domain()
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
		current_energy -= 1 

	# --- NEW: BOSS TRIBUTE ENFORCEMENT ---
	elif current_discard_mode == DiscardMode.BOSS_TRIBUTE:
		if marked_for_discard.size() != 3:
			print("You MUST discard exactly 3 cards to summon a boss!")
			return

	print("Processing burning selection...")
	var finished_mode = current_discard_mode 
	
	is_discard_phase = false
	current_discard_mode = DiscardMode.NONE
	
	if discard_overlay: discard_overlay.visible = false
	if confirm_discard_button: confirm_discard_button.visible = false
	if cancel_button: cancel_button.visible = false
	
	# Delete the actual cards!
	# Delete the actual cards!
	for card in marked_for_discard:
		if is_instance_valid(card):
			# --- THE FIX: Instantly rip it out of the manager's list! ---
			if card.get_parent():
				card.get_parent().remove_child(card)
			# Now queue it for deletion safely
			card.queue_free()
			
	# ---> PUT THE EVENT BUS SIGNAL RIGHT HERE! <---
	# This shouts to the whole game: "Hey! Cards were just discarded!"
	if EventBus:
		EventBus.emit_signal("cards_discarded", marked_for_discard.size())
		
	marked_for_discard.clear()
	
	# DELETE THIS LINE! -> clear_field_selection() 
		
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
	
	update_graveyard_mouse_priorities()
	marked_for_discard.clear()
	
	# --- THE FIX FOR HAND CENTERING ---
	if card_manager:
		# Force every surviving card to forget the mouse
		for remaining_card in card_manager.get_children():
			remaining_card.is_hovered = false
			
		card_manager.hovered_card_index = -1
		card_manager.arrange_hand()
	
	# --- 3. ROUTE THE GAME STATE ---
	if finished_mode == DiscardMode.HAND_LIMIT:
		start_new_turn()
	elif finished_mode == DiscardMode.SWITCHING:
		execute_paid_switch()
	# --- NEW: ROAR ON SUCCESSFUL BOSS SUMMON ---
	elif finished_mode == DiscardMode.BOSS_TRIBUTE:
		is_in_boss_tribute = false
		current_energy -= 1
		update_hud_display() 
		
		if is_instance_valid(pending_boss_card):
			# 1. KILL THE BREATHING ANIMATION & VFX
			if pending_boss_card.has_meta("idle_tween"):
				var idle_tween = pending_boss_card.get_meta("idle_tween")
				if is_instance_valid(idle_tween):
					idle_tween.kill()
					
			# ---> NEW: TURN OFF EFFECTS <---
			if pending_boss_card.has_method("deactivate_boss_vfx"):
				pending_boss_card.deactivate_boss_vfx()
			show_boss_vignette(false)
					
			# 2. SLAM ONTO THE BOARD
			# (Keep your existing slam_tween code exactly as it is below here!)
			var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
			var field_scale = Vector3(0.85, 0.85, 0.85)
			
			var slam_tween = create_tween().set_parallel(true)
			slam_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			slam_tween.tween_property(pending_boss_card, "global_transform:basis", flat_basis, 0.22)
			slam_tween.tween_property(pending_boss_card, "global_position", pending_boss_target_pos, 0.22)
			slam_tween.tween_property(pending_boss_card, "scale", field_scale, 0.22)
			
			# 3. TRIGGER THE ROAR UPON IMPACT
			slam_tween.chain().tween_callback(func():
				if pending_boss_card.has_node("EntrySound"):
					var roar = preload("res://sounds/lightning_strike.mp3") 
					pending_boss_card.get_node("EntrySound").stream = roar
					pending_boss_card.get_node("EntrySound").play()
				pending_boss_card = null
			)

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
	
	# --- 3. THE FREE DRAW (Cleaned up via scripts!) ---
	var loops_to_draw = 1
	
	if current_construct_card != null and current_construct_card.card_info.custom_ability_script != null:
		var ability_instance = current_construct_card.card_info.custom_ability_script.new()
		loops_to_draw = ability_instance.execute_passive_effect(self, current_construct_card)
		
	for d in range(loops_to_draw):
		if card_pool.is_empty():
			break
			
		# Delay subsequent card draws slightly so animations don't overlap awkwardly
		if d > 0:
			await get_tree().create_timer(0.4).timeout
			
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
		
		fly_tween.chain().tween_callback(func(): _add_to_hand_seamlessly(new_card))
	# 3. Refresh HUD UI display counters
	update_hud_display()
	
	# --- RESET STATUS LOCKS ---
	player_can_draw = true
	
	var all_my_pies = []
	if active_slot_card != null: all_my_pies.append(active_slot_card)
	for p in bench_slot_cards: 
		if p != null: all_my_pies.append(p)
		
	for pie in all_my_pies:
		pie.can_attack = true
		pie.can_switch = true
	
	# ==========================================================
# 💀 BATTLEFIELD PIE DEATH REAPER LOGIC
# ==========================================================
func handle_pie_death(card_node: Node3D):
	# --- NEW CONSTRUCT INTERCEPTOR ---
	# This must be at the VERY TOP so it triggers and exits before any LP is deducted!
	if card_node.card_info and card_node.card_info.card_type.to_lower() == "construct":
		print("Construct has been shattered: ", card_node.card_info.card_name)
		if card_node.has_node("HPTracker"):
			card_node.get_node("HPTracker").visible = false
			
		if current_construct_card == card_node:
			current_construct_card = null
			
		discard_graveyard_pool.append(card_node)
		
		# Used slightly different variable names here to avoid Godot shadow errors
		var construct_dest = discard_pile_marker.global_position
		var construct_flat = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		var construct_scale = Vector3(0.85, 0.85, 0.85)
		
		var construct_tween = create_tween().set_parallel(true)
		construct_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		construct_tween.tween_property(card_node, "global_position", construct_dest, 0.35)
		construct_tween.tween_property(card_node, "global_transform:basis", construct_flat, 0.35)
		construct_tween.tween_property(card_node, "scale", construct_scale, 0.35)
		
		construct_tween.chain().tween_callback(func():
			update_graveyard_mouse_priorities()
			if card_node.has_node("Area3D"):
				card_node.get_node("Area3D").input_ray_pickable = true
		)
		return # EXIT IMMEDIATELY! Prevents the code below from running and taking your LP.

	# ==========================================
	# --- NORMAL PIE LOGIC (Only runs if it is NOT a construct) ---
	# ==========================================
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
			print("Debug: Attacking Active Pie for 50 damage!")
			active_slot_card.take_damage(50)
			
	# Test Healing: Pressing "H" will heal your Active Pie for 15 health!
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if active_slot_card != null and active_slot_card.has_method("heal_pie"):
			print("Debug: Healing Active Pie for 50 HP!")
			active_slot_card.heal_pie(50)

	# --- NEW: AGGRESSIVE RIGHT CLICK DETECTION ---
	if is_in_tactical_targeting and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			undo_last_target()

# ==========================================================
# 🔍 3D IN-GAME HOVER CARD INSPECTION SYSTEM
# ==========================================================
@onready var inspect_anchor = $Camera3D/InspectAnchor
var current_3d_preview: Node3D = null

func show_3d_card_preview(source_card: Node3D):
	# If a preview is already showing, get rid of it first
	hide_3d_card_preview()
	
	# Safety check to make sure the card and its data exist
	if source_card == null or source_card.card_info == null or inspect_anchor == null:
		return
		
	var card_scene_path = load("res://card_3d.tscn") 
	var preview_instance = card_scene_path.instantiate()
	
	# Assign the resource data first
	preview_instance.card_info = source_card.card_info
	inspect_anchor.add_child(preview_instance)
	current_3d_preview = preview_instance
	
	if preview_instance.has_node("Area3D"):
		preview_instance.get_node("Area3D").input_ray_pickable = false
		
	if preview_instance.has_node("HPTracker"):
		preview_instance.get_node("HPTracker").visible = false

	# --- THE FIX FOR LIVE HP ---
	# We must wait one frame for the preview to finish its default _ready() setup.
	# Then, we force its HP to match the board card and reload the text!
	await get_tree().process_frame
	if is_instance_valid(preview_instance) and is_instance_valid(source_card):
		preview_instance.current_hp = source_card.current_hp
		preview_instance.peak_hp = source_card.peak_hp
		preview_instance.load_card_data()

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
	# Check for Status Locks!
	if active_slot_card != null and not active_slot_card.can_switch:
		spawn_floating_error_text("This Pie is trapped and cannot switch!", $UI/SwitchButton.global_position)
		return
	
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

func _unhandled_input(event):
	if is_in_attack_phase and event.is_action_pressed("ui_cancel"):
		cancel_attack_phase()

func cancel_switching_discard():
	print("Discard action cancelled!")
	var was_boss_mode = (current_discard_mode == DiscardMode.BOSS_TRIBUTE)
	
	is_discard_phase = false
	current_discard_mode = DiscardMode.NONE
	
	for card in marked_for_discard:
		if is_instance_valid(card) and card.has_method("set_discard_highlight"):
			card.set_discard_highlight(false)
	marked_for_discard.clear()
	
	if discard_overlay: discard_overlay.visible = false
	if confirm_discard_button: confirm_discard_button.visible = false
	if cancel_button: cancel_button.visible = false
	
	clear_field_selection()
	
	# --- NEW: RETURN BOSS TO HAND IF CANCELLED ---
	if was_boss_mode and is_instance_valid(pending_boss_card):
		
		# --- KILL IDLE TWEEN & VFX ---
		if pending_boss_card.has_meta("idle_tween"):
			var idle_tween = pending_boss_card.get_meta("idle_tween")
			if is_instance_valid(idle_tween):
				idle_tween.kill()
				
		# ---> NEW: TURN OFF EFFECTS <---
		if pending_boss_card.has_method("deactivate_boss_vfx"):
			pending_boss_card.deactivate_boss_vfx()
		show_boss_vignette(false)
				
		# 1. Un-assign it from the board logic
		# (Keep the rest of your cancel code exactly as it is below here!)
		if active_slot_card == pending_boss_card: 
			active_slot_card = null
		else:
			for i in range(bench_slot_cards.size()):
				if bench_slot_cards[i] == pending_boss_card:
					bench_slot_cards[i] = null
					break
					
		# --- THE FIXES ---
		
		if pending_boss_card.has_node("HPTracker"):
			pending_boss_card.get_node("HPTracker").visible = false # HIDE THE GHOST HP!
		# -----------------
		
		# 2. Add it seamlessly back to the hand manager
		pending_boss_card.is_on_board = false
		_add_to_hand_seamlessly(pending_boss_card)
		pending_boss_card = null
	
# ==========================================================
# 🔄 FIELD SWITCHING & MOVEMENT LOGIC
# ==========================================================

func handle_field_pie_clicked(pie: Node3D):
	if is_discard_phase: return
	
	# --- NEW: UNIFIED TACTICAL TARGETING ---
	if is_in_tactical_targeting:
		var type = ""
		if pie.card_info:
			type = pie.card_info.card_type.to_lower().strip_edges()
			
		# Enforce single-target rules: NO benched pies allowed
		if targets_allowed == 1:
			# If the clicked card is NOT one of these three, block it!
			if pie != active_slot_card and pie != opponent_active_card and pie != current_construct_card:
				spawn_floating_error_text("Can only hit Active Pies or Constructs!", get_viewport().get_mouse_position())
				return
				
		# Allow targeting ANY active Pie or Construct (including yourself!)
		if type == "pie" or type == "construct":
			add_tactical_target(pie)
		else:
			spawn_floating_error_text("Invalid target!", get_viewport().get_mouse_position())
		return 
		
	# --- NORMAL SELECTION LOGIC (Keep all of this exactly as it was!) ---
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
	var old_hand_label = get_node_or_null("UI/DiscardOverlay/DiscardInstructionLabel")
	
	if current_discard_mode == DiscardMode.SWITCHING:
		if old_hand_label: old_hand_label.visible = false
		if discard_title: 
			discard_title.text = "Discard 2 cards to switch your pie"
			discard_title.visible = true
		if discard_counter: 
			discard_counter.text = str(marked_for_discard.size()) + " / 2"
			discard_counter.visible = true
			
	# --- NEW BOSS TRIBUTE TEXT ---
	elif current_discard_mode == DiscardMode.BOSS_TRIBUTE:
		if old_hand_label: old_hand_label.visible = false
		if discard_title: 
			discard_title.text = "Discard 3 cards to summon Boss"
			discard_title.visible = true
		if discard_counter: 
			discard_counter.text = str(marked_for_discard.size()) + " / 3"
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
	
	# Filter the deck so we ONLY grab Pie cards!
	var possible_dummies = []
	for card_data in card_pool:
		if card_data.card_type.to_lower() == "pie":
			possible_dummies.append(card_data)
			
	if possible_dummies.is_empty():
		print("No pies in deck to use as dummy!")
		return
		
	# --- THE FIX: Put the markers you just duplicated into a list! ---
	var enemy_slots = [
		$BoardSlots/OpponentActiveSlot,
		$BoardSlots/OpponentActiveSlot2,
		$BoardSlots/OpponentActiveSlot3,
		$BoardSlots/OpponentActiveSlot4,
	]
	
	# Loop through every marker in the list and spawn a card there
	for i in range(enemy_slots.size()):
		var marker = enemy_slots[i]
		if marker == null: continue # Safety check just in case
		
		var dummy_data = possible_dummies.pick_random() 
		var dummy_card = card_manager.card_scene.instantiate()
		
		dummy_card.card_info = dummy_data
		dummy_card.is_opponent = true # Tags it as enemy property
		add_child(dummy_card)
		
		dummy_card.load_card_data()
		
		dummy_card.global_position = marker.global_position
		dummy_card.global_transform.basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90))).rotated(Vector3.UP, deg_to_rad(180))
		dummy_card.scale = Vector3(0.85, 0.85, 0.85)
		
		dummy_card.is_on_board = true
		
		# Set the first slot as the "Active" enemy so normal attacks still work
		if i == 0:
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
	attack_overlay.visible = false
	
	if has_node("TacticalOverlay"):
		$TacticalOverlay.visible = false 
		
	is_in_tactical_targeting = false 
	current_targets_selected.clear()
	
	# --- ADD THIS CLEANUP LOOP ---
	for r in spawned_reticles:
		if is_instance_valid(r):
			r.queue_free()
	spawned_reticles.clear()
	
	var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property(camera_3d, "global_position", original_camera_pos, 1.2)
	cam_tween.tween_property(camera_3d, "rotation", original_camera_rot, 1.2)
	
	cam_tween.chain().tween_callback(func():
		is_in_attack_phase = false
		$UI.visible = true
	)

func _on_move1_pressed():
	execute_move(1)

func _on_move2_pressed():
	execute_move(2)

func execute_move(move_num: int):
	if active_slot_card == null:
		cancel_attack_phase()
		return
		
	if not active_slot_card.can_attack:
		spawn_floating_error_text("This Pie is locked from attacking!", get_viewport().get_mouse_position())
		cancel_attack_phase()
		return
		
	var card_data = active_slot_card.card_info
	var move_name = card_data.move1_name if move_num == 1 else card_data.move2_name
	
	# THE CLEAN UP HOOK:
	if card_data.custom_ability_script != null:
		var ability_instance = card_data.custom_ability_script.new()
		var intercepted = ability_instance.execute_special_attack(self, active_slot_card, move_num)
		if intercepted:
			return # Let the external file handle the entire attack sequence!
	# ... (Keep the rest of your original execute_move code below here exactly the same)
	var dmg_string = card_data.move1_dmg if move_num == 1 else card_data.move2_dmg
	
	pending_is_healing = false
	if "±" in dmg_string:
		pending_is_healing = true
		dmg_string = dmg_string.replace("±", "")
		
	pending_damage_amount = dmg_string.to_int() + active_slot_card.current_damage_buff
	targets_allowed = card_data.move1_targets if move_num == 1 else card_data.move2_targets
	
	attack_overlay.visible = false
	
	is_in_tactical_targeting = true
	current_targets_selected.clear()
	
	# THE FIX: Show the UI instantly right now, NOT inside the camera tween!
	if has_node("TacticalOverlay"):
		$TacticalOverlay.visible = true
		$TacticalOverlay/Control.visible = true
		$TacticalOverlay/Control/TargetText.text = "Select " + str(targets_allowed) + " Target" + ("s" if targets_allowed > 1 else "")
		$TacticalOverlay/Control/ConfirmButton.visible = false
	
	var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var tactical_pos = Vector3(0, 5.0, 0) 
	var tactical_rot = Vector3(deg_to_rad(-90), 0, 0) 
	
	cam_tween.tween_property(camera_3d, "global_position", tactical_pos, 1.2)
	cam_tween.tween_property(camera_3d, "rotation", tactical_rot, 1.2)
	# Removed the delayed callback that was overriding your fast clicks!
		
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

func animate_physical_attack(attacker: Node3D, target: Node3D, damage: int):
	var original_pos = attacker.global_position
	var target_pos = target.global_position
	
	# Calculate the animation points
	var pullback_pos = original_pos + Vector3(0, 0, 0.4) # Pulls straight back slightly
	var lunge_pos = original_pos.lerp(target_pos, 0.6) # Lunges 60% of the way across the table
	
	var attack_tween = create_tween()
	
	# 1. ANTICIPATION: Card lifts up and pulls back slowly
	attack_tween.tween_property(attacker, "global_position", pullback_pos + Vector3(0, 0.3, 0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. THE STRIKE: Card shoots forward extremely fast
	attack_tween.tween_property(attacker, "global_position", lunge_pos + Vector3(0, 0.1, 0), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# 3. THE IMPACT: Deal the damage the exact millisecond the card hits the lunge point!
	attack_tween.tween_callback(func():
		target.take_damage(damage)
		update_hud_display()
		print("BAM! Dealt ", damage, " damage!")
	)
	
	# 4. THE RETURN: Card slides smoothly back to its home slot
	attack_tween.tween_property(attacker, "global_position", original_pos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func add_tactical_target(pie: Node3D):
	if current_targets_selected.size() >= targets_allowed:
		spawn_floating_error_text("Max targets reached!", get_viewport().get_mouse_position())
		return

	current_targets_selected.append(pie)

	# 1. Spawn visual reticle
	var reticle = reticle_scene.instantiate()
	pie.add_child(reticle)
	reticle.scale = Vector3(0.15, 0.15, 0.15) # <--- Using your preferred 0.05 scale!
	spawned_reticles.append(reticle)
	
	# THE FIX: This single line connects the crosshair to the pie!
	reticle.set_meta("target_pie", pie) 
	
	# 2. Arrange them to match your sketch!
	rearrange_reticles_on_pie(pie)

	# 3. Update the UI Text
	var remaining = targets_allowed - current_targets_selected.size()
	if has_node("TacticalOverlay/Control/TargetText"):
		$TacticalOverlay/Control/TargetText.text = "Select " + str(remaining) + " Targets"

	# 4. Show Confirm Button if we hit the max!
	# --- FIX: Use <= instead of == to catch fast clicks! ---
	if remaining <= 0:
		$TacticalOverlay/Control/ConfirmButton.visible = true
		
func rearrange_reticles_on_pie(pie: Node3D):
	var my_reticles = []
	for r in spawned_reticles:
		if is_instance_valid(r) and r.get_meta("target_pie") == pie:
			my_reticles.append(r)

	var count = my_reticles.size()
	for i in range(count):
		var r = my_reticles[i]
		if count == 1:
			r.position = Vector3(0, 0, 0.1) # Center
		elif count == 2:
			if i == 0: r.position = Vector3(-0.3, -0.3, 0.1) # Top Left
			if i == 1: r.position = Vector3(0.3, 0.3, 0.1)  # Top Right
		elif count >= 3:
			if i == 0: r.position = Vector3(0, 0.3, 0.1) # Top Left
			if i == 1: r.position = Vector3(0.3, -0.3, 0.1)  # Top Right
			if i == 2: r.position = Vector3(-0.3, -0.3, 0.1) # Bottom Left
		
func execute_tactical_attack():
	# THE FIX: Safety shield to prevent double-click crashes!
	if spawned_reticles.is_empty():
		return 
		
	if has_node("TacticalOverlay"):
		$TacticalOverlay.visible = false
		
	# ==========================================
	# --- SINGLE TARGET: PHYSICAL LUNGE OR HEAL ---
	# ==========================================
	if targets_allowed == 1:
		var target_node = spawned_reticles[0].get_meta("target_pie")
		
		# Clean up UI immediately
		for r in spawned_reticles:
			if is_instance_valid(r): r.queue_free()
		spawned_reticles.clear()
		
		current_energy -= 1
		has_attacked_this_turn = true
		update_hud_display()
		
		is_in_tactical_targeting = false 
		current_targets_selected.clear()
		
		var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(camera_3d, "global_position", original_camera_pos, 1.2)
		cam_tween.tween_property(camera_3d, "rotation", original_camera_rot, 1.2)
		
		cam_tween.chain().tween_callback(func():
			is_in_attack_phase = false
			if has_node("UI"): $UI.visible = true
			
			if pending_is_healing:
				if target_node.has_method("heal_pie"):
					target_node.heal_pie(pending_damage_amount)
					
			# --- TELEKINESIS CHECK ---
			# If the pie is psychic and deals 0 damage, trap them!
			elif pending_damage_amount == 0 and active_slot_card.card_info.card_name.to_lower() == "psychic pie":
				target_node.can_attack = false
				target_node.can_switch = false
				spawn_floating_error_text("Telekinesis Trapped!", target_node.global_position)
				# We skip the lunge animation so he just attacks with his mind!
				
			else:
				animate_physical_attack(active_slot_card, target_node, pending_damage_amount)
		)
		return 
	# ... inside execute_tactical_attack() ...
	if targets_allowed > 1:
		# CHECKMOVE HOOK INTERCEPTOR
		if active_slot_card and active_slot_card.card_info and active_slot_card.card_info.card_name.to_lower() == "psychic pie":
			# Clear reticles and drop the giant cosmic rock instead of lightning strikes!
			for r in spawned_reticles:
				if is_instance_valid(r): r.queue_free()
			spawned_reticles.clear()
			
			current_energy -= 1
			has_attacked_this_turn = true
			update_hud_display()
			is_in_tactical_targeting = false
			
			var cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			cam_tween.tween_property(camera_3d, "global_position", original_camera_pos, 1.2)
			cam_tween.tween_property(camera_3d, "rotation", original_camera_rot, 1.2)
			
			cam_tween.chain().tween_callback(func():
				is_in_attack_phase = false
				if has_node("UI"): $UI.visible = true
				spawn_psychic_meteor_strike() # Triggers the flaming comet drop sequence
			)
			return # Exit early out of the standard lightning engine block
			
	# ==========================================
	# --- MULTI-TARGET: LIGHTNING STRIKES ---
	# ==========================================
	for r in spawned_reticles:
		if is_instance_valid(r):
			var target_pie = r.get_meta("target_pie")
			if target_pie.has_method("take_damage"):
				target_pie.take_damage(pending_damage_amount, r.global_position)
				
				var lightning = lightning_vfx_scene.instantiate()
				add_child(lightning)
				lightning.scale = Vector3(0.5, 0.5, 0.5)
				lightning.global_position = r.global_position + Vector3(0, 0, 0)
				
				var particles = lightning.get_node_or_null("GPUParticles3D")
				if particles:
					particles.emitting = true
					
				get_tree().create_timer(2.0).timeout.connect(lightning.queue_free)
				
				if sfx_player:
					sfx_player.stream = lightning_sound
					sfx_player.play()
				
				r.visible = false 
				await get_tree().create_timer(0.2).timeout
			
	for r in spawned_reticles:
		if is_instance_valid(r): r.queue_free()
	spawned_reticles.clear()
	
	current_energy -= 1
	has_attacked_this_turn = true
	update_hud_display()
	
	is_in_tactical_targeting = false 
	current_targets_selected.clear()
	
	var multi_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	multi_cam_tween.tween_property(camera_3d, "global_position", original_camera_pos, 1.2)
	multi_cam_tween.tween_property(camera_3d, "rotation", original_camera_rot, 1.2)
	
	multi_cam_tween.chain().tween_callback(func():
		is_in_attack_phase = false
		if has_node("UI"): $UI.visible = true
	)

func undo_last_target():
	if current_targets_selected.is_empty():
		spawn_floating_error_text("No targets to remove!", get_viewport().get_mouse_position())
		return

	# Pop the last selected pie from the array
	var last_pie = current_targets_selected.pop_back()

	# Find the EXACT reticle associated with this selection and delete it
	for i in range(spawned_reticles.size() - 1, -1, -1):
		var r = spawned_reticles[i]
		if is_instance_valid(r) and r.get_meta("target_pie") == last_pie:
			r.queue_free()
			spawned_reticles.remove_at(i)
			break # Only remove ONE reticle!

	# Re-center the remaining reticles
	rearrange_reticles_on_pie(last_pie)

	# Update the UI
	var remaining = targets_allowed - current_targets_selected.size()
	if has_node("TacticalOverlay/Control/TargetText"):
		$TacticalOverlay/Control/TargetText.text = "Select " + str(remaining) + " Targets"
	if has_node("TacticalOverlay/Control/ConfirmButton"):
		$TacticalOverlay/Control/ConfirmButton.visible = false

func start_boss_tribute_phase(boss_card: Node3D):
	pending_boss_card = boss_card
	is_in_boss_tribute = true
	is_discard_phase = true
	current_discard_mode = DiscardMode.BOSS_TRIBUTE
	marked_for_discard.clear()
	
	# --- THE FIX: Force the combat UI to hide! ---
	if attack_button: attack_button.visible = false
	if free_move_up_button: free_move_up_button.visible = false
	if switch_button: switch_button.visible = false
	clear_field_selection()
	
	if discard_overlay: discard_overlay.visible = true
	if confirm_discard_button: confirm_discard_button.visible = true
	if cancel_button: cancel_button.visible = true 
	
	update_discard_ui_counters()
	# Activate boss VFX while player discards tributes
	if is_instance_valid(pending_boss_card) and pending_boss_card.has_method("activate_boss_vfx"):
		pending_boss_card.activate_boss_vfx()
	show_boss_vignette(true)

func add_tribute_target(hand_card: Node3D):
	if current_tributes_selected.size() >= 3: return
	if hand_card in current_tributes_selected: return # Prevent double-clicking the same card

	current_tributes_selected.append(hand_card)

	# Stamp the red reticle perfectly on the hand card!
	var reticle = reticle_scene.instantiate()
	hand_card.add_child(reticle)
	reticle.scale = Vector3(0.05, 0.05, 0.05)
	reticle.set_meta("target_pie", hand_card)
	spawned_reticles.append(reticle)
	rearrange_reticles_on_pie(hand_card) 

	var remaining = 3 - current_tributes_selected.size()
	if has_node("TacticalOverlay/Control/TargetText"):
		$TacticalOverlay/Control/TargetText.text = "Tribute " + str(remaining) + " Cards"

	if remaining == 0:
		$TacticalOverlay/Control/ConfirmButton.visible = true

func finalize_boss_summon():
	$TacticalOverlay.visible = false
	is_in_boss_tribute = false
	current_discard_mode = DiscardMode.NONE  # ← ADD THIS
	is_discard_phase = false 
	# Hide the discard UI immediately
	if discard_overlay: discard_overlay.visible = false
	if confirm_discard_button: confirm_discard_button.visible = false
	if cancel_button: cancel_button.visible = false
	# 1. Destroy the 3 tributed cards! 
	for t_card in current_tributes_selected:
		if is_instance_valid(t_card):
			t_card.queue_free()

	# 2. Clean up the reticles
	for r in spawned_reticles:
		if is_instance_valid(r): r.queue_free()
	spawned_reticles.clear()
	current_tributes_selected.clear()

	# Kill the boss VFX now that it's landing
	if is_instance_valid(pending_boss_card) and pending_boss_card.has_method("deactivate_boss_vfx"):
		pending_boss_card.deactivate_boss_vfx()
	show_boss_vignette(false)

	# 3. NOW slam the Boss onto the board!
	if is_instance_valid(pending_boss_card):
		var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		var field_scale = Vector3(0.85, 0.85, 0.85)
		
		var slam_tween = create_tween().set_parallel(true)
		slam_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slam_tween.tween_property(pending_boss_card, "global_transform:basis", flat_basis, 0.22)
		slam_tween.tween_property(pending_boss_card, "global_position", pending_boss_target_pos, 0.22)
		slam_tween.tween_property(pending_boss_card, "scale", field_scale, 0.22)
		
		# Trigger the roar right as it hits the board!
		slam_tween.chain().tween_callback(func():
			if pending_boss_card.has_node("EntrySound"):
				var roar = preload("res://sounds/lightning_strike.mp3") # Change to roar if you prefer!
				pending_boss_card.get_node("EntrySound").stream = roar
				pending_boss_card.get_node("EntrySound").play()
				
			card_manager.arrange_hand()
			update_hud_display()
			pending_boss_card = null
		)

func cancel_boss_summon():
	$TacticalOverlay.visible = false
	is_in_boss_tribute = false
	current_discard_mode = DiscardMode.NONE  # ← ADD THIS
	is_discard_phase = false 
	# Hide the discard UI immediately
	if discard_overlay: discard_overlay.visible = false
	if confirm_discard_button: confirm_discard_button.visible = false
	if cancel_button: cancel_button.visible = false 
	if is_instance_valid(pending_boss_card) and pending_boss_card.has_method("deactivate_boss_vfx"):
		pending_boss_card.deactivate_boss_vfx()
	show_boss_vignette(false)

	for r in spawned_reticles:
		if is_instance_valid(r): r.queue_free()
	spawned_reticles.clear()
	current_tributes_selected.clear()

	# Abort! Send the Boss gliding back to your hand!
	if is_instance_valid(pending_boss_card):
		pending_boss_card.is_on_board = false
		var tween = create_tween()
		tween.tween_property(pending_boss_card, "global_position", pending_boss_card.default_position, 0.4).set_ease(Tween.EASE_OUT)
	pending_boss_card = null

func execute_end_of_turn_passives():
	# 1. Gather every pie currently on your board
	var all_my_board_pies = []
	if active_slot_card != null:
		all_my_board_pies.append(active_slot_card)
		
	for bench_pie in bench_slot_cards:
		if bench_pie != null:
			all_my_board_pies.append(bench_pie)
			
	# 2. Loop through them and trigger any passives
	for pie in all_my_board_pies:
		if pie.card_info.card_name.to_lower() == "ghidorah":
			print("Ghidorah's Passive triggers from the board!")
			
			# Scan the main game board for ANY enemy cards
			var valid_targets = []
			for node in get_children():
				if node.get("is_opponent") == true and node.get("is_on_board") == true:
					if node.has_method("take_damage"):
						valid_targets.append(node)
						
			# Pick a random target from the list and blast it!
			if valid_targets.size() > 0:
				var random_target = valid_targets.pick_random()
				random_target.take_damage(50)
				
				# Spawn your lightning strike
				var lightning = lightning_vfx_scene.instantiate()
				add_child(lightning)
				lightning.global_position = random_target.global_position + Vector3(0, 0, 0)
				if lightning.get_node_or_null("GPUParticles3D"):
					lightning.get_node("GPUParticles3D").emitting = true
				get_tree().create_timer(2.0).timeout.connect(lightning.queue_free)
				
				# Play the sound
				if sfx_player:
					sfx_player.stream = preload("res://sounds/lightning_strike.mp3")
					sfx_player.play()

func try_place_domain(card_node: Node3D):
	if current_domain_card == null:
		# Slot empty, place directly
		place_domain_on_field(card_node)
	else:
		# Slot occupied, start clash
		pending_domain_card = card_node
		start_domain_clash()

func place_domain_on_field(card_node: Node3D):
	current_domain_card = card_node
	domain_rounds_remaining = card_node.card_info.domain_duration
	
	card_node.is_on_board = true
	card_node.get_parent().remove_child(card_node)
	add_child(card_node)
	
	var cam_forward = -camera_3d.global_transform.basis.z
	var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3
	var field_scale = Vector3(0.85, 0.85, 0.85)
	var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	
	var tween = create_tween()
	var fly = tween.parallel()
	fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(card_node, "global_position", camera_front_pos, 0.1)
	fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.1)
	tween.chain().tween_interval(0.05)
	var slam = tween.chain().parallel()
	slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(card_node, "global_position", domain_slot_marker.global_position + Vector3(0, 0.02, 0), 0.22)
	slam.tween_property(card_node, "global_transform:basis", flat_basis, 0.22)
	slam.tween_property(card_node, "scale", field_scale, 0.22)
	
	# ... inside place_domain_on_field code ...
	tween.chain().tween_callback(func():
		apply_domain_environment(card_node)
		spawn_domain_model(card_node)
		play_domain_audio(card_node)
		
		# FORCE HIDE THE PINK DROP ZONE VISUAL MESH NOW
		if is_instance_valid(field_drop_mesh):
			field_drop_mesh.visible = false
			
		if card_node.card_info.domain_has_slash_vfx:
			start_slash_vfx()
	)
	
	card_manager.arrange_hand()
	update_hud_display()

func expire_domain():
	if current_domain_card == null:
		return
	# Fly it to the discard pile
	var dead = current_domain_card
	current_domain_card = null
	domain_rounds_remaining = 0
	discard_graveyard_pool.append(dead)
	var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dead, "global_position", discard_pile_marker.global_position, 0.35)
	tween.tween_property(dead, "global_transform:basis", flat_basis, 0.35)
	tween.chain().tween_callback(func():
		update_graveyard_mouse_priorities()
	)
	restore_default_environment()
	despawn_domain_model()
	stop_domain_audio()
	stop_slash_vfx()

# --- DOMAIN CLASH ---
func start_domain_clash():
	is_in_domain_clash = true
	domain_clash_overlay.visible = true
	clash_result_label.visible = false
	clash_rock_button.disabled = false
	clash_paper_button.disabled = false
	clash_scissors_button.disabled = false
	_run_clash_countdown()

func _run_clash_countdown():
	clash_waiting_for_input = true
	var time_left = 5
	
	# Loop until time runs out or the player makes a choice
	while time_left > 0 and clash_waiting_for_input and is_in_domain_clash:
		clash_timer_label.text = str(time_left)
		await get_tree().create_timer(1.0).timeout
		time_left -= 1
		
	# If the timer expired and input hasn't changed, auto-lock rock
	if clash_waiting_for_input and is_in_domain_clash:
		clash_timer_label.text = "Time's Up!"
		await get_tree().create_timer(0.5).timeout
		_on_clash_choice("rock")

func _on_clash_choice(player_choice: String):
	if not is_in_domain_clash:
		return
		
	# Instantly toggle this off to intercept and break out of the countdown timer loop
	clash_waiting_for_input = false
	
	clash_rock_button.disabled = true
	clash_paper_button.disabled = true
	clash_scissors_button.disabled = true
	
	var choices = ["rock", "paper", "scissors"]
	var ai_choice = choices.pick_random()
	
	var result = _evaluate_rps(player_choice, ai_choice)
	clash_result_label.visible = true
	
	if result == "win":
		clash_result_label.text = "You chose " + player_choice + ", AI chose " + ai_choice + "\nYou win! Your domain stays!"
		await get_tree().create_timer(2.0).timeout
		_finish_clash(true)
	elif result == "lose":
		clash_result_label.text = "You chose " + player_choice + ", AI chose " + ai_choice + "\nAI wins! Their domain stays!"
		await get_tree().create_timer(2.0).timeout
		_finish_clash(false)
	else:
		clash_result_label.text = "You chose " + player_choice + ", AI chose " + ai_choice + "\nTie! Go again!"
		await get_tree().create_timer(1.5).timeout
		# Reset for another round
		clash_rock_button.disabled = false
		clash_paper_button.disabled = false
		clash_scissors_button.disabled = false
		_run_clash_countdown()

func _evaluate_rps(player: String, ai: String) -> String:
	if player == ai:
		return "tie"
	if (player == "rock" and ai == "scissors") or \
	   (player == "scissors" and ai == "paper") or \
	   (player == "paper" and ai == "rock"):
		return "win"
	return "lose"

func _finish_clash(player_won: bool):
	is_in_domain_clash = false
	domain_clash_overlay.visible = false
	clash_waiting_for_input = false
	
	if player_won:
		# Remove existing domain, place the new challenger
		expire_domain()
		await get_tree().create_timer(0.4).timeout
		place_domain_on_field(pending_domain_card)
		restore_default_environment()
	else:
		# AI wins, pending card goes to discard
		if is_instance_valid(pending_domain_card):
			# 1. Flag it as on-board/dead to disable hand interaction scripts
			pending_domain_card.is_on_board = true
			
			# 2. Rip it out of the hand manager and add it to the global game scene
			if pending_domain_card.get_parent():
				pending_domain_card.get_parent().remove_child(pending_domain_card)
			add_child(pending_domain_card)
			
			discard_graveyard_pool.append(pending_domain_card)
			
			# 3. Apply the clean, flat layout rotation used by other fainted cards
			var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
			var target_pile_scale = Vector3(0.85, 0.85, 0.85)
			
			var tween = create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(pending_domain_card, "global_position", discard_pile_marker.global_position, 0.35)
			tween.tween_property(pending_domain_card, "global_transform:basis", flat_basis, 0.35)
			tween.tween_property(pending_domain_card, "scale", target_pile_scale, 0.35)
			
			# 4. Refresh mouse collision priorities and snap remaining hand cards together
			tween.chain().tween_callback(func(): 
				update_graveyard_mouse_priorities()
				if card_manager:
					card_manager.arrange_hand()
			)
	
	pending_domain_card = null

func apply_domain_environment(domain_card: Node3D):
	if domain_card.card_info.domain_environment != null:
	   # Smoothly transition — Godot environments blend automatically
		world_environment.environment = domain_card.card_info.domain_environment

func restore_default_environment():
	if default_environment != null:
		world_environment.environment = default_environment

@onready var domain_model_anchor = $BoardSlots/DomainModelAnchor
var spawned_domain_model: Node3D = null

func spawn_domain_model(domain_card: Node3D):
	if domain_card.card_info.domain_model == null:
		return
	spawned_domain_model = domain_card.card_info.domain_model.instantiate()
	domain_model_anchor.add_child(spawned_domain_model)
	# Start small and scale up for a dramatic entrance
	spawned_domain_model.scale = Vector3.ZERO
	var t = create_tween()
	t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(spawned_domain_model, "scale", Vector3(0.1, 0.1, 0.1), 1.2)

func despawn_domain_model():
	if is_instance_valid(spawned_domain_model):
		# Create a local copy that won't turn null on the next line
		var model_to_free = spawned_domain_model
		spawned_domain_model = null # Safely reset the main tracker immediately
		
		var t = create_tween()
		t.tween_property(model_to_free, "scale", Vector3.ZERO, 0.4)
		t.tween_callback(func(): 
			if is_instance_valid(model_to_free):
				model_to_free.queue_free()
		)
	
func play_domain_audio(domain_card: Node3D): 
	var info = domain_card.card_info
	
	# Play intro sound immediately
	if info.domain_intro_sound:
		domain_sfx_player.stream = info.domain_intro_sound
		domain_sfx_player.play()
	
	# Start BGM after a short delay so intro plays first
	if info.domain_bgm:
		domain_bgm_player.stream = info.domain_bgm
		domain_bgm_player.volume_db = -80.0  # start silent
		# Delay BGM start slightly
		await get_tree().create_timer(1.5).timeout
		domain_bgm_player.play()
		# Fade BGM in
		var t = create_tween()
		t.tween_property(domain_bgm_player, "volume_db", -10.0, 2.0)

func stop_domain_audio():
	# Fade out BGM
	var t = create_tween()
	t.tween_property(domain_bgm_player, "volume_db", -80.0, 1.0)
	t.tween_callback(func(): domain_bgm_player.stop())
	domain_sfx_player.stop()

var slash_vfx_scene = preload("res://slash_vfx.tscn")
var domain_slash_timer: Timer = null

func start_slash_vfx():
	if domain_slash_timer:
		domain_slash_timer.queue_free()
	domain_slash_timer = Timer.new()
	add_child(domain_slash_timer)
	# START DELAY: Rapid first trigger (0.1 to 0.3 seconds)
	domain_slash_timer.wait_time = randf_range(0.1, 0.3)
	domain_slash_timer.timeout.connect(_spawn_slash)
	domain_slash_timer.start()

func _spawn_slash():
	if current_domain_card == null:
		return
	var slash = slash_vfx_scene.instantiate()
	add_child(slash)
	slash.global_position = Vector3(randf_range(-4.0, 4.0), randf_range(1.0, 4.0), -8.0)
	slash.one_shot = true
	slash.emitting = true
	
	# Clean up the particle node quickly since its lifetime is short (0.4s)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(slash):
			slash.queue_free()
	)
	
	# LOOP DELAY: Set the next slash to fire almost instantly (0.05 to 0.2 seconds)
	if domain_slash_timer and is_instance_valid(domain_slash_timer):
		domain_slash_timer.wait_time = randf_range(0.05, 0.2)
		domain_slash_timer.start()

func stop_slash_vfx():
	if is_instance_valid(domain_slash_timer):
		domain_slash_timer.stop()
		domain_slash_timer.queue_free()
	domain_slash_timer = null

func try_place_construct(card_node: Node3D):
	if current_construct_card != null:
		# If a construct already occupies the slot, replace it safely
		expire_construct()
		await get_tree().create_timer(0.4).timeout
	place_construct_on_field(card_node)

func place_construct_on_field(card_node: Node3D):
	current_construct_card = card_node
	
	card_node.is_on_board = true
	card_node.get_parent().remove_child(card_node)
	add_child(card_node)
	
	var cam_forward = -camera_3d.global_transform.basis.z
	var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3
	var field_scale = Vector3(0.85, 0.85, 0.85)
	var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	
	var tween = create_tween()
	var fly = tween.parallel()
	fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(card_node, "global_position", camera_front_pos, 0.1)
	fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.1)
	
	tween.chain().tween_interval(0.05)
	
	var slam = tween.chain().parallel()
	slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam.tween_property(card_node, "global_position", construct_slot_marker.global_position + Vector3(0, 0.02, 0), 0.22)
	slam.tween_property(card_node, "global_transform:basis", flat_basis, 0.22)
	slam.tween_property(card_node, "scale", field_scale, 0.22)
	
	# Hides the pink mat dropzone visual since placement is complete
	if is_instance_valid(field_drop_mesh):
		field_drop_mesh.visible = false
		
	tween.chain().tween_callback(func():
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
		if card_node.has_method("update_field_hp_display"):
			card_node.update_field_hp_display()
	)

func expire_construct():
	if current_construct_card == null:
		return
	var dead = current_construct_card
	current_construct_card = null
	
	if dead.has_node("HPTracker"):
		dead.get_node("HPTracker").visible = false
		
	discard_graveyard_pool.append(dead)
	var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(dead, "global_position", discard_pile_marker.global_position, 0.35)
	tween.tween_property(dead, "global_transform:basis", flat_basis, 0.35)
	tween.chain().tween_callback(func():
		update_graveyard_mouse_priorities()
)

func show_end_turn_warning(message: String):
	var warning = get_node_or_null("UI/HUD/EndTurnWarning")
	if warning == null:
		print("WARNING: EndTurnWarning label not found in scene!")
		return
	warning.text = message
	warning.visible = true
	warning.modulate = Color(1, 0.2, 0.2, 1)
	
	var t = create_tween()
	t.tween_interval(1.5)
	t.tween_property(warning, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): warning.visible = false; warning.modulate.a = 1.0)

func spawn_psychic_meteor_strike():
	# Define target position: the center space between enemy cards
	var target_center = Vector3(0, 0.05, -1.8) 
	if opponent_active_card:
		target_center = opponent_active_card.global_position
		
	# Spawn meteor way up high in the sky and offset it diagonally
	var start_pos = target_center + Vector3(-5.0, 8.0, -4.0)
	
	var meteor = meteor_scene.instantiate()
	add_child(meteor)
	meteor.global_position = start_pos
	# --- THE FIX: SCALE THE METEOR HERE ---
	# Vector3(2.5, 2.5, 2.5) multiplies its original physical proportions by 2.5x!
	# Increase or decrease this number to find your perfect comic scale.
	meteor.scale = Vector3(2.5, 2.5, 2.5)
	# Make the meteor orient itself looking directly along its flight path toward impact
	meteor.look_at(target_center, Vector3.UP)
	
	# Tween the catastrophic decent crashing inward
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(meteor, "global_position", target_center, 0.65)
	
	# Explosive Shockwave Trigger Upon Landing
	tween.chain().tween_callback(func():
		# Scan the board for ANY enemy cards and detonate damage across all of them!
		for node in get_children():
			if node.get("is_opponent") == true and node.get("is_on_board") == true:
				if node.has_method("take_damage"):
					node.take_damage(150, node.global_position)
				
		# Play audio impact burst
		if sfx_player:
			sfx_player.stream = meteor_sound # Replace with a bass heavy crash SFX file if desired!
			sfx_player.play()
			
		# Flash screen via a camera shake or vignette pop
		if boss_vignette:
			boss_vignette.modulate = Color(1.5, 0.5, 2.0, 1.0) # Bright psychic purple blast hue tint
			var flash_fade = create_tween()
			flash_fade.tween_property(boss_vignette, "modulate", Color(1, 1, 1, 1), 0.4)
			
		# --- TRIGGER THE SHAKE ---
		trigger_camera_shake(0.3, 0.6)
		
		# Delete meteor asset container node safely
		meteor.queue_free()
)

func trigger_camera_shake(intensity: float, duration: float):
	var shake_tween = create_tween()
	var original_v = camera_3d.v_offset
	var original_h = camera_3d.h_offset
	var steps = int(duration / 0.05)
	
	for i in range(steps):
		var random_h = randf_range(-intensity, intensity)
		var random_v = randf_range(-intensity, intensity)
		shake_tween.chain().tween_property(camera_3d, "h_offset", random_h, 0.025)
		shake_tween.parallel().tween_property(camera_3d, "v_offset", random_v, 0.025)
	
	# Smoothly return camera to true center
	shake_tween.chain().tween_property(camera_3d, "h_offset", original_h, 0.05)
	shake_tween.parallel().tween_property(camera_3d, "v_offset", original_v, 0.05)
