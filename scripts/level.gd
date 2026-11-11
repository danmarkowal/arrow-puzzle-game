extends Node2D
class_name Level


# Not all blocks are placeable by the player
# Also using enums makes a better DevEx
enum PlaceableBlock {
	USER_WALL,
	SPLITTER,
	TELEPORTER
}


const PLACEABLE_ATLAS_COORDS: Dictionary[PlaceableBlock, Vector2i] = {
	PlaceableBlock.USER_WALL: Constants.USER_WALL,
	PlaceableBlock.SPLITTER: Constants.SPLITTER,
	PlaceableBlock.TELEPORTER: Constants.TELEPORTER
}

# TODO: Replace this with something cleaner
const PLACEABLE_BLOCKS: Dictionary[Vector2i, PlaceableBlock] = {
	Constants.USER_WALL: PlaceableBlock.USER_WALL,
	Constants.SPLITTER: PlaceableBlock.SPLITTER,
	Constants.TELEPORTER: PlaceableBlock.TELEPORTER
}


static func get_block_atlas_coords(block: PlaceableBlock):
	return PLACEABLE_ATLAS_COORDS[block]
	
	
static func get_placeable_block(atlas_coords: Vector2i):
	return PLACEABLE_BLOCKS[atlas_coords]


@export var placeable_blocks: Dictionary[PlaceableBlock, int]
@export_multiline var notes: String


func _init() -> void:
	#for block in PLACEABLE_ATLAS_COORDS:
		#placeable_blocks.set(block, 0)
	pass
