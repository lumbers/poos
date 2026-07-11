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
@export var entry_effect: BaseEffect # Triggers when the pie is placed on the board!

@export_category("Pie Specific Details")
@export var is_half_art: bool = false
@export var force_text_on_full_art: bool = false # Check this for Ghidorah!
@export var is_boss: bool = false # Check this to make it cost 3 discards
@export var pie_size: String = "Medium"
@export_multiline var passive_desc: String = ""

@export_category("Move 1")
@export var move1_name: String = ""
@export var move1_dmg: String = ""
@export_multiline var move1_desc: String = ""
@export var move1_targets: int = 1 # <--- ADD THIS
@export var move1_is_equippable: bool = false
@export var move1_has_cooldown: bool = false

@export_category("Move 2")
@export var move2_name: String = ""
@export var move2_dmg: String = ""
@export_multiline var move2_desc: String = ""
@export var move2_targets: int = 1 # <--- ADD THIS
@export var move2_is_equippable: bool = false
@export var move2_has_cooldown: bool = false

@export_category("Domain Specific")
@export var domain_duration: int = 3
@export var domain_environment: Environment  # drag your .tres env file here
@export var domain_model: PackedScene  # drag the imported .glb here
@export var domain_intro_sound: AudioStream   # ryoiki tenkai sfx
@export var domain_bgm: AudioStream           # looping background music
@export var domain_has_slash_vfx: bool = false

# Inside card_data.gd
@export_category("Custom Ability Scripts")
@export var custom_ability_script: Script # Drag your psychic_pie_ability.gd or slave_ability.gd file here!
