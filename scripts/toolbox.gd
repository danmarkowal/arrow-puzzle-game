extends VBoxContainer
class_name Toolbox


var selected_cell: Vector2i = Constants.EMPTY


func _on_texture_button_pressed() -> void:
	selected_cell = Constants.SPLITTER
	


func _on_texture_button_pressed2() -> void:
	selected_cell = Constants.USER_WALL
