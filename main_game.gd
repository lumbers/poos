extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
@onready var camera_3d: Camera3D = $Camera3D

# --- NEW BOARD SLOT ANCHORS ---
@onready var active_slot_marker = $BoardSlots/ActiveSlot
@onready var bench_markers = [
	$BoardSlots/BenchSlot1,
	$BoardSlots/BenchSlot2,
	$BoardSlots/BenchSlot3
]

# Arrays to keep track of which card nodes are physically sitting in which slots
var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null] # Holds up to 3 cards

func _ready():
	get_viewport().physics_object_picking = true
	deck_3d.deck_clicked.connect(_on_deck_clicked)
	
	# Start with the zone disabled so it doesn't block the deck or table clicks
	activate_field_drop_zone(false)

func _on_deck_clicked():
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

# ==========================================================
# 🎯 THE BOARD PLACEMENT LOGIC
# ==========================================================
func try_place_pie_on_field(card_node: Node3D):
	var target_global_position: Vector3 = Vector3.ZERO
	var placement_successful: bool = false
	
	# 1. PRIORITY 1: Check if the Active Spot is free
	if active_slot_card == null:
		active_slot_card = card_node
		target_global_position = active_slot_marker.global_position
		placement_successful = true
		print("Placed Pie in the Active Zone!")
		
	# 2. PRIORITY 2: Check Bench Slots left-to-right
	else:
		for i in range(bench_slot_cards.size()):
			if bench_slot_cards[i] == null:
				bench_slot_cards[i] = card_node
				target_global_position = bench_markers[i].global_position
				placement_successful = true
				print("Placed Pie on Bench Slot ", i + 1)
				break
				
	# 3. HIGH-SPEED COUNTER-CLOCKWISE SPIN AND ACCELERATED SLAM
	if placement_successful:
		card_node.is_on_board = true
		
		# Disconnect card from hand layout folder instantly
		card_node.get_parent().remove_child(card_node)
		add_child(card_node)
		
		var final_field_scale = Vector3(0.85, 0.85, 0.85)
		var camera_zoom_scale = Vector3(1.3, 1.3, 1.3)
		
		# Position anchor right in front of camera lens lens
		var camera_front_pos = camera_3d.global_transform.origin + camera_3d.global_transform.basis.z * -1.3 + Vector3(0, -0.1, 0)
		
		# Create a serial master chain sequence
		var show_tween = create_tween()
		
		# ==========================================================
		# PHASE 1: EXPLOSIVE RUSH TO CAMERA & HORIZONTAL TUMBLE (0.2s)
		# ==========================================================
		var fly_up = show_tween.parallel()
		fly_up.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		fly_up.tween_property(card_node, "global_position", camera_front_pos, 0.2)
		fly_up.tween_property(card_node, "scale", camera_zoom_scale, 0.2)
		
		# --- THE PERFECT HORIZONTAL FLIP ---
		# We force a clean 360-degree rotation loop strictly on the Y-axis (Yaw)
		# relative to the camera face, keeping X and Z perfectly steady so it doesn't wobble!
		var target_rot_y = camera_3d.global_rotation.y + deg_to_rad(360)
		
		fly_up.tween_property(card_node, "global_rotation:x", camera_3d.global_rotation.x, 0.2)
		fly_up.tween_property(card_node, "global_rotation:y", target_rot_y, 0.2)
		fly_up.tween_property(card_node, "global_rotation:z", camera_3d.global_rotation.z, 0.2)
		# ==========================================================
		# PHASE 2: INSTANT ACCELERATED DIVE (0.18s)
		# ==========================================================
		var slam_down = show_tween.chain().parallel()
		slam_down.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		var final_pos = target_global_position + Vector3(0, 0.02, 0)
		
		slam_down.tween_property(card_node, "global_position", final_pos, 0.18)
		slam_down.tween_property(card_node, "global_rotation", Vector3(deg_to_rad(-90), 0, 0), 0.18)
		slam_down.tween_property(card_node, "scale", final_field_scale, 0.18)
		
		# Clear up the hand gaps frame-one
		card_manager.arrange_hand()
		
		show_tween.chain().tween_callback(func():
			if card_node.has_node("Area3D"):
				card_node.get_node("Area3D").input_ray_pickable = true
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
