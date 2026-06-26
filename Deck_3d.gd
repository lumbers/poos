extends Node3D

signal deck_clicked

var red_sleeve_material: StandardMaterial3D
var yellow_hover_material: StandardMaterial3D
var active_mesh: MeshInstance3D

var is_hovered: bool = false

func _ready():
	if has_node("Area3D"):
		$Area3D.mouse_entered.connect(_on_mouse_entered)
		$Area3D.mouse_exited.connect(_on_mouse_exited)
		$Area3D.input_event.connect(_on_input_event)
	
	for child in get_children():
		if child is MeshInstance3D:
			active_mesh = child
			break
	
	red_sleeve_material = StandardMaterial3D.new()
	red_sleeve_material.albedo_color = Color(0.8, 0.1, 0.15)
	
	yellow_hover_material = StandardMaterial3D.new()
	yellow_hover_material.albedo_color = Color(1.0, 0.85, 0.2)
	
	if active_mesh:
		active_mesh.material_override = red_sleeve_material
		
func _on_mouse_entered():
	if active_mesh:
		active_mesh.material_override = yellow_hover_material
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(2.1, 2.1, 2.1), 0.1)

func _on_mouse_exited():
	if active_mesh:
		active_mesh.material_override = red_sleeve_material
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(2.0, 2.0, 2.0), 0.1)

func _on_input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		deck_clicked.emit()
