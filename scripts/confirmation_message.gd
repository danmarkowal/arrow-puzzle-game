extends Control
signal closed
signal confirmed

func _on_yes_pressed() -> void:
	confirmed.emit()

func _on_no_pressed() -> void:
	closed.emit()
