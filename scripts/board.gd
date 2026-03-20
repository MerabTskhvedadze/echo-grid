extends Control

signal score_changed(new_score)
signal pressure_changed(current_pressure, max_pressure)
signal locks_changed(current_locks, max_locks)
signal game_over(final_score)

const GRID_SIZE = 5
const TILE_SIZE = 100
const GAP = 8
const SWIPE_THRESHOLD = 30

const PRESSURE_LIMIT = 3
const MAX_LOCKS = 8

var colors = [
	Color("ff5a5f"),
	Color("2ec4b6"),
	Color("ffd166"),
	Color("6c63ff"),
	Color("00bbf9")
]

var grid = []
var swipe_start = Vector2.ZERO
var dragging = false
var score = 0
var busy = false
var pressure = 0
var dead = false

func _ready():
	randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_game()

func start_game():
	busy = false
	dragging = false
	dead = false
	score = 0
	pressure = 0

	score_changed.emit(score)
	pressure_changed.emit(pressure, PRESSURE_LIMIT)
	locks_changed.emit(0, MAX_LOCKS)

	make_board()
	remove_matches_on_start()

func make_board():
	for child in get_children():
		child.free()

	grid.clear()

	var board_size = GRID_SIZE * TILE_SIZE + (GRID_SIZE - 1) * GAP
	custom_minimum_size = Vector2(board_size, board_size)
	size = Vector2(board_size, board_size)

	for row in range(GRID_SIZE):
		grid.append([])
		for col in range(GRID_SIZE):
			var color_id = randi() % colors.size()
			var tile = create_tile(color_id)

			tile.position = Vector2(
				col * (TILE_SIZE + GAP),
				row * (TILE_SIZE + GAP)
			)

			add_child(tile)
			grid[row].append(tile)

func create_tile(color_id):
	var tile = Panel.new()
	tile.size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.pivot_offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

	tile.set_meta("color_id", color_id)
	tile.set_meta("locked", false)

	apply_tile_look(tile)
	return tile

func set_tile_color(tile, color_id):
	tile.set_meta("color_id", color_id)
	apply_tile_look(tile)

func get_tile_color(tile):
	return int(tile.get_meta("color_id"))

func set_tile_locked(tile, value):
	tile.set_meta("locked", value)
	apply_tile_look(tile)

func get_tile_locked(tile):
	return bool(tile.get_meta("locked"))

func apply_tile_look(tile):
	var color_id = get_tile_color(tile)
	var locked = get_tile_locked(tile)

	var base_color = colors[color_id]
	if locked:
		base_color = base_color.darkened(0.45)

	var style = StyleBoxFlat.new()
	style.bg_color = base_color

	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18

	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)

	style.border_color = base_color.lightened(0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	tile.add_theme_stylebox_override("panel", style)

func _gui_input(event):
	if busy or dead:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = event.position
			dragging = true
		else:
			if dragging:
				dragging = false
				handle_swipe(swipe_start, event.position)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start = event.position
				dragging = true
			else:
				if dragging:
					dragging = false
					handle_swipe(swipe_start, event.position)

func handle_swipe(start_pos, end_pos):
	var delta = end_pos - start_pos

	if delta.length() < SWIPE_THRESHOLD:
		return

	busy = true

	var cell_size = TILE_SIZE + GAP
	var row = clampi(int(start_pos.y / cell_size), 0, GRID_SIZE - 1)
	var col = clampi(int(start_pos.x / cell_size), 0, GRID_SIZE - 1)

	if abs(delta.x) > abs(delta.y):
		if delta.x > 0:
			shift_row_right(row)
		else:
			shift_row_left(row)
	else:
		if delta.y > 0:
			shift_column_down(col)
		else:
			shift_column_up(col)

	await animate_board_move()

	var result = await clear_all_matches()
	apply_pressure_and_locks(result)

	busy = false

func shift_row_left(row):
	var first = grid[row][0]
	for col in range(GRID_SIZE - 1):
		grid[row][col] = grid[row][col + 1]
	grid[row][GRID_SIZE - 1] = first

func shift_row_right(row):
	var last = grid[row][GRID_SIZE - 1]
	for col in range(GRID_SIZE - 1, 0, -1):
		grid[row][col] = grid[row][col - 1]
	grid[row][0] = last

func shift_column_up(col):
	var first = grid[0][col]
	for row in range(GRID_SIZE - 1):
		grid[row][col] = grid[row + 1][col]
	grid[GRID_SIZE - 1][col] = first

func shift_column_down(col):
	var last = grid[GRID_SIZE - 1][col]
	for row in range(GRID_SIZE - 1, 0, -1):
		grid[row][col] = grid[row - 1][col]
	grid[0][col] = last

func animate_board_move():
	var tween = create_tween()

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var tile = grid[row][col]
			var target_pos = Vector2(
				col * (TILE_SIZE + GAP),
				row * (TILE_SIZE + GAP)
			)
			tween.parallel().tween_property(tile, "position", target_pos, 0.12)

	await tween.finished

func add_run_matches(matched, run):
	if run.size() >= 3:
		for pos in run:
			matched[str(pos.x) + "_" + str(pos.y)] = pos

func find_matches():
	var matched = {}

	# Rows
	for row in range(GRID_SIZE):
		var run = []
		var run_color = -1

		for col in range(GRID_SIZE):
			var tile = grid[row][col]

			if get_tile_locked(tile):
				add_run_matches(matched, run)
				run = []
				run_color = -1
				continue

			var color_id = get_tile_color(tile)

			if run.size() == 0 or color_id == run_color:
				run.append(Vector2i(row, col))
				run_color = color_id
			else:
				add_run_matches(matched, run)
				run = [Vector2i(row, col)]
				run_color = color_id

		add_run_matches(matched, run)

	# Columns
	for col in range(GRID_SIZE):
		var run = []
		var run_color = -1

		for row in range(GRID_SIZE):
			var tile = grid[row][col]

			if get_tile_locked(tile):
				add_run_matches(matched, run)
				run = []
				run_color = -1
				continue

			var color_id = get_tile_color(tile)

			if run.size() == 0 or color_id == run_color:
				run.append(Vector2i(row, col))
				run_color = color_id
			else:
				add_run_matches(matched, run)
				run = [Vector2i(row, col)]
				run_color = color_id

		add_run_matches(matched, run)

	return matched.values()

func clear_all_matches():
	var matches = find_matches()
	var total_cleared = 0
	var chain_count = 0

	while matches.size() > 0:
		chain_count += 1
		total_cleared += matches.size()

		score += matches.size() * 10 * chain_count
		score_changed.emit(score)

		await animate_match_pop(matches)

		for pos in matches:
			var row = pos.x
			var col = pos.y
			var new_color_id = randi() % colors.size()
			set_tile_color(grid[row][col], new_color_id)

		await animate_match_reappear(matches)

		matches = find_matches()

	return {
		"had_match": chain_count > 0,
		"total_cleared": total_cleared,
		"chain_count": chain_count
	}

func animate_match_pop(matches):
	var tween = create_tween()

	for pos in matches:
		var row = pos.x
		var col = pos.y
		var tile = grid[row][col]
		tween.parallel().tween_property(tile, "scale", Vector2(0.2, 0.2), 0.08)

	await tween.finished

func animate_match_reappear(matches):
	for pos in matches:
		var row = pos.x
		var col = pos.y
		var tile = grid[row][col]
		tile.scale = Vector2(0.2, 0.2)

	var tween = create_tween()

	for pos in matches:
		var row = pos.x
		var col = pos.y
		var tile = grid[row][col]
		tween.parallel().tween_property(tile, "scale", Vector2(1, 1), 0.10)

	await tween.finished

func apply_pressure_and_locks(result):
	pressure += 1

	if result["had_match"]:
		pressure = max(0, pressure - 1)

	if result["chain_count"] >= 2 or result["total_cleared"] >= 4:
		unlock_random_tile()

	while pressure >= PRESSURE_LIMIT:
		pressure -= PRESSURE_LIMIT
		add_random_lock()

	pressure_changed.emit(pressure, PRESSURE_LIMIT)

	var lock_count = count_locked_tiles()
	locks_changed.emit(lock_count, MAX_LOCKS)

	if lock_count >= MAX_LOCKS:
		dead = true
		game_over.emit(score)

func add_random_lock():
	var choices = []

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var tile = grid[row][col]
			if not get_tile_locked(tile):
				choices.append(tile)

	if choices.size() == 0:
		return

	var tile = choices[randi() % choices.size()]
	set_tile_locked(tile, true)

func unlock_random_tile():
	var choices = []

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var tile = grid[row][col]
			if get_tile_locked(tile):
				choices.append(tile)

	if choices.size() == 0:
		return

	var tile = choices[randi() % choices.size()]
	set_tile_locked(tile, false)

func count_locked_tiles():
	var total = 0

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			if get_tile_locked(grid[row][col]):
				total += 1

	return total

func remove_matches_on_start():
	var matches = find_matches()

	while matches.size() > 0:
		for pos in matches:
			var row = pos.x
			var col = pos.y
			var new_color_id = randi() % colors.size()
			set_tile_color(grid[row][col], new_color_id)

		matches = find_matches()
