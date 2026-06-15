extends Resource
class_name CardData

# CHECK THIS BOX IF THE IMAGE IS A FULL PRE-MADE PAPER CARD!
@export var use_full_paper_image: bool = false

@export var card_name: String = "Name"
@export var card_type: String = "pie"
@export var max_hp: int = 100
@export var attribute: String = "med"
@export_multiline var passives_and_attacks: String = ""
@export var card_art: Texture2D
