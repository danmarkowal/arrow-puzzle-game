extends Resource
class_name BlockRegistry

@export var blocks: Array[BlockResource]

var _atlas_lookup: Dictionary[Vector2i, BlockResource] = {}
var _lookup_built := false


func get_block(atlas_coords: Vector2i) -> BlockResource:
	if not _lookup_built:
		_build_lookup()
	return _atlas_lookup.get(atlas_coords)


func _build_lookup() -> void:
	_atlas_lookup.clear()
	for block in blocks:
		if block.atlas_coords in _atlas_lookup:
			push_error(
				"Duplicate block entry in block registry with atlas coords %s"
				% [block.atlas_coords]
			)
		_atlas_lookup[block.atlas_coords] = block
	_lookup_built = true
