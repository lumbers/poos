# draw_cards_effect.gd
class_name DrawCardsEffect
extends BaseEffect

@export var amount_to_draw: int = 1

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	print(source.card_info.card_name + " is drawing " + str(amount_to_draw) + " cards!")
	
	# Loop and trigger the exact same draw logic you already built in main_game.gd!
	for i in range(amount_to_draw):
		# We use a tiny delay so the cards don't visually overlap while flying to hand
		await game_manager.get_tree().create_timer(0.2).timeout
		game_manager._on_deck_clicked()
