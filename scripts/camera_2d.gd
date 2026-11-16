extends Camera2D

class_name InputCam

@export var drag_speed = 100.0
@export var margin_factor = 0.8
@export var max_zoom = 0.5
@export var min_zoom = 1.0
@export var zoom_increment = 0.1
@export var scroll_speed = 0.3

var start_camera_pos : Vector2
var last_mouse_pos : Vector2
var min_margin : Vector2
var max_margin : Vector2
var scroll_length = 0.0

func _ready() -> void:
	zoom = Vector2(min_zoom, min_zoom)

func _process(delta: float) -> void:
	var max_zoom_vec = Vector2(max_zoom, max_zoom)
	var min_zoom_vec = Vector2(min_zoom, min_zoom)
	var zoom_increment_vec = Vector2(zoom_increment, zoom_increment)
	
	if Input.is_action_just_pressed("CameraDragKeyboard") or \
	 Input.is_action_just_pressed("CameraDragMousepad") or \
	 Input.is_action_just_pressed("CameraDragMouse"):
		last_mouse_pos = get_local_mouse_position()
	elif is_dragging():
		var new_pos = get_local_mouse_position()
		position -= (new_pos - last_mouse_pos) * drag_speed * delta
		position = position.clamp(min_margin, max_margin)
		last_mouse_pos = new_pos
	elif Input.is_action_pressed("CameraReset"):
		global_position = start_camera_pos
		zoom = min_zoom_vec
		last_mouse_pos = get_local_mouse_position()
	elif Input.is_action_just_pressed("CameraZoomInKeyboard"):
		zoom += zoom_increment_vec
	elif Input.is_action_just_pressed("CameraZoomOutKeyboard"):
		zoom -= zoom_increment_vec
	elif Input.is_action_just_pressed("CameraZoomInScroll") or \
	 Input.is_action_just_pressed("CameraZoomOutScroll"):
		scroll_length = 0.0
	elif Input.is_action_pressed("CameraZoomInScroll"):
		var last_zoom = int(scroll_length / scroll_speed)
		scroll_length += delta
		if int(scroll_length / scroll_speed) > last_zoom:
			zoom += zoom_increment_vec
	elif Input.is_action_pressed("CameraZoomOutScroll"):
		var last_zoom = int(scroll_length / scroll_speed)
		scroll_length -= delta
		if int(scroll_length / scroll_speed) < last_zoom:
			zoom -= zoom_increment_vec
	zoom = zoom.min(min_zoom_vec).max(max_zoom_vec) 

func set_camera(used_rect: Rect2) -> void:
	zoom = Vector2.ONE
	last_mouse_pos = get_local_mouse_position()
	
	var centre = used_rect.get_center()
	start_camera_pos = centre
	global_position = centre
	
	var viewport_rect = get_viewport_rect()
	viewport_rect.position = centre - viewport_rect.get_center()

	var bounding_rect = (viewport_rect if viewport_rect.encloses(used_rect) else \
	 used_rect)
	
	var rect_centre = bounding_rect.get_center()
	var to_top_left = bounding_rect.position - rect_centre
	min_margin = rect_centre + to_top_left * margin_factor
	max_margin = rect_centre - to_top_left * margin_factor
		
func is_dragging() -> bool:
	return (Input.is_action_pressed("CameraDragKeyboard") and Input.is_action_pressed("CameraDragMousepad")) \
		or Input.is_action_pressed("CameraDragMouse")
		