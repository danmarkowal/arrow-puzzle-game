extends HBoxContainer


signal play
signal pause
signal restart
signal clear


func _on_play_button_pressed() -> void:
	play.emit()


func _on_pause_button_pressed() -> void:
	pause.emit()
	
	
func _on_restart_button_pressed() -> void:
	restart.emit()


func _on_clear_button_pressed() -> void:
	clear.emit()
