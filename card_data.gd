extends Resource
class_name CardData

@export_category("Base Card Info")
@export var card_name: String = ""
@export var card_type: String = "PIE"
@export var max_hp: int = 0
@export var attribute: String = ""
@export var card_art: Texture2D
@export var use_full_paper_image: bool = false
@export_multiline var passives_and_attacks: String = "" # Keeping this so your old cards don't break!

@export_category("Pie Specific Details")
@export var is_half_art: bool = false
@export var force_text_on_full_art: bool = false # Check this for Ghidorah!
@export var is_boss: bool = false # Check this to make it cost 3 discards
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
