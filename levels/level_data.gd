@tool
extends Node

@export_tool_button("Scan level data") var scan_cells = scan_level_layer

# Per-cell data
@export
var interactable_cell_data: Dictionary[Vector2i, BlockData]

func scan_level_layer() -> void:
	# TODO: Verify non-safe function
	var layer := get_parent() as TileMapLayer
	
	# Remove tiles that are no longer there
	# Or are changed
	for tile_coords in interactable_cell_data.keys():
		var atlas_coords := layer.get_cell_atlas_coords(tile_coords)
#		# If cell type is no longer the same, remove
		if (interactable_cell_data[tile_coords].cell_type_id != atlas_coords):
			interactable_cell_data.erase(tile_coords)
	for tile_coords in layer.get_used_cells():
		# Get cell type
		var atlas_coords := layer.get_cell_atlas_coords(tile_coords)
		# TODO: Make this a list
		if (atlas_coords == Constants.TELEPORTER or atlas_coords == Constants.BUTTON):
			# Initialise new cells
			if not (tile_coords in interactable_cell_data):
				interactable_cell_data[tile_coords] = BlockData.new()
				interactable_cell_data[tile_coords].cell_type_id = atlas_coords
				interactable_cell_data[tile_coords].interaction_tag = -1
			pass
	
	# Refresh in inspector
	if Engine.is_editor_hint():
		notify_property_list_changed()
		EditorInterface.mark_scene_as_unsaved()
