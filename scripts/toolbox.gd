extends PanelContainer
class_name Toolbox


const cell_button_scene := preload("res://scenes/cell_button.tscn")


@export var cells: Dictionary[Vector2i, int] = {} 
@export var selected_cell: Vector2i = Constants.EMPTY


var button_group = ButtonGroup.new()


func _ready() -> void:
	#var cell_types = cells.keys()
	#cell_types.sort()
	#for cell_type in cell_types:
		#if cells[cell_type] > 0:
			#var cell_button = cell_button_scene.instantiate()
			#cell_button.button_group = button_group
	for child in $Buttons.get_children():
		child.button_group = button_group
		child.toggle_mode = true
		child.cell_selected.connect(_on_cell_selected)
		

func _on_cell_selected(cell_type: Vector2i):
	selected_cell = cell_type
