extends PanelContainer

signal level_chosen(scene_index: int)

const LEVEL_COUNT = 6
const MIN_CELL_SIZE = Vector2(55, 55)

@onready var grid = $VBoxContainer/MarginContainer/GridContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	toggle_visibility()
	var original_width = $VBoxContainer.size.x
	for i in range(LEVEL_COUNT):
		var button := Button.new()
		button.text = "Level " + str(i + 1)
		button.custom_minimum_size = MIN_CELL_SIZE
		button.pressed.connect(_on_button_pressed.bind(i))
		grid.add_child(button)
	await get_tree().process_frame
	position.x -= abs($VBoxContainer/MarginContainer.size.x - original_width)
	
func _on_button_pressed(index: int) -> void:
	level_chosen.emit(index)
	toggle_visibility()

func toggle_visibility() -> void:
	visible = not visible
