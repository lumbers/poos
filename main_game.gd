extends Node3D

@export var card_pool: Array[CardData] = []

@onready var deck_3d = $Deck3D
@onready var card_manager = $Camera3D/CardManager
# Change line 7 to look exactly like this:
@onready var camera_3d: Camera3D = $Camera3D

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
	
	# Turn off collision instantly so hovering mid-flight is IMPOSSIBLE
	if new_card.has_node("Area3D"):
		new_card.get_node("Area3D").input_ray_pickable = false
	
	add_child(new_card)
	new_card.global_position = deck_3d.global_position + Vector3(0, 0.1, 0)
	
	# --- THE FIXED LINE: FORCE START HORIZONTAL ---
	# This overrides the scene file's vertical posture the exact millisecond it spawns!
	new_card.global_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	# --- THE FLAT "SOUTH" SLIDE PATH ---
	var fly_past_target = deck_3d.global_position + Vector3(0, 0.1, 3)
	
	var fly_tween = create_tween().set_parallel(true)
	fly_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Keep it flat against the table surface (face down, sleeve up) throughout the whole motion
	var face_floor_rotation = Vector3(deg_to_rad(90), deck_3d.global_rotation.y, 0)
	
	fly_tween.tween_property(new_card, "global_position", fly_past_target, 0.3)
	fly_tween.tween_property(new_card, "global_rotation", face_floor_rotation, 0.3)
	
	fly_tween.chain().tween_callback(_add_to_hand_seamlessly.bind(new_card))
	
func _add_to_hand_seamlessly(card_node: Node3D):
	# 1. Instantly move the card into the hand manager folder
	card_node.get_parent().remove_child(card_node)
	card_manager.add_child(card_node)
	
	# 2. Reset rotation so it faces the camera perfectly
	card_node.rotation = Vector3.ZERO
	
	# 3. Forcibly push its starting position down below the screen 
	# so it physically slides UP into its fanned spot
	card_node.scale = Vector3(0.75, 0.75, 0.75) # Match the manager's baseline scale
	card_node.position = Vector3(0, card_manager.hand_y_offset - 1.5, card_manager.hand_z_depth)
	
	# 4. Simply call arrange_hand()! The manager's built-in tween 
	# will cleanly slide it up from the bottom gutter without any fighting.
	card_manager.arrange_hand()
	
	# 5. Safely turn collision back on right after the manager layout tween finishes (0.15s)
	var collision_timer = create_tween()
	collision_timer.tween_interval(0.15)
	collision_timer.tween_callback(func():
		if card_node.has_node("Area3D"):
			card_node.get_node("Area3D").input_ray_pickable = true
	)
