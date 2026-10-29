extends Node2D


@export var current_level: int = 0
@export var step_time: float = 0.2
@export var level_scenes: Array[PackedScene]
@export var toolbox: Toolbox
@export var stats: Stats
@export var camera: Camera2D


var goal_reached = false
var game_over = false
var editable = true
var steps = 0


func add_user_tiles() -> void:
	for cell in $UserLayer.get_used_cells():
		var cell_type: Vector2i = $UserLayer.get_cell_atlas_coords(cell)
		match cell_type:
			Constants.USER_WALL:
				$ObstacleLayer.set_cell(cell, 0, cell_type)
			_:
				$LevelLayer.set_cell(cell, 0, cell_type)


func remove_user_tiles() -> void:
	for cell in $UserLayer.get_used_cells():
		$LevelLayer.erase_cell(cell)
		$ObstacleLayer.erase_cell(cell)


func play() -> void:
	if not $StepTimer.is_stopped() or goal_reached or game_over:
		return
	editable = false
	add_user_tiles()
	$BuildAreaLayer.visible = false
	$UserLayer.visible = false
	$StepTimer.start()


func pause() -> void:
	if $StepTimer.is_stopped():
		return
	remove_user_tiles()
	$UserLayer.visible = true
	$StepTimer.stop()


func restart(first_load: bool) -> void:
	if level_scenes.is_empty():
		push_warning("No level scenes assigned.")
		return
	load_level_from_scene(level_scenes[current_level], first_load)
	$BuildAreaLayer.visible = true


func clear() -> void:
	if not editable:
		return
	pause()
	$BuildAreaLayer.visible = true
	$UserLayer.clear()
	toolbox.reset()


func update_level(offset: int) -> void:
	if current_level + offset < 0:
		return
	if current_level + offset >= len(level_scenes):
		print("Well done! All levels completed!")
		pause()
		return
	current_level += offset
	$UserLayer.clear()
	$UserLayer.visible = true
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


func is_blocked(cell: Vector2i) -> bool:
	return $ObstacleLayer.get_cell_atlas_coords(cell) != Constants.EMPTY


func kill_arrow(arrow: Arrow) -> void:
	arrow.alive = false
	arrows.erase(arrow)


# Which way the arrow artwork points in the tileset (assumes the
# cardinals are consecutive clockwise: N, E, S, W).
var arrow_art_facing: int = Constants.NORTH


# Tile transform flags that rotate the arrow artwork to point along `facing`.
func facing_to_tile_alternative(facing: int) -> int:
	var quarter_turns = posmod(facing - arrow_art_facing, 4)
	if quarter_turns == 1:  # 90 degrees clockwise
		return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
	elif quarter_turns == 2:  # 180 degrees
		return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
	elif quarter_turns == 3:  # 90 degrees counter-clockwise
		return TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V
	return 0


func redraw_arrows() -> void:
	# Redrawing from the arrow list avoids erasing a tile another arrow is on
	$ArrowLayer.clear()
	for arrow in arrows:
		$ArrowLayer.set_cell(arrow.position, 0, Constants.ARROW, facing_to_tile_alternative(arrow.facing))


# Decide facing and destination for this tick. Does not move the arrow yet,
# so all arrows move simultaneously regardless of processing order
func plan_move(arrow: Arrow) -> void:
	if is_blocked(arrow.look(Constants.FORWARD)):
		var open_dirs: Array[int] = []
		for dir in [Constants.RIGHT, Constants.LEFT]:
			if not is_blocked(arrow.look(dir)):
				open_dirs.append(dir)
		if len(open_dirs) == 1:
			arrow.face(open_dirs[0])
		elif not is_blocked(arrow.look(Constants.BACK)):
			arrow.face(Constants.BACK)
		# else: completely boxed in, keep facing and stay put.
	var target = arrow.look(Constants.FORWARD)
	arrow.next_position = arrow.position if is_blocked(target) else target


# Head-on fight: the stronger arrow survives with the absolute difference
# Equal values destroy both.
func fight(a: Arrow, b: Arrow) -> void:
	var diff = a.value - b.value
	if diff > 0:
		a.value = diff
		kill_arrow(b)
	elif diff < 0:
		b.value = -diff
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
# whose value is the sum of theirs. Children inherit the parent's value.
func split_arrow(arrow: Arrow, spawn: Dictionary) -> void:
	var relative_dirs: Array[int] = [Constants.FORWARD, Constants.LEFT, Constants.RIGHT]
	for relative_dir in relative_dirs:
		var pos = arrow.look(relative_dir)
		if is_blocked(pos):
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
# splitter by normal movement always split.
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


func load_level_from_scene(scene: PackedScene, first_load: bool) -> void:
	print(first_load)
	goal_reached = false
	game_over = false
	editable = true
	steps = 0
	pause()
	
	arrows.clear()
	$BuildAreaLayer.clear()
	$ArrowLayer.clear()
	$LevelLayer.clear()
	$ObstacleLayer.clear()
	
	var level = scene.instantiate()
	var build_area = level.get_node("BuildAreaLayer")
	var level_layer = level.get_node("LevelLayer")
		
	if first_load:
		toolbox.init(level.placable_blocks)
	
	for cell in build_area.get_used_cells():
		$BuildAreaLayer.set_cell(cell, 0, Constants.BUILD_AREA)

	# Move cells from level into different layers
	for cell in level_layer.get_used_cells():
		var cell_type = level_layer.get_cell_atlas_coords(cell)
		if cell_type == Constants.WALL:
			$ObstacleLayer.set_cell(cell, 0, cell_type)
		elif cell_type == Constants.START:
			arrows.push_back(Arrow.new(cell))
		else:
			$LevelLayer.set_cell(cell, 0, cell_type)

	# The instantiated scene is never added to the tree, so we free it 
	level.free()

	redraw_arrows()
	if stats:
		stats.set_steps(steps)
		stats.set_arrows(len(arrows))

	var used_rect = $ObstacleLayer.get_used_rect()
	if camera and used_rect.has_area():
		# Centre of the first and last tile (end is exclusive, hence - ONE).
		var top_left = $ObstacleLayer.map_to_local(used_rect.position)
		var bottom_right = $ObstacleLayer.map_to_local(used_rect.end - Vector2i.ONE)
		var center = (top_left + bottom_right) / 2
		camera.global_position = $ObstacleLayer.to_global(center)


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
		next_level()
	elif arrows.is_empty():
		print("Game over!")
		game_over = true
		pause()


# TODO: Add keybinds (Taiyo)
func _unhandled_input(event: InputEvent) -> void:
	if not $StepTimer.is_stopped() or not editable:
		return
	if event is InputEventMouseButton and event.pressed:
		var cell = $UserLayer.local_to_map($UserLayer.get_local_mouse_position())
		if not can_place_block(cell):
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				place_block(cell)
			MOUSE_BUTTON_RIGHT:
				delete_block(cell)


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


func place_block(cell: Vector2i) -> void:
	var selected = toolbox.selected_block
	if selected == null or not toolbox.has_remaining(selected):
		return

	var atlas_coords = Level.get_block_atlas_coords(selected)
	var existing_atlas_coords = $UserLayer.get_cell_atlas_coords(cell)

	if existing_atlas_coords != Constants.EMPTY:
		# Only look up the block once we know the cell isn't empty
		var existing_block = Level.get_placable_block(existing_atlas_coords)
		# Do not replace with the same block as useless
		if existing_block == selected:
			return
		# Put back the existing block when replacing it
		toolbox.change_count(existing_block, 1)

	$UserLayer.set_cell(cell, 0, atlas_coords)
	toolbox.change_count(selected, -1)
	

func delete_block(cell: Vector2i):
	var atlas_coords = $UserLayer.get_cell_atlas_coords(cell)
	if atlas_coords == Constants.EMPTY:
		return
	var placable_block = Level.get_placable_block(atlas_coords)
	$UserLayer.erase_cell(cell)
	toolbox.change_count(placable_block, 1)
