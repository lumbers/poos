extends Node3D

@export var card_scene: PackedScene

@export var max_hand_width: float = 3.4
@export var card_spacing: float = 0.28
@export var hand_y_offset: float = -0.70
@export var hand_z_depth: float = -1.75
@export var fan_rotation_intensity: float = 1.5
var hovered_card_index: int = -1

func _ready():
	await get_tree().process_frame
	arrange_hand()

func arrange_hand():
	var cards = get_children()
	var card_count = cards.size()
	
	if card_count == 0:
		return
		
	var dynamic_spacing = card_spacing
	if (card_count - 1) * card_spacing > max_hand_width:
		dynamic_spacing = max_hand_width / (card_count - 1)
		
	var total_width = (card_count - 1) * dynamic_spacing
	var start_x = -total_width / 2.0
	
	# Keep track of how many dragging cards we've skipped so far
	var active_index_offset = 0
	
	for i in range(card_count):
		var card = cards[i]
		
		# --- FIXED: Skip this card entirely if it is currently being dragged ---
		if "is_dragging" in card and card.is_dragging:
			active_index_offset += 1
			continue
			
		# Calculate an adjusted grid position index to squeeze out the gaps
		var adjusted_index = i - active_index_offset
		
		var hover_push_offset = 0.0
		if hovered_card_index != -1 and i != hovered_card_index:
			var push_direction = 1.0 if i > hovered_card_index else -1.0
			hover_push_offset = push_direction * 0.22
			
		# FIXED: Swapped 'i' out for 'adjusted_index' across all vector layouts
		var target_x = start_x + (adjusted_index * dynamic_spacing) + hover_push_offset
		var curve_dip = (target_x * target_x) * -0.015
		var target_y = hand_y_offset + curve_dip
		var target_z = hand_z_depth + (adjusted_index * 0.01)
		
		var target_scale = Vector3(0.75, 0.75, 0.75)
		
		if i == hovered_card_index:
			target_y += 0.3
			target_z += 0.05
			target_scale = Vector3(0.85, 0.85, 0.85)
			
		var t = create_tween().set_parallel(true)
		t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(card, "position", Vector3(target_x, target_y, target_z), 0.15)
		t.tween_property(card, "scale", target_scale, 0.15)
		
		var pitch = 5.0
		var yaw = -target_x * fan_rotation_intensity
		var roll = -target_x * 1.5
		
		if i == hovered_card_index:
			pitch = 0.0
			yaw = 0.0
			roll = 0.0
			
		t.tween_property(card, "rotation_degrees", Vector3(pitch, yaw, roll), 0.15)
