# ghost_slot.gd
extends Area3D

@onready var mesh_instance = $MeshInstance3D

# Customize your feedback colors here!
var neutral_color = Color(1, 1, 1, 0.25)   # Semi-transparent white
var hover_color = Color(0, 0.8, 0.3, 0.45) # Highlighted semi-transparent green
@export var slot_index: int = -1            # -1 for Active, 0, 1, 2 for Bench
@export var is_active_slot: bool = false

func _ready():
	# Ensure transparency is running on our unique material instance
	if mesh_instance.get_active_material(0):
		mesh_instance.get_active_material(0).albedo_color = neutral_color
	
	# Wire up local mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# We only highlight if the main game says the player is actively dragging a Pie!
	var main_game = get_node_or_null("/root/MainGame")
	if main_game and main_game.get("is_dragging_pie") == true:
		set_slot_highlight(true)
		main_game.current_hovered_ghost_slot = self

func _on_mouse_exited():
	set_slot_highlight(false)
	var main_game = get_node_or_null("/root/MainGame")
	if main_game and main_game.current_hovered_ghost_slot == self:
		main_game.current_hovered_ghost_slot = null

func set_slot_highlight(is_hovered: bool):
	var mat = mesh_instance.get_active_material(0)
	if mat:
		mat.albedo_color = hover_color if is_hovered else neutral_color
