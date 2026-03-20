extends Control

@onready var board = $BoardCenter/Board
@onready var score_label = $ScoreLabel
@onready var restart_button = $RestartButton

func _ready():
	board.score_changed.connect(on_score_changed)
	restart_button.pressed.connect(on_restart_pressed)
	on_score_changed(0)

func on_score_changed(new_score):
	score_label.text = "Score: " + str(new_score)

func on_restart_pressed():
	board.start_game()
