extends TileMapLayer

@export var highlight_block_colour = Color(1, 0, 0, 0.5)
@export var select_window_colour = Color(0.15294118,0.83137255,0.92156863,0.5)

var select_rect: Rect2
var highlighted_cells: Array[Rect2]
var moving_positions: Array[Vector2]
var moving_positions_last: Vector2
var dragging_cells : bool = false

func set_render_targets(rect: Rect2, new_cells: Array[Rect2]) -> void:
	select_rect = rect
	highlighted_cells = new_cells
	queue_redraw()

func clear_render_targets() -> void:
	select_rect.size = Vector2.ZERO
	highlighted_cells.clear()
	queue_redraw()

func clear_highlighted_cells() -> void:
	highlighted_cells.clear()
	queue_redraw()

func clear_select_rect() -> void:
	select_rect.size = Vector2.ZERO
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
	clear_render_targets()

func _draw() -> void:
	for cell in highlighted_cells:
		draw_rect(cell, highlight_block_colour)
	draw_rect(select_rect, select_window_colour)
		
