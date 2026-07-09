class_name DamageModifierEffect
extends BaseEffect

@export var bonus_damage: int = 20

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	# Add the buff to the target Pie
	if "current_damage_buff" in target:
		target.current_damage_buff += bonus_damage
		print(target.name + " gained " + str(bonus_damage) + " bonus damage!")
		
		# Optional: Spawn a cool floating text to show the buff!
		if target.has_method("spawn_healing_number"):
			target.spawn_healing_number(bonus_damage) # Reusing green text for a buff!
