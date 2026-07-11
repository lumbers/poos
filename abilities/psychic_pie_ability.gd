extends CardAbility

var meteor_scene = preload("res://psychic_meteor.tscn")

func execute_special_attack(main_game: Node3D, active_card: Node3D, move_num: int):
	var card_data = active_card.card_info
	var move_name = card_data.move1_name if move_num == 1 else card_data.move2_name
	
	if move_name.to_lower().strip_edges() == "psychic meteor":
		# Trigger the cinematic camera return
		main_game.attack_overlay.visible = false
		main_game.current_energy -= 1
		main_game.has_attacked_this_turn = true
		main_game.update_hud_display()
		
		var cam_tween = main_game.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(main_game.camera_3d, "global_position", main_game.original_camera_pos, 1.2)
		cam_tween.tween_property(main_game.camera_3d, "rotation", main_game.original_camera_rot, 1.2)
		
		cam_tween.chain().tween_callback(func():
			main_game.is_in_attack_phase = false
			if main_game.has_node("UI"): main_game.get_node("UI").visible = true
			spawn_psychic_meteor_strike(main_game)
		)
		return true # Tell main_game that this move was intercepted and handled here!
	return false

func spawn_psychic_meteor_strike(main_game: Node3D):
	var target_center = Vector3(0, 0.05, -1.8) 
	if main_game.opponent_active_card:
		target_center = main_game.opponent_active_card.global_position
		
	var start_pos = target_center + Vector3(-5.0, 8.0, -4.0)
	var meteor = meteor_scene.instantiate()
	main_game.add_child(meteor)
	meteor.scale = Vector3(3, 3, 3)
	meteor.global_position = start_pos
	meteor.look_at(target_center, Vector3.UP)
	
	var tween = main_game.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(meteor, "global_position", target_center, 0.65)
	
	tween.chain().tween_callback(func():
		for node in main_game.get_children():
			if node.get("is_opponent") == true and node.get("is_on_board") == true:
				if node.has_method("take_damage"):
					node.take_damage(150, node.global_position)
				
		if main_game.sfx_player:
			main_game.sfx_player.stream = main_game.lightning_sound
			main_game.sfx_player.play()
			
		if main_game.boss_vignette:
			main_game.boss_vignette.modulate = Color(1.5, 0.5, 2.0, 1.0) 
			var flash_fade = main_game.create_tween()
			flash_fade.tween_property(main_game.boss_vignette, "modulate", Color(1, 1, 1, 1), 0.4)
			
		main_game.trigger_camera_shake(0.3, 0.6)
		meteor.queue_free()
)
