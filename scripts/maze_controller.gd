extends Node2D


const BLOCK_REGISTRY := preload("res://resources/block_registry.tres") as BlockRegistry

const PLACE_BLOCK_SOUND = preload("res://audio/place_block.wav")
const REMOVE_BLOCK_SOUND = preload("res://audio/remove_block.wav")
const MOVE_SOUND = preload("res://audio/move.wav")
const PLAY_SOUND = preload("res://audio/play.wav")
const PAUSE_SOUND = preload("res://audio/pause.wav")
const RESTART_SOUND = preload("res://audio/restart.wav")
const CLEAR_SOUND = preload("res://audio/clear.wav")

const PAUSE_MENU = preload("res://scenes/pause_menu.tscn")


@export var current_level: int = 0
@export var step_time: float = 0.2
@export var level_list: LevelList
@export var gui: GUI
@export var camera: InputCam
@export var ui_layer: CanvasLayer


var playing: bool = false
var goal_reached: bool = false
var game_over: bool = false
var editable: bool = true
var steps: int = 0
var action: ActionType = ActionType.NONE
var level_cell_data: Dictionary[Vector2i, BlockData]
var start_time: int = 0
var pause_menu: Control
var block_select_rect: Rect2


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
	if playing or goal_reached or game_over:
		return
	deselect_blocks()
	# Only add the user tiles once, when the user first presses play without a reset
	if editable:
		add_user_tiles()
		editable = false
		$BuildAreaLayer.visible = false
		$UserLayer.visible = false
	playing = true
	start_time = Time.get_ticks_usec()
	$UiSfxPlayer.stream = PLAY_SOUND
	$UiSfxPlayer.play()

func pause() -> void:
	if not playing:
		return
	playing = false
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
	deselect_blocks()
	$UserLayer.clear()
	gui.toolbox.reset()
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
	call_deferred("restart", true)


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

# Teleporter
# Performs similar behaviour to a splitter, except the exit is on the other side of the portal
func teleport_arrow(arrow: Arrow, spawn: Dictionary) -> void:
	var portal_coords := arrow.position
	# Fetch tag of this portal
	var tag = level_cell_data.get(portal_coords).interaction_tag

	# Find its corresponding portal
	var other_portal_coords = null

	for key in level_cell_data.keys():
		if level_cell_data[key].cell_type_id == Constants.TELEPORTER:
			if level_cell_data[key].interaction_tag == tag and key != portal_coords:
				# If other portal has already been found, then we have more than 2 portals on the same tag
				if other_portal_coords != null:
					push_error("ERROR: More than 2 portals on one tag.")
				else:
					other_portal_coords = key

	if other_portal_coords == null:
		push_error("ERROR: No matching portal found.")
		return
	# Get arrow facing direction
	# Get the corresponding cell at the other portal coords
	# if free, spawn an arrow there
	var output_block = other_portal_coords + Arrow.cardinal_to_offset(arrow.facing)
	var output_facing := arrow.facing
	var can_teleport: bool = true

	if not (is_free(output_block, arrow.facing)):
		# Output block is not free
		# Check if left and right are free
		var right_block = other_portal_coords + Arrow.cardinal_to_offset(arrow.relative_to_cardinal(Constants.RIGHT))
		var left_block = other_portal_coords + Arrow.cardinal_to_offset(arrow.relative_to_cardinal(Constants.LEFT))
		var behind_block = other_portal_coords + Arrow.cardinal_to_offset(arrow.relative_to_cardinal(Constants.BACK))

		if (is_free(left_block, arrow.relative_to_cardinal(Constants.LEFT)) and is_free(right_block, arrow.relative_to_cardinal(Constants.RIGHT))):
			# Left and right free, back free: Bounce
			if (is_free(behind_block, arrow.relative_to_cardinal(Constants.BACK))):
				output_block = behind_block
				output_facing = arrow.relative_to_cardinal(Constants.BACK)
			# Left and right free, back not free: Dont teleport
			else:
				print("Can't teleport from here, blocked everywhere.")
				can_teleport = false
		elif (is_free(left_block, arrow.relative_to_cardinal(Constants.LEFT))):
			output_block = left_block
			output_facing = arrow.relative_to_cardinal(Constants.LEFT)
		elif (is_free(right_block, arrow.relative_to_cardinal(Constants.RIGHT))):
			output_block = right_block
			output_facing = arrow.relative_to_cardinal(Constants.RIGHT)

		else:
			# Teleporter is surrounded
			can_teleport = false

	if can_teleport:
		# Arrow that will be spawned
		var child = Arrow.new(output_block, output_facing, arrow.value)

		# Spawn arrow
		if spawn.has(output_block):
			spawn[output_block].absorb(child)
		else:
			spawn[output_block] = child

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

		match cell_type:
			Constants.SPLITTER:
				if is_chain:
					if chain_fired.has(arrow.position):
						continue
					chain_fired[arrow.position] = true
				split_arrow(arrow, spawn)
			Constants.OBSTACLE:
				kill_arrow(arrow)
				destroyed.append(arrow.position)
			Constants.DESTROYER:
				kill_arrow(arrow)
			Constants.TELEPORTER:
				teleport_arrow(arrow, spawn)
			Constants.GOAL:
				goal_reached = true
			_:
				pass
	return spawn

func _on_level_select_in_menu(scene_index: int) -> void:
	if scene_index >= level_list.levels.size(): return

	update_level(scene_index - current_level)

func load_level_from_scene(scene: PackedScene, first_load: bool) -> void:
	playing = false
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
	deselect_blocks()

	var level = scene.instantiate()
	level.init()
	var build_area = level.get_node("BuildAreaLayer")
	var level_layer = level.get_node("LevelLayer")
	var level_data = level_layer.get_node("LevelData")

	# Move cells from level into different layers
	for cell in level_layer.get_used_cells():
		var atlas_coords: Vector2i = level_layer.get_cell_atlas_coords(cell)
		var block_rotation: int = level_layer.get_cell_alternative_tile(cell)
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
		gui.toolbox.init(level.block_counts)
		# This has to be set after cells are copied so the center is correctly
		# calculated
		set_camera_position()

	# Load interactable cell data into the maze controller
	level_data.scan_level_layer()
	level_cell_data = level_data.interactable_cell_data

	# Draw annotations on interactable cells
	$LevelLayer/LevelAnnotations.cell_data = level_cell_data
	$LevelLayer/LevelAnnotations.queue_redraw()

	# The instantiated scene is never added to the tree, so we free it
	level.free()


	redraw_arrows()
	if gui.stats:
		gui.stats.set_steps(steps)
		gui.stats.set_arrows(len(arrows))


func set_camera_position() -> void:
	var layers = [$LevelLayer, $ObstacleLayer, $ArrowLayer, $BuildAreaLayer]
	var used_rect = Rect2i()
	for layer in layers:
		used_rect = used_rect.merge(layer.get_used_rect())

	if camera and used_rect.has_area():
		var rendered_size = Vector2i($LevelLayer.rendering_quadrant_size, $LevelLayer.rendering_quadrant_size)
		used_rect.size *= rendered_size
		used_rect.position *= rendered_size
		camera.set_camera(used_rect)


func copy_cell(cell: Vector2i, from: TileMapLayer, to: TileMapLayer) -> void:
	to.set_cell(cell,
		from.get_cell_source_id(cell),
		from.get_cell_atlas_coords(cell),
		from.get_cell_alternative_tile(cell))


func process_mouse_edit() -> void:
	$GhostUserLayer.clear()
	gui.mouse_behavior_recursive = \
	 Control.MOUSE_BEHAVIOR_DISABLED if camera.is_dragging() else Control.MOUSE_BEHAVIOR_ENABLED
	if not editable:
		return
	var cell = $UserLayer.local_to_map($UserLayer.get_local_mouse_position())
	if action != ActionType.DELETE_BLOCK and can_place_block(cell) and not camera.is_dragging():
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

func process_selected_blocks() -> void:
	if Input.is_action_just_pressed("SelectBlocks"):
		# Deselect currently held block when starting to select blocks
		if gui.toolbox.selected_block != null:
			gui.toolbox.buttons[gui.toolbox.selected_block].button_pressed = false
			gui.toolbox.deselect()
		$SelectUserLayer.clear_highlighted_cells()
		block_select_rect.position = get_global_mouse_position()
	elif Input.is_action_pressed("SelectBlocks"):
		block_select_rect = Rect2(block_select_rect.position, get_global_mouse_position() - block_select_rect.position).abs()
		draw_select_blocks()
	elif Input.is_action_just_released("SelectBlocks"):
		$SelectUserLayer.clear_select_rect()
	elif $SelectUserLayer.is_cells_selected(): 
		if Input.is_action_just_pressed("DeleteBlock", true):
			$SelectUserLayer.clear_highlighted_cells()
		elif Input.is_action_just_pressed("PlaceBlock", true):
			var mouse_pos = get_global_mouse_position()
			if $SelectUserLayer.in_selected_cells(mouse_pos):
				$SelectUserLayer.start_moving_cells(mouse_pos)
			else:
				$SelectUserLayer.clear_highlighted_cells()
		elif Input.is_action_pressed("PlaceBlock", true) and $SelectUserLayer.dragging_cells:
			var mouse_pos = get_global_mouse_position()
			var new_cell_data: Array[int]
			
			# Save block data to array then erase blocks
			for pos in $SelectUserLayer.moving_positions:
				var user_cell = $UserLayer.local_to_map(pos)
				var atlas_coords = $UserLayer.get_cell_atlas_coords(user_cell)
				var block_rotation = $UserLayer.get_cell_alternative_tile(user_cell)
				var new_block_cell = $UserLayer.local_to_map(pos + mouse_pos - $SelectUserLayer.moving_positions_last)
				new_cell_data.append_array(\
					[ \
						new_block_cell.x, new_block_cell.y, \
						atlas_coords.x, atlas_coords.y, \
						block_rotation
					] \
				)
				
				$UserLayer.erase_cell(user_cell)
			
			# Now reset blocks in new positions from data
			for i in range(0, new_cell_data.size(), 5):
				var new_block_cell = Vector2i(new_cell_data[i], new_cell_data[i + 1])
				
				if new_block_cell in $UserLayer.get_used_cells():
					delete_block(new_block_cell)
				
				$UserLayer.set_cell(\
					new_block_cell, \
					0, \
					Vector2i(new_cell_data[i + 2], new_cell_data[i + 3]), \
					new_cell_data[i + 4] \
				)
				
			$SelectUserLayer.move_selected_cells(mouse_pos)
		elif Input.is_action_just_released("PlaceBlock", true):
			deselect_blocks()

func deselect_blocks() -> void:
	for cell in $UserLayer.get_used_cells():
		if not can_place_block(cell):
			delete_block(cell)
	$SelectUserLayer.stop_moving_cells()

func render_ghost_block(cell: Vector2i) -> void:
	var selected = gui.toolbox.selected_block
	if selected == null or not gui.toolbox.has_remaining(selected):
		return
	$GhostUserLayer.set_cell(cell, 0, selected.atlas_coords, gui.toolbox.block_rotation)


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
	if gui.stats:
		gui.stats.set_steps(steps)
		gui.stats.set_arrows(len(arrows))

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
	var elapsed := Time.get_ticks_usec() - start_time
	if playing and elapsed >= 1_000_000 * step_time:
		_on_step_timer_timeout()
		start_time = Time.get_ticks_usec()
	process_mouse_edit()
	
	if not camera.is_dragging() and editable:
		process_selected_blocks()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and editable \
		and event.pressed and not event.echo \
		and event.keycode >= KEY_0 and event.keycode <= KEY_9:
		var buttons = gui.toolbox.get_buttons()
		var index = event.keycode - KEY_1
		if event.keycode == KEY_0:
			index = 9
		if index >= 0 and index < buttons.size():
			var currently_pressed = buttons[index].button_pressed
			buttons[index].button_pressed = not currently_pressed
			if buttons[index].button_pressed:
				buttons[index].pressed.emit()
			else:
				gui.toolbox.deselect()
			$SelectUserLayer.clear_highlighted_cells()
	
	if event.is_action_pressed("PauseToggle"):
		if playing:
			pause()
		else:
			play()
	elif event.is_action_pressed("PauseMenuToggle"):
		_open_pause()
		return
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
	elif event.is_action_pressed("PlaceBlock", false, true) and \
	 not camera.is_dragging() and editable:
		action = ActionType.PLACE_BLOCK
	elif event.is_action_pressed("DeleteBlock", false, true) and editable:
		action = ActionType.DELETE_BLOCK
	elif event.is_action_released("PlaceBlock") \
		or event.is_action_released("DeleteBlock") \
		or camera.is_dragging():
		action = ActionType.NONE
	elif event.is_action_pressed("RotateBlockCW"):
		gui.toolbox.rotate_block(1)
	elif event.is_action_pressed("RotateBlockCCW"):
		gui.toolbox.rotate_block(-1)


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
	var selected = gui.toolbox.selected_block
	if selected == null or not gui.toolbox.has_remaining(selected):
		return false

	var existing_atlas_coords = $UserLayer.get_cell_atlas_coords(cell)
	if existing_atlas_coords != Constants.EMPTY:
		# Only look up the block once we know the cell isn't empty
		var existing_block = BLOCK_REGISTRY.get_block(existing_atlas_coords)
		var existing_rotation = $UserLayer.get_cell_alternative_tile(cell)
		# Do not replace with the same block as useless
		if existing_block == selected and existing_rotation == gui.toolbox.block_rotation:
			return false
		# Put back the existing block when replacing it
		gui.toolbox.change_count(existing_block, 1)

	$UserLayer.set_cell(cell, 0, selected.atlas_coords, gui.toolbox.block_rotation)
	gui.toolbox.change_count(selected, -1)
	return true


func delete_block(cell: Vector2i) -> bool:
	var atlas_coords = $UserLayer.get_cell_atlas_coords(cell)
	if atlas_coords == Constants.EMPTY:
		return false
	var placeable_block = BLOCK_REGISTRY.get_block(atlas_coords)
	$UserLayer.erase_cell(cell)
	gui.toolbox.change_count(placeable_block, 1)
	return true
	
func draw_select_blocks() -> void:
	var highlighted_cells: Array[Rect2]
	var cell_size = Vector2($UserLayer.tile_set.tile_size)
	for cell in $UserLayer.get_used_cells():
		var cell_rect = Rect2(Vector2(cell) * cell_size, cell_size)
		if block_select_rect.intersects(cell_rect):
			highlighted_cells.push_back(cell_rect)
	$SelectUserLayer.set_render_targets(block_select_rect, highlighted_cells)

func _open_pause() -> void:
	pause_menu = PAUSE_MENU.instantiate()
	ui_layer.add_child(pause_menu)
	pause_menu.resumed.connect(_resume.bind())
	get_tree().paused = true
	get_viewport().set_input_as_handled()
	
func _resume() -> void:
	pause_menu.queue_free()
	pause_menu = null
	get_tree().paused = false
