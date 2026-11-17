extends Control

#const LEVEL_SELECT = preload()
const OPTIONS = preload("res://scenes/options_menu.tscn")
const CREDITS = preload("res://scenes/credits.tscn")

func _on_play_button_pressed() -> void:
	#_open(LEVEL_SELECT)
	pass

func _on_options_button_pressed() -> void:
	_open(OPTIONS)

func _on_credits_pressed() -> void:
	_open(CREDITS)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _open(scene: PackedScene) -> Control:
	var overlay: Control = scene.instantiate()
	add_child(overlay)
	$Container.process_mode = Node.PROCESS_MODE_DISABLED
	overlay.closed.connect(_close.bind(overlay))
	return overlay
	
func _close(overlay: Control) -> void:
	overlay.queue_free()
	$Container.process_mode = Node.PROCESS_MODE_INHERIT 
	
	
