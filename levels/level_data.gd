@tool
extends Node

@export_tool_button("Scan level data") var scan_cells = scan_level_layer

# Per-cell data
@export
var interactable_cell_data: Dictionary[Vector2i, BlockData]

func scan_level_layer() -> void:
	# TODO: Verify non-safe function
	var layer := get_parent() as TileMapLayer
	if layer == null:
		push_error("LevelData must be a child of a TileMapLayer")
		return
		
	# We have to make a new dict and then replace for godot to realise the property changed
	var new_dict: Dictionary[Vector2i, BlockData] = {}
	
	for tile_coords in layer.get_used_cells():
		var atlas_coords := layer.get_cell_atlas_coords(tile_coords)
		# Skip non-interactable blocks - TODO: Make this a list
		if not (atlas_coords == Constants.TELEPORTER or atlas_coords == Constants.BUTTON):
			continue
		
		var existing_data:BlockData = interactable_cell_data.get(tile_coords)
		if (existing_data != null and atlas_coords == existing_data.cell_type_id):
			# Unchanged block
			new_dict[tile_coords] = existing_data
		else:
			# New/changed block
			var block = BlockData.new()
			block.cell_type_id = atlas_coords
			block.interaction_tag = -1
			new_dict[tile_coords] = block
			
	
	interactable_cell_data = new_dict
	
	# Refresh in inspector
	if Engine.is_editor_hint():
		notify_property_list_changed()
		EditorInterface.mark_scene_as_unsaved()
