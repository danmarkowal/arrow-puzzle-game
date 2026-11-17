extends Node2D
class_name Level


@export var block_counts: Dictionary[BlockResource, int]
@export_multiline var notes: String


func init() -> void:
	for block in block_counts.keys():
		var count = block_counts[block]
		if not block.placeable:
			push_error("Block '", block.name, "' is not placeable by the player")
		if not is_count_valid(count):
			push_error("Block '", block.name, "' has an invalid count of ", count)


func is_count_valid(count: int) -> bool:
	return count > 0 and count < 1000
