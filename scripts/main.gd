extends Control

@onready var board = $BoardCenter/Board
@onready var score_label = $ScoreLabel
@onready var restart_button = $RestartButton
@onready var pressure_label = $PressureLabel
@onready var locks_label = $LocksLabel
@onready var status_label = $StatusLabel

func _ready():
	board.score_changed.connect(on_score_changed)
	board.pressure_changed.connect(on_pressure_changed)
	board.locks_changed.connect(on_locks_changed)
	board.game_over.connect(on_game_over)

	restart_button.pressed.connect(on_restart_pressed)

	on_score_changed(0)
	on_pressure_changed(0, 3)
	on_locks_changed(0, 8)
	status_label.text = ""

func on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

func on_pressure_changed(current_pressure, max_pressure):
	pressure_label.text = "Pressure: " + str(current_pressure) + "/" + str(max_pressure)

func on_locks_changed(current_locks, max_locks):
	locks_label.text = "Locks: " + str(current_locks) + "/" + str(max_locks)

func on_game_over(final_score):
	status_label.text = "Locked Out"

func on_restart_pressed():
	status_label.text = ""
	board.start_game()
