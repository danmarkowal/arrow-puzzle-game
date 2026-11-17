extends PanelContainer
class_name Toolbox


const BLOCK_BUTTON_SCENE := preload("res://scenes/block_button.tscn")

var selected_block: BlockResource = null
var block_rotation: int = Constants.NORTH
var initial_counts: Dictionary[BlockResource, int] = {}
var remaining: Dictionary[BlockResource, int] = {}
var buttons: Dictionary[BlockResource, Button] = {}

var button_group := ButtonGroup.new()


signal count_changed(block: BlockResource, count: int)


func init(p_block_counts: Dictionary[BlockResource, int]) -> void:
	selected_block = null
	for child in $Buttons.get_children():
		$Buttons.remove_child(child)
		child.queue_free()
	buttons.clear()

	initial_counts = p_block_counts.duplicate()
	remaining = p_block_counts.duplicate()

	var block_types := p_block_counts.keys()
	block_types.sort_custom(
		func(a: BlockResource, b: BlockResource) -> bool:
			return p_block_counts[a] > p_block_counts[b]
	)

	for block in block_types:
		var button = BLOCK_BUTTON_SCENE.instantiate()
		button.block = block
		button.button_group = button_group
		button.toggle_mode = true
		button.block_selected.connect(_on_block_selected)
		$Buttons.add_child(button)
		buttons[block] = button
		button.display_count(remaining[block])
		
	if buttons.is_empty():
		hide()
	else:
		show()


func reset() -> void:
	remaining = initial_counts.duplicate()
	for block_type in buttons:
		buttons[block_type].display_count(remaining[block_type])


func change_count(block: BlockResource, delta: int) -> void:
	remaining[block] += delta
	buttons[block].display_count(remaining[block])
	count_changed.emit(block, remaining[block])


func has_remaining(block: BlockResource) -> bool:
	return remaining.get(block, 0) > 0


func get_buttons() -> Array[Node]:
	return $Buttons.get_children()


func deselect():
	selected_block = null
	

func _on_block_selected(block: BlockResource) -> void:
	selected_block = block
	block_rotation = Constants.NORTH


func rotate_block(direction: int) -> void:
	if selected_block == null or not selected_block.rotatable:
		return
	block_rotation = (block_rotation + direction) % 4
