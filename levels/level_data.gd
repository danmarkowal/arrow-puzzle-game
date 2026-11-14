@tool
extends Node

@export_tool_button("Scan level data") var scan_cells = scan_level_layer

# Per-cell data
@export
var cell_data: Dictionary[Vector2i, BlockData]

func scan_level_layer() -> void:
	# TODO: Verify non-safe function
	var layer := get_parent() as TileMapLayer
	for tile_coords in layer.get_used_cells():
		print("Tile at ", tile_coords)
		var atlas_coords = layer.get_cell_atlas_coords(tile_coords)
		if atlas_coords == Constants.WALL:
			continue
		
		# If tile already exists in the cell data (i.e is not new),
		# We don't need to initialise it.
		if not (tile_coords in cell_data and cell_data[tile_coords].cell_type_id == atlas_coords):
			cell_data[tile_coords] = BlockData.new()
			cell_data[tile_coords].cell_type_id = atlas_coords
			cell_data[tile_coords].interaction_tag = -1
		pass
		
	print("Scanned cells")
	pass
