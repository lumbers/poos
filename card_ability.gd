extends RefCounted
class_name CardAbility

# We pass main_game and the card node so the script can access your board variables
func execute_special_attack(main_game: Node3D, active_card: Node3D, move_num: int):
	pass

func execute_passive_effect(main_game: Node3D, card_node: Node3D):
	pass
