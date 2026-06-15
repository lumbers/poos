extends Node3D

# Drop your sanic.tres file into this slot in the inspector later!
@export var card_info: CardData
@onready var preview_panel = get_node("/root/MainGame/CanvasLayer/CardPreviewPanel")
# --- NEW HOVER CONTROLS ---
var default_position: Vector3
var is_hovered: bool = false

func _ready():
	# Wait one frame to make sure everything is fully loaded
	await get_tree().process_frame
	
	if card_info != null:
		load_card_data()
	$Area3D.mouse_entered.connect(_on_mouse_entered)
	$Area3D.mouse_exited.connect(_on_mouse_exited)
	
func load_card_data():
	var template = $MeshInstance3D/SubViewport/PieTemplate
	
	# ==========================================================
	# RULE 1: FULL PAPER CARDS (Like Fireball)
	# ==========================================================
	if card_info.use_full_paper_image == true:
		template.get_node("Label").visible = false
		template.get_node("NameHP").visible = false
		template.get_node("RichTextLabel").visible = false
		template.get_node("Label3").visible = false
		
		var art_rect = template.get_node("TextureRect")
		art_rect.position = Vector2(0, 0)
		art_rect.size = Vector2(350, 500)
		
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		
		if card_info.card_art != null:
			art_rect.texture = card_info.card_art

	# ==========================================================
	# RULE 2: SYSTEM CARDS (Dynamic Layouts like Sanic)
	# ==========================================================
	else:
		# Reset visibility defaults
		template.get_node("Label").visible = true
		template.get_node("RichTextLabel").visible = true
		template.get_node("Label3").visible = true
		template.get_node("NameHP").visible = true
		
		var art_rect = template.get_node("TextureRect")
		art_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		if card_info.card_art != null:
			art_rect.texture = card_info.card_art
			
		# Set type text and attribute
		template.get_node("Label").text = card_info.card_type
		template.get_node("Label3").text = card_info.attribute
		
		# ---- THE PIE TYPE SPARK CHECK ----
		# Convert the text to all lowercase so "Pie", "PIE", or "pie" all count!
		var type_check = card_info.card_type.to_lower()
		
		if type_check == "pie":
			# Normal Pie Card: Show Name and HP normally, text aligned left
			template.get_node("NameHP").text = card_info.card_name + "  HP:" + str(card_info.max_hp)
			template.get_node("NameHP").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			# Raw attack text with black outline formatting
			var raw_text = card_info.passives_and_attacks
			template.get_node("RichTextLabel").text = "[outline_size=5][outline_color=black]" + raw_text + "[/outline_color][/outline_size]"
		
		else:
			# Non-Pie Card (Spesh, Trap, Item, Spell, etc.)
			# 1. Hide the HP entirely and center the Name string in the middle of the box
			template.get_node("NameHP").text = card_info.card_name
			template.get_node("NameHP").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			# 2. Grab the attack text, center it using BBCode [center] tags, and apply outlines
			var raw_text = card_info.passives_and_attacks
			template.get_node("RichTextLabel").text = "[outline_size=5][outline_color=black][center]" + raw_text + "[/center][/outline_color][/outline_size]"
# --- SMOOTH TWEEN ANIMATIONS ---
func _on_mouse_entered():
	if card_info == null or get_parent() == get_node("/root/MainGame"):
		return
		
	is_hovered = true
	
	# Pass layout management entirely to the manager
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		manager.hovered_card_index = get_index()
		manager.arrange_hand()

func _on_mouse_exited():
	if !is_hovered:
		return
	is_hovered = false
	
	if preview_panel:
		preview_panel.visible = false
		
	var manager = get_parent()
	if manager and manager.has_method("arrange_hand"):
		if manager.hovered_card_index == get_index():
			manager.hovered_card_index = -1
			manager.arrange_hand()
