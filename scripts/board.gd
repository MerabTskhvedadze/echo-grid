extends Control

signal score_changed(new_score)

const GRID_SIZE = 5
const TILE_SIZE = 100
const GAP = 8
const SWIPE_THRESHOLD = 30

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

func _ready():
	randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_game()

func start_game():
	score = 0
	score_changed.emit(score)
	make_board()
	remove_matches_on_start()

func make_board():
	for child in get_children():
		child.queue_free()

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
	var tile = ColorRect.new()
	tile.size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.color = colors[color_id]
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.set_meta("color_id", color_id)
	return tile

func set_tile_color(tile, color_id):
	tile.set_meta("color_id", color_id)
	tile.color = colors[color_id]

func get_tile_color(tile):
	return tile.get_meta("color_id")

func _gui_input(event):
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

	update_tile_positions()
	clear_all_matches()

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

func update_tile_positions():
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var tile = grid[row][col]
			tile.position = Vector2(
				col * (TILE_SIZE + GAP),
				row * (TILE_SIZE + GAP)
			)

func find_matches():
	var matched = {}

	# Rows
	for row in range(GRID_SIZE):
		var run_color = get_tile_color(grid[row][0])
		var run_start = 0
		var run_length = 1

		for col in range(1, GRID_SIZE):
			var color_id = get_tile_color(grid[row][col])

			if color_id == run_color:
				run_length += 1
			else:
				if run_length >= 3:
					for i in range(run_start, run_start + run_length):
						matched[str(row) + "_" + str(i)] = Vector2i(row, i)

				run_color = color_id
				run_start = col
				run_length = 1

		if run_length >= 3:
			for i in range(run_start, run_start + run_length):
				matched[str(row) + "_" + str(i)] = Vector2i(row, i)

	# Columns
	for col in range(GRID_SIZE):
		var run_color = get_tile_color(grid[0][col])
		var run_start = 0
		var run_length = 1

		for row in range(1, GRID_SIZE):
			var color_id = get_tile_color(grid[row][col])

			if color_id == run_color:
				run_length += 1
			else:
				if run_length >= 3:
					for i in range(run_start, run_start + run_length):
						matched[str(i) + "_" + str(col)] = Vector2i(i, col)

				run_color = color_id
				run_start = row
				run_length = 1

		if run_length >= 3:
			for i in range(run_start, run_start + run_length):
				matched[str(i) + "_" + str(col)] = Vector2i(i, col)

	return matched.values()

func clear_all_matches():
	var matches = find_matches()

	while matches.size() > 0:
		score += matches.size() * 10
		score_changed.emit(score)

		for pos in matches:
			var row = pos.x
			var col = pos.y
			var new_color_id = randi() % colors.size()
			set_tile_color(grid[row][col], new_color_id)

		matches = find_matches()

func remove_matches_on_start():
	var matches = find_matches()

	while matches.size() > 0:
		for pos in matches:
			var row = pos.x
			var col = pos.y
			var new_color_id = randi() % colors.size()
			set_tile_color(grid[row][col], new_color_id)

		matches = find_matches()
