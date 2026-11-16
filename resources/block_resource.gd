extends Resource
class_name BlockResource


enum BlockType {
	OBSTACLE,
	INTERACTABLE
}


# This is like the ID of the block
@export var atlas_coords: Vector2i
# The name in Title Case
@export var name: String
# The type detemines which layer the block is placed on
@export var type: BlockType
# Whether this block is placeable by the player
@export var placeable: bool
# Rotatable blocks must have alternative tiles set
@export var rotatable: bool
