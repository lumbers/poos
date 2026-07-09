class_name DrawCardsEffect
extends BaseEffect

@export var amount_to_draw: int = 1

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	print(source.name + " triggered a Draw Effect! Drawing " + str(amount_to_draw) + " cards.")
	
	# Loop and trigger the draw logic
	for i in range(amount_to_draw):
		# A tiny delay so the cards don't visually clip through each other in the air
		await game_manager.get_tree().create_timer(0.2).timeout
		game_manager._on_deck_clicked()
