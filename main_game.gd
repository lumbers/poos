extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
@onready var camera_3d: Camera3D = $Camera3D

# --- BOARD SLOT ANCHORS ---
@onready var active_slot_marker = $BoardSlots/ActiveSlot
@onready var bench_markers = [
	$BoardSlots/BenchSlot1,
	$BoardSlots/BenchSlot2,
	$BoardSlots/BenchSlot3
]

var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null]

# --- NEW GAMEPLAY SYSTEMS (RULES & ENERGY) ---
var max_hand_size: int = 7
var current_energy: int = 3 # Start with 3 energy for testing purposes

func _ready():
	get_viewport().physics_object_picking = true
	deck_3d.deck_clicked.connect(_on_deck_clicked)
	activate_field_drop_zone(false)
	print("Game initialized! Current Energy: ", current_energy)

func _on_deck_clicked():
	# FIX 1: Hand Limit Restraint Check
	# Check how many card nodes are currently sitting inside your hand folder
	if card_manager.get_child_count() >= max_hand_size:
		print("Hand is full! Cannot draw more than ", max_hand_size, " cards.")
		# Small shake effect on the deck to provide physical feedback
		var shake = create_tween()
		shake.tween_property(deck_3d, "position:x", deck_3d.position.x + 0.05, 0.05)
		shake.tween_property(deck_3d, "position:x", deck_3d.position.x - 0.05, 0.05)
		shake.tween_property(deck_3d, "position:x", deck_3d.position.x, 0.05)
		return
		
	if card_pool.is_empty():
		print("Warning: Your Card Pool array is empty in the Inspector!")
		return
		
	var random_data = card_pool.pick_random()
	var new_card = card_manager.card_scene.instantiate()
	new_card.card_info = random_data
	
	if new_card.has_node("Area3D"):
		new_card.get_node("Area3D").input_ray_pickable = false
	
	add_child(new_card)
	new_card.global_position = deck_3d.global_position + Vector3(0, 0.1, 0)
	new_card.global_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	var fly_past_target = deck_3d.global_position + Vector3(0, 0.1, 1.8)
	var fly_tween = create_tween().set_parallel(true)
	fly_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var face_floor_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	fly_tween.tween_property(new_card, "global_position", fly_past_target, 0.3)
	fly_tween.tween_property(new_card, "global_rotation", face_floor_rotation, 0.3)
	
	fly_tween.chain().tween_callback(_add_to_hand_seamlessly.bind(new_card))
	
func _add_to_hand_seamlessly(card_node: Node3D):
	card_node.get_parent().remove_child(card_node)
	card_manager.add_child(card_node)
	
	card_node.rotation = Vector3.ZERO
	card_node.scale = Vector3(0.75, 0.75, 0.75)
	
	card_manager.arrange_hand()
	
	var collision_timer = create_tween()
	collision_timer.tween_interval(0.15)
	collision_timer.tween_callback(func():
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
	)

func try_place_pie_on_field(card_node: Node3D):
	# --- NEW ENERGY RESOURCE SYSTEM CHECK ---
	# Checks if player can afford the 1 Energy point required to play a Pie
	var play_cost = 1
	if current_energy < play_cost:
		print("Not enough energy! Requires ", play_cost, " (You have: ", current_energy, ")")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()
		return

	var target_global_position: Vector3 = Vector3.ZERO
	var placement_successful: bool = false
	
	if active_slot_card == null:
		active_slot_card = card_node
		target_global_position = active_slot_marker.global_position
		placement_successful = true
	else:
		for i in range(bench_slot_cards.size()):
			if bench_slot_cards[i] == null:
				bench_slot_cards[i] = card_node
				target_global_position = bench_markers[i].global_position
				placement_successful = true
				break

	if placement_successful:
		# --- DEDUCT ENERGY COST ON SUCCESS ---
		current_energy -= play_cost
		print("Card played! Remaining Energy: ", current_energy)
		
		card_node.is_on_board = true
		card_node.get_parent().remove_child(card_node)
		add_child(card_node)

		var cam_forward = -camera_3d.global_transform.basis.z
		var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3

		var field_scale = Vector3(0.85, 0.85, 0.85)
		
		# STEP 1: Fly up in front of camera, keep current scale (TIMING LOCKED)
		var tween = create_tween()
		var fly = tween.parallel()
		fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(card_node, "global_position", camera_front_pos, 0.1)
		fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.1)

		# PAUSE: Hold in front of camera (TIMING LOCKED)
		tween.chain().tween_interval(0)

		# STEP 2: Slam down AND turn to flat parallel layout simultaneously (TIMING LOCKED)
		var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		var slam = tween.chain().parallel()
		
		slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		slam.tween_property(card_node, "global_transform:basis", flat_basis, 0.22)
		slam.tween_property(card_node, "global_position", target_global_position + Vector3(0, 0.02, 0), 0.22)
		slam.tween_property(card_node, "scale", field_scale, 0.22)

		card_manager.arrange_hand()

		# Update callback to unlock picking AND wake up the Nextbot HP display
		tween.chain().tween_callback(func():
			if card_node.has_node("Area3D"):
				card_node.get_node("Area3D").input_ray_pickable = true
			
			# ---> WAKE UP TRACKER HERE <---
			if card_node.has_method("update_field_hp_display"):
				card_node.update_field_hp_display()
		)

	else:
		print("Field is full! Returning card to hand.")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()

# Call this to wake up the field drop zone when a drag starts
func activate_field_drop_zone(should_activate: bool):
	if has_node("FieldDropZone/CollisionShape3D"):
		# Inversing the activation: if we want it active, disabled must be false
		$FieldDropZone/CollisionShape3D.disabled = !should_activate
		print("Field Drop Zone Collision Active: ", should_activate)
		
		# --- NEW COMBAT / ATTACK DEBUG TESTING KEY ---
func _unhandled_input(event: InputEvent):
	# Test Damage: Pressing "ENTER" will hit your Active Pie for 20 damage!
	if event.is_action_pressed("ui_accept"): # UI_ACCEPT is typically the Enter/Return key
		if active_slot_card != null and active_slot_card.has_method("take_damage"):
			print("Debug: Attacking Active Pie for 20 damage!")
			active_slot_card.take_damage(20)
			
	# Test Healing/Buffing: Pressing "H" will heal your Active Pie for 15 health!
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if active_slot_card != null and active_slot_card.has_method("heal_pie"):
			print("Debug: Healing Active Pie for 15 HP (Testing Over-heal limits)!")
			active_slot_card.heal_pie(15)
