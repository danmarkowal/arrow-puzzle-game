extends Node2D
class_name Level


# Not all blocks are placable by the player
# Also using enums makes a better DevEx
enum PlacableBlock {
	USER_WALL,
	SPLITTER
}


const PLACABLE_ATLAS_COORDS: Dictionary[PlacableBlock, Vector2i] = {
	PlacableBlock.USER_WALL: Constants.USER_WALL,
	PlacableBlock.SPLITTER: Constants.SPLITTER,
}

# TODO: Replace this with something cleaner
const PLACABLE_BLOCKS: Dictionary[Vector2i, PlacableBlock] = {
	Constants.USER_WALL: PlacableBlock.USER_WALL,
	Constants.SPLITTER: PlacableBlock.SPLITTER,
}


static func get_block_atlas_coords(block: PlacableBlock):
	return PLACABLE_ATLAS_COORDS[block]
	
	
static func get_placable_block(atlas_coords: Vector2i):
	return PLACABLE_BLOCKS[atlas_coords]


@export var placable_blocks: Dictionary[PlacableBlock, int]


func _init() -> void:
	for block in PLACABLE_ATLAS_COORDS:
		placable_blocks.set(block, 0)
