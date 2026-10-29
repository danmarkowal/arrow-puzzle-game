@tool
extends Button
class_name CellButton


const CELLS_ATLAS := preload("res://resources/cells_atlas.tres")


var block_colors: Dictionary[Level.PlacableBlock, Color] = {
	Level.PlacableBlock.SPLITTER: Color.from_string("#80d4ff", Color.WHITE),
	Level.PlacableBlock.USER_WALL: Color.from_string("#ffdf80", Color.WHITE)
}


@export var block_type: Level.PlacableBlock


signal block_selected(block_type: Level.PlacableBlock)


func _ready() -> void:
	# Set icon texture
	var icon_texture = CELLS_ATLAS.duplicate()
	add_theme_color_override("icon_normal_color", get_block_color(block_type))
	var atlas_coords = Level.get_block_atlas_coords(block_type)
	icon_texture.region.position = Vector2(atlas_coords * Constants.CELL_SIZE)
	icon = icon_texture
	
	# Default
	display_count(0)


func get_block_color(block_type: Level.PlacableBlock):
	return block_colors.get(block_type, Color.WHITE)


func display_count(p_count: int):
	$CountLabel.text = "x%s" % p_count


func _on_pressed() -> void:
	block_selected.emit(block_type)
