@tool
extends Button
class_name CellButton


const cells_atlas := preload("res://resources/cells_atlas.tres")


var cell_colors: Dictionary[Vector2i, Color] = {
	Constants.SPLITTER: Color.from_string("#80d4ff", Color.WHITE),
	Constants.USER_WALL: Color.from_string("#ffdf80", Color.WHITE)
}


@export var cell_type: Vector2i
@export var count: int


signal cell_selected(cell_type: Vector2i)


func _ready() -> void:
	add_theme_color_override("icon_normal_color", get_cell_color(cell_type))
	var icon_texture = cells_atlas.duplicate()
	icon_texture.region.position = Vector2(cell_type * Constants.CELL_SIZE)
	icon = icon_texture
	$CountLabel.text = "x%s" % count


func _on_pressed() -> void:
	cell_selected.emit(cell_type)


func get_cell_color(cell_type: Vector2i):
	return cell_colors.get(cell_type, Color.WHITE)
