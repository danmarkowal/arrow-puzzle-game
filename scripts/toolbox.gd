extends PanelContainer
class_name Toolbox

signal count_changed(block_type: Level.PlaceableBlock, count: int)

const BLOCK_BUTTON_SCENE := preload("res://scenes/block_button.tscn")

var selected_block = null
var initial_counts: Dictionary[Level.PlaceableBlock, int] = {}
var remaining: Dictionary[Level.PlaceableBlock, int] = {}
var buttons: Dictionary[Level.PlaceableBlock, Button] = {}

var button_group := ButtonGroup.new()


func init(p_placeable_blocks: Dictionary[Level.PlaceableBlock, int]) -> void:
	selected_block = null
	for child in $Buttons.get_children():
		$Buttons.remove_child(child)
		child.queue_free()
	buttons.clear()

	initial_counts = p_placeable_blocks.duplicate()
	remaining = p_placeable_blocks.duplicate()

	var block_types := p_placeable_blocks.keys()
	block_types.sort()
	for block_type in block_types:
		var button = BLOCK_BUTTON_SCENE.instantiate()
		button.block_type = block_type
		button.button_group = button_group
		button.toggle_mode = true
		button.block_selected.connect(_on_block_selected)
		$Buttons.add_child(button)
		buttons[block_type] = button
		button.display_count(remaining[block_type])
		
	if buttons.is_empty():
		hide()
	else:
		show()


func reset() -> void:
	remaining = initial_counts.duplicate()
	for block_type in buttons:
		buttons[block_type].display_count(remaining[block_type])


func change_count(block_type: Level.PlaceableBlock, delta: int) -> void:
	remaining[block_type] += delta
	buttons[block_type].display_count(remaining[block_type])
	count_changed.emit(block_type, remaining[block_type])


func has_remaining(block_type: Level.PlaceableBlock) -> bool:
	return remaining.get(block_type, 0) > 0


func get_buttons() -> Array[Node]:
	return $Buttons.get_children()


func deselect():
	selected_block = null
	

func _on_block_selected(block_type: Level.PlaceableBlock) -> void:
	selected_block = block_type
