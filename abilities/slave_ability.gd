extends CardAbility

func execute_passive_effect(main_game: Node3D, card_node: Node3D):
	# This holds the code to alter the drawing count rule
	print("Slave Construct passive calculated out of external class file.")
	return 2 # Return 2 loops to draw instead of 1
