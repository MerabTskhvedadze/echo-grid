extends Node

const SAVE_PATH = "user://save_data.json"

var best_score = 0

func _ready():
	load_data()

func load_data():
	if not FileAccess.file_exists(SAVE_PATH):
		best_score = 0
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		best_score = 0
		return

	var text = file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) == TYPE_DICTIONARY:
		best_score = int(data.get("best_score", 0))
	else:
		best_score = 0

func save_best_score(new_score):
	if new_score <= best_score:
		return

	best_score = new_score

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	var data = {
		"best_score": best_score
	}

	file.store_string(JSON.stringify(data))
