extends TileMapLayer

@export var highlight_colour = Color(1, 0, 0, 0.5)

var highlighted_cells: Array[Rect2]
var moving_positions: Array[Vector2]
var moving_positions_last: Vector2
var dragging_cells : bool = false

func set_highlighted_cells(new_cells: Array[Rect2]) -> void:
	highlighted_cells = new_cells
	queue_redraw()
	
func clear_highlighted_cells() -> void:
	highlighted_cells.clear()
	queue_redraw()

func is_cells_selected() -> bool:
	return not highlighted_cells.is_empty()

func in_selected_cells(point: Vector2) -> bool:
	for cell in highlighted_cells:
		if cell.has_point(point):
			return true
	return false

func start_moving_cells(start: Vector2) -> void:
	dragging_cells = true
	moving_positions_last = start
	moving_positions.clear()
	for cell in highlighted_cells:
		moving_positions.push_back(cell.position)
	
func move_selected_cells(pos: Vector2) -> void:
	for i in moving_positions.size():
		moving_positions[i] += pos - moving_positions_last
		var cell = local_to_map(moving_positions[i])
		highlighted_cells[i].position = map_to_local(cell) - Vector2(tile_set.tile_size) / 2
	moving_positions_last = pos
	queue_redraw()

func stop_moving_cells() -> void:
	dragging_cells = false
	clear_highlighted_cells()

func _draw() -> void:
	for cell in highlighted_cells:
		draw_rect(cell, highlight_colour)
