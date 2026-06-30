extends Node3D

@onready var mesh_instance = $MeshInstance3D
@onready var area = $Area3D

var neutral_color = Color(1, 1, 1, 0.25)
var hover_color = Color(0, 0.8, 0.3, 0.45)

@export var slot_index: int = -1
@export var is_active_slot: bool = false

func _ready():
	# Create a UNIQUE material per instance so highlights don't bleed across all slots
	var unique_mat = StandardMaterial3D.new()
	unique_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	unique_mat.albedo_color = neutral_color
	mesh_instance.set_surface_override_material(0, unique_mat)
	
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	area.input_event.connect(_on_input_event)

# NEW FUNCTION: Tell the main game when an empty slot is clicked!
@warning_ignore("unused_parameter")
func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main_game = get_node_or_null("/root/MainGame")
		if main_game and main_game.has_method("handle_ghost_slot_clicked"):
			main_game.handle_ghost_slot_clicked(self)

func _on_mouse_entered():
	var main_game = get_node_or_null("/root/MainGame")
	if main_game and main_game.get("is_dragging_pie") == true:
		set_slot_highlight(true)
		main_game.current_hovered_ghost_slot = self

func _on_mouse_exited():
	set_slot_highlight(false)
	var main_game = get_node_or_null("/root/MainGame")
	if main_game and main_game.current_hovered_ghost_slot == self:
		main_game.current_hovered_ghost_slot = null

func set_slot_highlight(is_highlighted: bool):
	var mat = mesh_instance.get_surface_override_material(0)
	if mat:
		mat.albedo_color = hover_color if is_highlighted else neutral_color
