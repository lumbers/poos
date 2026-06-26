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

# --- NEW DISCARD PILE MARKER ---
@onready var discard_pile_marker = $DiscardPileMarker

var active_slot_card: Node3D = null
var bench_slot_cards: Array[Node3D] = [null, null, null]

# --- GAMEPLAY SYSTEMS ---
var max_hand_size: int = 7
var current_energy: int = 3 # Your actions/energy pool

func _ready():
	get_viewport().physics_object_picking = true
	deck_3d.deck_clicked.connect(_on_deck_clicked)
	activate_field_drop_zone(false)
	print("Game initialized! Current Actions: ", current_energy)

func _on_deck_clicked():
	# Allow drawing past 7 mid-turn! We check actions instead
	var draw_cost = 1
	if current_energy < draw_cost:
		print("Not enough actions left to draw!")
		return
		
	if card_pool.is_empty():
		print("Warning: Your Card Pool array is empty in the Inspector!")
		return
		
	current_energy -= draw_cost
	print("Drew a card. Actions left: ", current_energy)
		
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
	
	var face_floor_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	fly_tween.tween_property(new_card, "global_position", fly_past_target, 0.1)
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
# 🎯 REVISED CARD PLACEMENT AND DISCARD pile LOGIC
# ==========================================================
func try_place_pie_on_field(card_node: Node3D):
	var play_cost = 1
	if current_energy < play_cost:
		print("Not enough actions! Requires ", play_cost, " (You have: ", current_energy, ")")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()
		return

	var is_pie = card_node.card_info and card_node.card_info.card_type.to_lower() == "pie"
	var target_global_position: Vector3 = Vector3.ZERO
	var placement_successful: bool = false
	
	if is_pie:
		# Standard Pie placement checking logic
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
	else:
		# NON-PIE CARDS (Spells, Items) always succeed and target the Discard Pile!
		target_global_position = discard_pile_marker.global_position
		placement_successful = true

	if placement_successful:
		current_energy -= play_cost
		print("Action spent! Remaining actions: ", current_energy)
		
		card_node.is_on_board = true
		card_node.get_parent().remove_child(card_node)
		add_child(card_node)

		var cam_forward = -camera_3d.global_transform.basis.z
		var camera_front_pos = camera_3d.global_transform.origin + cam_forward * 1.3
		var field_scale = Vector3(0.85, 0.85, 0.85)
		
		# STEP 1: Fly up in front of camera lens (LOCKED TIMING)
		var tween = create_tween()
		var fly = tween.parallel()
		fly.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(card_node, "global_position", camera_front_pos, 0.1)
		fly.tween_property(card_node, "global_transform:basis", camera_3d.global_transform.basis, 0.1)

		tween.chain().tween_interval(0)

		# STEP 2: Slam down to destination (Table slot or Discard pile)
		var flat_basis = Basis(Quaternion(Vector3.RIGHT, deg_to_rad(-90)))
		var slam = tween.chain().parallel()
		slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		slam.tween_property(card_node, "global_transform:basis", flat_basis, 0.22)
		slam.tween_property(card_node, "global_position", target_global_position + Vector3(0, 0.02, 0), 0.22)
		slam.tween_property(card_node, "scale", field_scale, 0.22)

		card_manager.arrange_hand()

		tween.chain().tween_callback(func():
			if card_node.has_node("Area3D"):
				card_node.get_node("Area3D").input_ray_pickable = true
			
			if is_pie:
				if card_node.has_method("update_field_hp_display"):
					card_node.update_field_hp_display()
			else:
				# Non-Pies on board turn off pickable so they don't block table clicks once in discard pile
				if card_node.has_node("Area3D"):
					card_node.get_node("Area3D").input_ray_pickable = false
		)

	else:
		print("Field is full! Returning card to hand.")
		if card_node.has_method("_cancel_dragging"):
			card_node._cancel_dragging()

func activate_field_drop_zone(should_activate: bool):
	if has_node("FieldDropZone/CollisionShape3D"):
		$FieldDropZone/CollisionShape3D.disabled = !should_activate
