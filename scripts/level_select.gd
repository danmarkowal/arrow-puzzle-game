extends HBoxContainer
class_name LevelSelect


signal previous
signal next


func _on_previous_level_pressed() -> void:
	previous.emit()


func _on_next_level_pressed() -> void:
	next.emit()
