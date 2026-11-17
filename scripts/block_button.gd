@tool
extends Button
class_name ButtonBlock


const CELLS_ATLAS := preload("res://resources/cells_atlas.tres") as AtlasTexture
const CELLS_TILE_SET := preload("res://resources/maze_tile_set.tres") as TileSet


@export var block: BlockResource


signal block_selected(block: BlockResource)


func _ready() -> void:
	# Set icon color based on the modulate color from the tile set
	var src: TileSetAtlasSource = CELLS_TILE_SET.get_source(0)
	# Assume that all alternative tiles have the same color
	var data := src.get_tile_data(block.atlas_coords, 0)
	var color := data.modulate
	# I don't know any other way of setting these all at once
	add_theme_color_override("icon_normal_color", color)
	add_theme_color_override("icon_hover_color", color)
	add_theme_color_override("icon_pressed_color", color)
	add_theme_color_override("icon_hover_pressed_color", color)
	
	# Set icon texture
	var icon_texture: AtlasTexture = CELLS_ATLAS.duplicate()

	icon_texture.region.position = Vector2(block.atlas_coords * Constants.CELL_SIZE)
	icon = icon_texture
	tooltip_text = block.name


func display_count(p_count: int):
	$CountLabel.text = "x%s" % p_count


func _on_pressed() -> void:
	block_selected.emit(block)
