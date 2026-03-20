extends Control

@onready var board = $BoardCenter/Board
@onready var score_label = $ScoreLabel
@onready var best_label = $BestLabel
@onready var restart_button = $RestartButton
@onready var pressure_label = $PressureLabel
@onready var locks_label = $LocksLabel
@onready var status_label = $StatusLabel

@onready var game_over_panel = $GameOverPanel
@onready var final_score_label = $GameOverPanel/FinalScoreLabel
@onready var best_score_label = $GameOverPanel/BestScoreLabel
@onready var restart_big_button = $GameOverPanel/RestartBigButton

func _ready():
	board.score_changed.connect(on_score_changed)
	board.pressure_changed.connect(on_pressure_changed)
	board.locks_changed.connect(on_locks_changed)
	board.game_over.connect(on_game_over)

	restart_button.pressed.connect(on_restart_pressed)
	restart_big_button.pressed.connect(on_restart_pressed)

	on_score_changed(0)
	on_pressure_changed(0, 3)
	on_locks_changed(0, 8)
	refresh_best_label()

	status_label.text = ""
	game_over_panel.visible = false

func on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

	if new_score > Savedata.best_score:
		Savedata.save_best_score(new_score)
		refresh_best_label()

func on_pressure_changed(current_pressure, max_pressure):
	pressure_label.text = "Pressure: " + str(current_pressure) + "/" + str(max_pressure)

func on_locks_changed(current_locks, max_locks):
	locks_label.text = "Locks: " + str(current_locks) + "/" + str(max_locks)

func on_game_over(final_score):
	if final_score > Savedata.best_score:
		Savedata.save_best_score(final_score)
		refresh_best_label()

	status_label.text = "Locked Out"

	final_score_label.text = "Score: " + str(final_score)
	best_score_label.text = "Best: " + str(Savedata.best_score)
	game_over_panel.visible = true

func on_restart_pressed():
	status_label.text = ""
	game_over_panel.visible = false
	board.start_game()
	refresh_best_label()

func refresh_best_label():
	best_label.text = "Best: " + str(Savedata.best_score)
