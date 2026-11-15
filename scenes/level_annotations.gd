@tool
extends Node2D

# tag -> [portal1Coords, portal2Coords]
var cell_data: Dictionary[Vector2i, BlockData]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _draw() -> void:
	var layer := get_parent() as TileMapLayer
	if layer == null:
		return
	
	var ANNOTATION_FONT: Font = ThemeDB.fallback_font
	const ANNOTATION_SIZE: int = 10
	
	for coords in cell_data:
		var data:BlockData = cell_data[coords]
		if data.cell_type_id != Constants.TELEPORTER or data.interaction_tag < 1:
			continue
		
		var center = layer.map_to_local(coords)
		var x_pos = center[0] 
		var y_pos = center[1] + (0.5 * Constants.CELL_SIZE)
		draw_string(ANNOTATION_FONT, Vector2i(x_pos, y_pos), str(data.interaction_tag), HORIZONTAL_ALIGNMENT_CENTER, Constants.CELL_SIZE, ANNOTATION_SIZE, Color.WHITE)
	
