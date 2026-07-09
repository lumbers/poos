class_name HPModifierEffect
extends BaseEffect

@export_category("Effect Settings")
@export_enum("Heal Target", "Damage Target") var modification_type: String = "Heal Target"
@export var amount: int = 50

func execute_effect(source: Node3D, target: Node3D, game_manager: Node3D):
	# Make sure the target is actually a pie!
	if not target.has_method("take_damage"):
		return 
		
	if modification_type == "Heal Target":
		print("Healing target for " + str(amount))
		target.heal_pie(amount)
	else:
		print("Damaging target for " + str(amount))
		target.take_damage(amount)
