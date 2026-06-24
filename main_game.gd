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
				
	# 3. IF SUCCESSFUL: Disconnect from hand entirely and animate the game board entry
	if placement_successful:
		card_node.get_parent().remove_child(card_node)
		add_child(card_node)
		
		# Set card properties for the field
		card_node.scale = Vector3(0.55, 0.55, 0.55) # Matches slot size
		
		# --- POKEMON TCG STYLE SLAM TWEEN ---
		var snap_tween = create_tween().set_parallel(true)
		
		# TRANS_BACK + EASE_OUT makes it pop up slightly and slam down like a physical chip!
		snap_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Destination is right on the marker surface
		var final_pos = target_global_position + Vector3(0, 0.02, 0)
		
		# Tween the position and flat layout over 0.25 seconds
		snap_tween.tween_property(card_node, "global_position", final_pos, 0.25)
		snap_tween.tween_property(card_node, "global_rotation", Vector3(deg_to_rad(-90), 0, 0), 0.25)
		
		# Force hand manager to update seamlessly
		card_manager.arrange_hand()
		
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
	else:
		# NO SLOTS AVAILABLE: Reject and drop back into hand
		print("Field is full! Returning card to hand.")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()
			
		# Call this to wake up the field drop zone when a drag starts
func activate_field_drop_zone(should_activate: bool):
	if has_node("FieldDropZone/CollisionShape3D"):
		# Inversing the activation: if we want it active, disabled must be false
		$FieldDropZone/CollisionShape3D.disabled = !should_activate
		print("Field Drop Zone Collision Active: ", should_activate)
