class_name DiscardEffect
extends BaseEffect

@export var amount_to_discard: int = 1

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	print(source.name + " forces a discard of " + str(amount_to_discard) + " cards!")
	
	for i in range(amount_to_discard):
		if game_manager.player_hand.size() > 0:
			# Pick a random card from the hand
			var random_card = game_manager.player_hand.pick_random()
			
			# Remove it from the hand array
			game_manager.player_hand.erase(random_card)
			
			# Toss it into the graveyard visually and logically
			game_manager.discard_graveyard_pool.append(random_card)
			var tween = game_manager.create_tween()
			tween.tween_property(random_card, "global_position", game_manager.graveyard_marker.global_position, 0.3)
			tween.tween_property(random_card, "rotation", Vector3(0, 0, 0), 0.3)
			
			# Re-arrange the remaining hand so there isn't an empty gap!
			game_manager.card_manager.arrange_hand()
