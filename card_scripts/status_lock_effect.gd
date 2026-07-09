class_name StatusLockEffect
extends BaseEffect

@export_category("Status Locks")
@export var disable_attack: bool = false
@export var disable_switch: bool = false
@export var disable_draw: bool = false

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	# 1. Apply Pie-specific locks (Attack and Switch)
	if disable_attack and "can_attack" in target:
		target.can_attack = false
		print(target.name + " is paralyzed and cannot attack!")
		
	if disable_switch and "can_switch" in target:
		target.can_switch = false
		print(target.name + " is trapped and cannot switch!")
		
	# 2. Apply Player-wide locks (Drawing cards affects the player, not the Pie)
	if disable_draw:
		game_manager.player_can_draw = false
		print("Player is blinded/cursed and cannot draw cards!")
