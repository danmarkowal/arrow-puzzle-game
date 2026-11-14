@tool
extends Resource
class_name BlockData

@export var cell_type_id:Vector2i
# blocks with the same cell type and interaction tag will interact
# eg two portals with interaction tag 1, 2, 3, ...
@export var interaction_tag:int = -1 # -1 represents no interaction_tag 

# Could be helpful
@export var placed_by_user:bool = false
