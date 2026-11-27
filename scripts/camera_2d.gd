extends Camera2D
class_name InputCam

@export var margin_factor := 0.8
@export var max_zoom := 1.0
@export var min_zoom := 0.4
@export var zoom_increment := 0.1

var start_camera_pos: Vector2
var last_mouse_pos: Vector2
var min_margin: Vector2
var max_margin: Vector2
var scroll_length := 0.0
var level_zoom := 1.0

func _ready() -> void:
	reset_zoom()

func _process(delta: float) -> void:
	var zoom_increment_vec = Vector2(zoom_increment, zoom_increment)
	
	if Input.is_action_just_pressed("CameraDragKeyboard") or \
		Input.is_action_just_pressed("CameraDragMouse"):
		last_mouse_pos = get_local_mouse_position()
	elif is_dragging():
		var new_pos = get_local_mouse_position()
		position -= (new_pos - last_mouse_pos)
		position = position.clamp(min_margin, max_margin)
		last_mouse_pos = new_pos
	elif Input.is_action_pressed("CameraReset"):
		global_position = start_camera_pos
		last_mouse_pos = get_local_mouse_position()
		reset_zoom()
	elif Input.is_action_just_pressed("CameraZoomInKeyboard"):
		zoom += zoom_increment_vec
	elif Input.is_action_just_pressed("CameraZoomOutKeyboard"):
		zoom -= zoom_increment_vec
	clamp_zoom()
	
func _input(event: InputEvent) -> void:
	var zoom_increment_vec = Vector2(zoom_increment, zoom_increment)
	if event.is_action("CameraZoomInScroll"):
		zoom += zoom_increment_vec
	elif event.is_action("CameraZoomOutScroll"):
		zoom -= zoom_increment_vec
	clamp_zoom()

func set_camera(used_rect: Rect2) -> void:
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
	
	var level_size = bounding_rect.size
	var viewport_size = get_viewport_rect().size
	level_zoom = min(viewport_size.x / level_size.x, viewport_size.y / level_size.y)
	# Round down to the nearest increment
	level_zoom -= fmod(level_zoom, zoom_increment)
	reset_zoom()
	
func reset_zoom() -> void:
	zoom = Vector2(level_zoom, level_zoom)
	clamp_zoom()

func clamp_zoom() -> void:
	var max_zoom_vec = Vector2(max_zoom, max_zoom)
	var min_zoom_vec = Vector2(min_zoom, min_zoom)
	zoom = zoom.clamp(min_zoom_vec, max_zoom_vec)

func is_dragging() -> bool:
	return (Input.is_action_pressed("CameraDragKeyboard") \
		or Input.is_action_pressed("CameraDragMouse"))
