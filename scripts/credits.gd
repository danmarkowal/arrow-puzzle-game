extends Control
signal closed

func _on_back_pressed() -> void:
	closed.emit()
