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
				
	# 3. IF SUCCESSFUL: Disconnect from hand entirely and slide to the marker location
	if placement_successful:
		# Remove from the CardManager folder layout system
		card_node.get_parent().remove_child(card_node)
		add_child(card_node) # Add directly to main world space
		
		# Set card properties for the field
		card_node.scale = Vector3(0.55, 0.55, 0.55) # Shrink slightly so it fits perfectly inside your squares
		
		# Animate a smooth snap down onto the board grid
		var snap_tween = create_tween().set_parallel(true)
		snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Slide to slot position, add a tiny Y height gap so it rests on the grid
		snap_tween.tween_property(card_node, "global_position", target_global_position + Vector3(0, 0.02, 0), 0.2)
		# Keep it flat face up against the board
		snap_tween.tween_property(card_node, "global_rotation", Vector3(deg_to_rad(-90), 0, 0), 0.2)
		
		# Force hand to adjust and immediately close up the permanent empty gap
		card_manager.arrange_hand()
		
		# Turn interaction back on if you want field cards clickable later
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
			
	else:
		# NO SLOTS AVAILABLE: Reject and drop back into hand
		print("Field is full! Returning card to hand.")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()
