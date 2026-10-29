extends PanelContainer
class_name Toolbox

signal count_changed(block_type: Level.PlacableBlock, count: int)

const BLOCK_BUTTON_SCENE := preload("res://scenes/block_button.tscn")

var selected_block = null
var initial_counts: Dictionary[Level.PlacableBlock, int] = {}
var remaining: Dictionary[Level.PlacableBlock, int] = {}
var buttons: Dictionary[Level.PlacableBlock, Button] = {}

var button_group := ButtonGroup.new()


func init(p_placable_blocks: Dictionary[Level.PlacableBlock, int]) -> void:
	for child in $Buttons.get_children():
		$Buttons.remove_child(child)
		child.queue_free()
	buttons.clear()

	initial_counts = p_placable_blocks.duplicate()
	remaining = p_placable_blocks.duplicate()

	var block_types := p_placable_blocks.keys()
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


func reset() -> void:
	remaining = initial_counts.duplicate()
	for block_type in buttons:
		buttons[block_type].display_count(remaining[block_type])


func change_count(block_type: Level.PlacableBlock, delta: int) -> void:
	remaining[block_type] += delta
	buttons[block_type].display_count(remaining[block_type])
	count_changed.emit(block_type, remaining[block_type])


func has_remaining(block_type: Level.PlacableBlock) -> bool:
	return remaining.get(block_type, 0) > 0


func _on_block_selected(block_type: Level.PlacableBlock) -> void:
	selected_block = block_type
