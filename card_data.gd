extends Resource
class_name CardData

# (Keep your existing base variables like card_name, card_type, max_hp, card_art, etc. here)

@export_category("Pie specific details")
@export var is_half_art: bool = false
@export var pie_size: String = "Medium"
@export_multiline var passive_desc: String = ""

@export_group("Move 1")
@export var move1_name: String = ""
@export var move1_dmg: String = ""
@export_multiline var move1_desc: String = ""
@export var move1_is_equippable: bool = false
@export var move1_has_cooldown: bool = false

@export_group("Move 2")
@export var move2_name: String = ""
@export var move2_dmg: String = ""
@export_multiline var move2_desc: String = ""
@export var move2_is_equippable: bool = false
@export var move2_has_cooldown: bool = false
