extends Control
signal resumed

#const LEVEL_SELECT = preload()
const OPTIONS = preload("res://scenes/options_menu.tscn")
const CONFIRM_DIALOG = preload("res://scenes/confirmation_message.tscn")

#func _unhandled_input(event: InputEvent) -> void:
#	if event.is_action_pressed("pause") and overlay == null:
#		resumed.emit()
#		get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	resumed.emit()

func _on_level_select_pressed() -> void:
	#_open(LEVEL_SELECT)
	pass # Replace with function body.

func _on_options_pressed() -> void:
	_open(OPTIONS)

func _on_main_menu_pressed() -> void:
	var confirm = _open(CONFIRM_DIALOG)
	confirm.confirmed.connect(_on_main_menu_confirmed)

func _on_main_menu_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _open(scene: PackedScene) -> Control:
	var overlay: Control = scene.instantiate()
	add_child(overlay)
	$Container.process_mode = Node.PROCESS_MODE_DISABLED
	overlay.closed.connect(_close.bind(overlay))
	return overlay
	
func _close(overlay: Control) -> void:
	overlay.queue_free()
	overlay = null
	$Container.process_mode = Node.PROCESS_MODE_INHERIT 
