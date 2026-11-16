extends Node2D


const BLOCK_REGISTRY := preload("res://resources/block_registry.tres") as BlockRegistry

const PLACE_BLOCK_SOUND = preload("res://audio/place_block.wav")
const REMOVE_BLOCK_SOUND = preload("res://audio/remove_block.wav")
const MOVE_SOUND = preload("res://audio/move.wav")
const PLAY_SOUND = preload("res://audio/play.wav")
const PAUSE_SOUND = preload("res://audio/pause.wav")
const RESTART_SOUND = preload("res://audio/restart.wav")
const CLEAR_SOUND = preload("res://audio/clear.wav")


@export var current_level: int = 0
@export var step_time: float = 0.2
@export var level_list: LevelList
@export var toolbox: Toolbox
@export var stats: Stats
@export var camera: InputCam


var goal_reached: bool = false
var game_over: bool = false
var editable: bool = true
var steps: int = 0
var action: ActionType = ActionType.NONE


enum ActionType {
	NONE = -1,
	PLACE_BLOCK,
	DELETE_BLOCK
}


func add_user_tiles() -> void:
	for cell in $UserLayer.get_used_cells():
		var atlas_coords: Vector2i = $UserLayer.get_cell_atlas_coords(cell)
		var block_rotation: int = $UserLayer.get_cell_alternative_tile(cell)
		var block := BLOCK_REGISTRY.get_block(atlas_coords)
		if block.atlas_coords == Constants.ARROW:
			arrows.push_back(Arrow.new(cell, block_rotation))
			continue
		var layer: TileMapLayer
		match block.type:
			BlockResource.BlockType.OBSTACLE:
				layer = $ObstacleLayer
			BlockResource.BlockType.INTERACTABLE:
				layer = $LevelLayer
		layer.set_cell(cell, 0, block.atlas_coords, block_rotation)
	redraw_arrows()


func play() -> void:
	if not $StepTimer.is_stopped() or goal_reached or game_over:
		return
	# Only add the user tiles once, when the user first presses play without a reset
	if editable:
		add_user_tiles()
		editable = false
		$BuildAreaLayer.visible = false
		$UserLayer.visible = false
	$StepTimer.start()
	$UiSfxPlayer.stream = PLAY_SOUND
	$UiSfxPlayer.play()

func pause() -> void:
	if $StepTimer.is_stopped():
		return
	$StepTimer.stop()
	$UiSfxPlayer.stream = PAUSE_SOUND
	$UiSfxPlayer.play()



func restart(first_load: bool) -> void:
	if level_list.levels.is_empty():
		push_warning("No level scenes assigned.")
		return
	if not first_load and editable:
		# No need to restart in this case
		return
	load_level_from_scene(level_list.levels[current_level], first_load)
	if not first_load:
		$UiSfxPlayer.stream = RESTART_SOUND
		$UiSfxPlayer.play()


func clear() -> void:
	# Can't clear or nothing to clear 
	if not editable or $UserLayer.get_used_cells().size() == 0:
		return
	$UserLayer.clear()
	toolbox.reset()
	$UiSfxPlayer.stream = CLEAR_SOUND
	$UiSfxPlayer.play()


func update_level(offset: int) -> void:
	if current_level + offset < 0:
		return
	if current_level + offset >= len(level_list.levels):
		print("Well done! All levels completed!")
		pause()
		return
	current_level += offset
	restart(true)
	

func previous_level() -> void:
	update_level(-1)


func next_level() -> void:
	update_level(1)


class Arrow:
	var position: Vector2i
	var next_position: Vector2i
	# NESW
	var facing: int
	var value: int
	var alive: bool = true

	func _init(p_position: Vector2i = Vector2i.ZERO, p_facing: int = Constants.NORTH, p_value: int = 1) -> void:
		position = p_position
		next_position = p_position
		facing = p_facing
		value = p_value

	static func cardinal_to_offset(cardinal_dir: int) -> Vector2i:
		if cardinal_dir == Constants.NORTH:
			return Vector2i(0, -1)
		elif cardinal_dir == Constants.EAST:
			return Vector2i(1, 0)
		elif cardinal_dir == Constants.SOUTH:
			return Vector2i(0, 1)
		else:
			return Vector2i(-1, 0)

	static func get_opposite(dir: int) -> int:
		return posmod(dir + 2, 4)

	func relative_to_cardinal(relative_dir: int) -> int:
		# posmod: GDScript's % keeps the sign, so a negative relative_dir
		# (e.g. LEFT = -1) would give a negative direction.
		return posmod(facing + relative_dir, 4)

	func look(relative_dir: int = Constants.FORWARD) -> Vector2i:
		var cardinal_dir = relative_to_cardinal(relative_dir)
		return position + cardinal_to_offset(cardinal_dir)

	func face(relative_dir: int = Constants.FORWARD) -> void:
		facing = relative_to_cardinal(relative_dir)

	# Merge another arrow (spawned onto the same tile) into this one.
	# Values add up; the facing of the stronger contributor wins (ties keep ours)
	func absorb(other: Arrow) -> void:
		if other.value > value:
			facing = other.facing
		value += other.value


var arrows: Array[Arrow] = []


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	$StepTimer.wait_time = step_time
	restart(true)


# Desired facing is an absolute direction
func is_free(cell: Vector2i, desired_facing: int) -> bool:
	var cell_type = $ObstacleLayer.get_cell_atlas_coords(cell)
	# Assume that the cell alternative id corresponds to its cardinal facing
	# direction
	var cell_facing = $ObstacleLayer.get_cell_alternative_tile(cell)
	match cell_type:
		Constants.ONE_WAY_WALL, Constants.PLACEABLE_ONE_WAY_WALL:
			return desired_facing == cell_facing
		Constants.EMPTY:
			return true
		_:
			return false


func kill_arrow(arrow: Arrow) -> void:
	arrow.alive = false
	arrows.erase(arrow)


# Which way the arrow artwork points in the tileset (assumes the
# cardinals are consecutive clockwise: N, E, S, W)
var arrow_art_facing: int = Constants.NORTH


func redraw_arrows() -> void:
	# Redrawing from the arrow list avoids erasing a tile another arrow is on
	$ArrowLayer.clear()
	for arrow in arrows:
		$ArrowLayer.set_cell(arrow.position, 0, Constants.ARROW, arrow.facing)


# Decide facing and destination for this tick. Does not move the arrow yet,
# so all arrows move simultaneously regardless of processing order
func plan_move(arrow: Arrow) -> void:
	if not is_free(arrow.look(Constants.FORWARD), arrow.facing):
		var open_dirs: Array[int] = []
		for dir in [Constants.RIGHT, Constants.LEFT]:
			if is_free(arrow.look(dir), arrow.relative_to_cardinal(dir)):
				open_dirs.append(dir)
		if len(open_dirs) == 1:
			arrow.face(open_dirs[0])
		elif is_free(arrow.look(Constants.BACK), arrow.facing):
			arrow.face(Constants.BACK)
		# else: completely boxed in, keep facing and stay put
	var target = arrow.look(Constants.FORWARD)
	arrow.next_position = arrow.position if not is_free(target, arrow.facing) else target


# Head-on fight: the stronger arrow survives with the absolute difference
# Equal values destroy both.
func fight(a: Arrow, b: Arrow) -> void:
	var diff = a.value - b.value
	if diff > 0:
		a.value = diff
		kill_arrow(b)
	elif diff < 0:
		b.value = - diff
		kill_arrow(a)
	else:
		kill_arrow(a)
		kill_arrow(b)


# Two arrows about to swap tiles would pass through each other: that's a head-on hit
func resolve_swaps(list: Array[Arrow]) -> void:
	for i in range(len(list)):
		var a = list[i]
		for j in range(i + 1, len(list)):
			if not a.alive:
				break
			var b = list[j]
			if not b.alive:
				continue
			if a.position != a.next_position \
					and a.next_position == b.position \
					and b.next_position == a.position:
				fight(a, b)


# Arrows sharing a tile collide. Head-on pairs (opposite facings) fight, and the
# stronger survives with the difference. Any arrows still sharing the tile after
# that (side-on, same direction, or a survivor meeting a third arrow) are all
# destroyed, so no two arrows ever end up on the same tile
func resolve_collisions() -> void:
	var by_cell: Dictionary = {}
	for arrow in arrows:
		if not by_cell.has(arrow.position):
			by_cell[arrow.position] = []
		by_cell[arrow.position].append(arrow)
	for group in by_cell.values():
		if len(group) < 2:
			continue
		var pair = find_head_on_pair(group)
		while not pair.is_empty():
			fight(pair[0], pair[1])
			pair = find_head_on_pair(group)
		var remaining: Array[Arrow] = []
		for arrow in group:
			if arrow.alive:
				remaining.append(arrow)
		if len(remaining) > 1:
			for arrow in remaining:
				kill_arrow(arrow)


func find_head_on_pair(group: Array) -> Array:
	for i in range(len(group)):
		var a: Arrow = group[i]
		if not a.alive:
			continue
		for j in range(i + 1, len(group)):
			var b: Arrow = group[j]
			if b.alive and b.facing == Arrow.get_opposite(a.facing):
				return [a, b]
	return []


# Removes the splitting arrow and records its children in `spawn`
# (cell -> Arrow). Children landing on the same tile are combined into one arrow
# whose value is the sum of theirs. Children inherit the parent's value
func split_arrow(arrow: Arrow, spawn: Dictionary) -> void:
	var relative_dirs: Array[int] = [Constants.FORWARD, Constants.LEFT, Constants.RIGHT]
	for relative_dir in relative_dirs:
		var pos = arrow.look(relative_dir)
		if not is_free(pos, arrow.relative_to_cardinal(relative_dir)):
			continue
		var child = Arrow.new(pos, arrow.relative_to_cardinal(relative_dir), arrow.value)
		if spawn.has(pos):
			spawn[pos].absorb(child)
		else:
			spawn[pos] = child
	kill_arrow(arrow)


# Applies tile effects to the given arrows. Obstacle tiles are only queued in
# `destroyed` so that several arrows hitting the same obstacle on one tick all die.
# Returns the spawned children (cell -> Arrow) from splitters.
#
# `is_chain` marks arrows spawned by a splitter this tick. A splitter may be
# triggered by chain-spawned arrows only once per tick (tracked in `chain_fired`),
# which keeps loops of splitters from chaining forever. Arrows that reached a
# splitter by normal movement always split
func process_interactions(list: Array[Arrow], is_chain: bool, chain_fired: Dictionary, destroyed: Array[Vector2i]) -> Dictionary:
	var spawn: Dictionary = {}
	for arrow in list:
		if not arrow.alive:
			continue
		var cell_type = $LevelLayer.get_cell_atlas_coords(arrow.position)
		if cell_type == Constants.SPLITTER:
			if is_chain:
				if chain_fired.has(arrow.position):
					continue
				chain_fired[arrow.position] = true
			split_arrow(arrow, spawn)
		elif cell_type == Constants.OBSTACLE:
			kill_arrow(arrow)
			destroyed.append(arrow.position)
		elif cell_type == Constants.DESTROYER:
			kill_arrow(arrow)
		elif cell_type == Constants.GOAL:
			goal_reached = true
	return spawn

func _on_level_select_in_menu(scene_index: int) -> void:
	if scene_index >= level_list.levels.size(): return
	
	update_level(scene_index - current_level)

func load_level_from_scene(scene: PackedScene, first_load: bool) -> void:
	goal_reached = false
	game_over = false
	editable = true
	steps = 0
	pause()
	
	arrows.clear()
	$BuildAreaLayer.visible = true
	$UserLayer.visible = true
	$ArrowLayer.clear()
	$LevelLayer.clear()
	$ObstacleLayer.clear()
	
	var level = scene.instantiate()
	level.init()
	var build_area = level.get_node("BuildAreaLayer")
	var level_layer = level.get_node("LevelLayer")

	# Move cells from level into different layers
	for cell in level_layer.get_used_cells():
		var atlas_coords: Vector2i = level_layer.get_cell_atlas_coords(cell)
		var block_rotation: int = level_layer.get_cell_alternative_tile(cell)
		print(atlas_coords)
		var block := BLOCK_REGISTRY.get_block(atlas_coords)
		if block.atlas_coords == Constants.ARROW:
			arrows.push_back(Arrow.new(cell, block_rotation))
			continue
		var layer: TileMapLayer
		match block.type:
			BlockResource.BlockType.OBSTACLE:
				layer = $ObstacleLayer
			BlockResource.BlockType.INTERACTABLE:
				layer = $LevelLayer
		layer.set_cell(cell, 0, block.atlas_coords, block_rotation)

	if first_load:
		# Only clear the user layer if we are starting a fresh level
		$UserLayer.clear()
		$BuildAreaLayer.clear()
		for cell in build_area.get_used_cells():
			$BuildAreaLayer.set_cell(cell, 0, Constants.BUILD_AREA)
		toolbox.init(level.block_counts)
		# This has to be set after cells are copied so the center is correctly
		# calculated
		set_camera_position()

	# The instantiated scene is never added to the tree, so we free it 
	level.free()

	redraw_arrows()
	if stats:
		stats.set_steps(steps)
		stats.set_arrows(len(arrows))


func set_camera_position() -> void:
	var layers = [$LevelLayer, $ObstacleLayer, $ArrowLayer]
	var used_rect = Rect2i()
	for layer in layers:
		used_rect = used_rect.merge(layer.get_used_rect())
	
	if camera and used_rect.has_area():
		# Centre of the first and last tile (end is exclusive, hence - ONE).
		var top_left = $ObstacleLayer.map_to_local(used_rect.position)
		var bottom_right = $ObstacleLayer.map_to_local(used_rect.end - Vector2i.ONE)
		var center = (top_left + bottom_right) / 2
		camera.set_camera($ObstacleLayer.to_global(center))


func copy_cell(cell: Vector2i, from: TileMapLayer, to: TileMapLayer) -> void:
	to.set_cell(cell,
		from.get_cell_source_id(cell),
		from.get_cell_atlas_coords(cell),
		from.get_cell_alternative_tile(cell))


func process_mouse_edit() -> void:
	$GhostUserLayer.clear()
	$GhostUserLayer.visible = !camera.is_dragging()
	if not editable:
		return
	var cell = $UserLayer.local_to_map($UserLayer.get_local_mouse_position())
	if action != ActionType.DELETE_BLOCK and can_place_block(cell):
		render_ghost_block(cell)
	match action:
		ActionType.PLACE_BLOCK:
			if can_place_block(cell) and place_block(cell):
				$EditorSfxPlayer.stream = PLACE_BLOCK_SOUND
				$EditorSfxPlayer.pitch_scale = 1.0 + randf_range(0.0, 0.1)
				$EditorSfxPlayer.play()
		ActionType.DELETE_BLOCK:
			if delete_block(cell):
				$EditorSfxPlayer.stream = REMOVE_BLOCK_SOUND
				$EditorSfxPlayer.pitch_scale = 1.0 + randf_range(0.0, 0.1)
				$EditorSfxPlayer.play()


func render_ghost_block(cell: Vector2i) -> void:
	var selected = toolbox.selected_block
	if selected == null or not toolbox.has_remaining(selected):
		return
	$GhostUserLayer.set_cell(cell, 0, selected.atlas_coords, toolbox.block_rotation)


func _on_step_timer_timeout() -> void:
	var moving: Array[Arrow] = []
	moving.assign(arrows)

	# Everyone decides where to go, then head-on swaps are resolved
	for arrow in moving:
		plan_move(arrow)
	resolve_swaps(moving)

	# Everyone moves at once, then arrows meeting on a tile collide
	for arrow in moving:
		if arrow.alive:
			arrow.position = arrow.next_position
	resolve_collisions()

	# Tile effects, in rounds. Splitter children are merged per tile, join
	# the game, can fight, and then interact with the tile they landed on,
	# including splitting again (chain splits happen within the same step)
	var destroyed: Array[Vector2i] = []
	var chain_fired: Dictionary = {}
	var batch: Array[Arrow] = moving
	var is_chain = false
	while true:
		var spawned = process_interactions(batch, is_chain, chain_fired, destroyed)
		if spawned.is_empty():
			break
		var children: Array[Arrow] = []
		for child in spawned.values():
			arrows.push_back(child)
			children.append(child)
		resolve_collisions()
		batch = children
		is_chain = true
	for cell in destroyed:
		$LevelLayer.erase_cell(cell)

	steps += 1
	redraw_arrows()
	if stats:
		stats.set_steps(steps)
		stats.set_arrows(len(arrows))

	# Win/lose is decided once per tick, so order of arrows doesn't matter.
	if goal_reached:
		print("GOAL!")
		goal_reached = true
		pause()
	elif arrows.is_empty():
		print("Game over!")
		game_over = true
		pause()
		
	if not game_over:
		$LevelSfxPlayer.stream = MOVE_SOUND
		$LevelSfxPlayer.play()


func _process(delta: float) -> void:
	process_mouse_edit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and editable \
		and event.pressed and not event.echo \
		and event.keycode >= KEY_0 and event.keycode <= KEY_9:
		var buttons = toolbox.get_buttons()
		var index = event.keycode - KEY_1
		if event.keycode == KEY_0:
			index = 9
		if index >= 0 and index < buttons.size():
			var currently_pressed = buttons[index].button_pressed
			buttons[index].button_pressed = not currently_pressed
			if buttons[index].button_pressed:
				buttons[index].pressed.emit()
			else:
				toolbox.deselect()
				
	if event.is_action_pressed("PauseToggle"):
		if $StepTimer.is_stopped():
			play()
		else:
			pause()
	elif event.is_action_pressed("Clear"):
		clear()
	elif event.is_action_pressed("Restart"):
		restart(false)
	elif event.is_action_pressed("NextLevel"):
		next_level()
	elif event.is_action_pressed("PrevLevel"):
		previous_level()
	elif event.is_action_pressed("LevelSelectMenuToggle"):
		var level_menu = get_parent().get_node("CanvasLayer/GUI/LevelMenu")
		level_menu.toggle_visibility()
	elif event.is_action_pressed("PlaceBlock") and \
	 not camera.is_dragging() and editable:
		action = ActionType.PLACE_BLOCK
	elif event.is_action_pressed("DeleteBlock") and editable:
		action = ActionType.DELETE_BLOCK
	elif event.is_action_released("PlaceBlock") \
		or event.is_action_released("DeleteBlock") \
		or camera.is_dragging():
		action = ActionType.NONE
	elif event.is_action_pressed("RotateBlockCW"):
		toolbox.rotate_block(1)
	elif event.is_action_pressed("RotateBlockCCW"):
		toolbox.rotate_block(-1)


func can_place_block(cell: Vector2i):
	# Player can only place blocks in the buildable area
	if cell not in $BuildAreaLayer.get_used_cells():
		return false
	# Player cannot place blocks in occupied cells
	var layers = [$LevelLayer, $ObstacleLayer, $ArrowLayer]
	for layer in layers:
		if layer.get_cell_atlas_coords(cell) != Constants.EMPTY:
			return false
	return true


func place_block(cell: Vector2i) -> bool:
	var selected = toolbox.selected_block
	if selected == null or not toolbox.has_remaining(selected):
		return false

	var existing_atlas_coords = $UserLayer.get_cell_atlas_coords(cell)
	if existing_atlas_coords != Constants.EMPTY:
		# Only look up the block once we know the cell isn't empty
		var existing_block = BLOCK_REGISTRY.get_block(existing_atlas_coords)
		var existing_rotation = $UserLayer.get_cell_alternative_tile(cell)
		# Do not replace with the same block as useless
		if existing_block == selected and existing_rotation == toolbox.block_rotation:
			return false
		# Put back the existing block when replacing it
		toolbox.change_count(existing_block, 1)

	$UserLayer.set_cell(cell, 0, selected.atlas_coords, toolbox.block_rotation)
	toolbox.change_count(selected, -1)
	return true
	

func delete_block(cell: Vector2i) -> bool:
	var atlas_coords = $UserLayer.get_cell_atlas_coords(cell)
	if atlas_coords == Constants.EMPTY:
		return false
	var placeable_block = BLOCK_REGISTRY.get_block(atlas_coords)
	$UserLayer.erase_cell(cell)
	toolbox.change_count(placeable_block, 1)
	return true
