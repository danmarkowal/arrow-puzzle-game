extends Camera2D

class_name InputCam

@export var drag_speed = 100.0
@export var margin_factor = 0.8

var first_pos : Vector2
var last_pos : Vector2
var min_margin : Vector2
var max_margin : Vector2

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("CameraDragKeyboard") or \
	 Input.is_action_just_pressed("CameraDragMousepad") or \
	 Input.is_action_just_pressed("CameraDragMouse"):
		last_pos = get_local_mouse_position()
	elif is_dragging():
		var new_pos = get_local_mouse_position()
		position -= (new_pos - last_pos) * drag_speed * delta
		position = position.clamp(min_margin, max_margin)
		last_pos = new_pos
	elif Input.is_action_pressed("CameraReset"):
		global_position = first_pos
		last_pos = get_local_mouse_position()

func set_camera(pos: Vector2) -> void:
	first_pos = pos
	global_position = pos
	last_pos = get_local_mouse_position()
	
	var to_bottom_right = get_viewport_rect().size / 2
	min_margin = pos - to_bottom_right * margin_factor
	max_margin = pos + to_bottom_right * margin_factor
		
		
func is_dragging() -> bool:
	return (Input.is_action_pressed("CameraDragKeyboard") and Input.is_action_pressed("CameraDragMousepad")) \
		or Input.is_action_pressed("CameraDragMouse")
		
		
