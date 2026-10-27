extends Node2D
class_name Level


enum UserCells {
	SPLITTER,
	WALL
}


@export var allowed_cells: Dictionary[UserCells, int]
