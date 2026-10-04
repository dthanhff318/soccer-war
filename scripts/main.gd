extends Node2D

## Root game scene. Keeps score and resets the ball after each goal.

signal score_changed(left: int, right: int)

var score_left: int = 0
var score_right: int = 0

@onready var _ball: Ball = $Ball
@onready var _score_label: Label = $UI/ScoreLabel

var _ball_start: Vector2


func _ready() -> void:
	_ball_start = _ball.global_position
	$Goals/GoalLeft.body_entered.connect(_on_goal_entered.bind("right"))
	$Goals/GoalRight.body_entered.connect(_on_goal_entered.bind("left"))
	_update_score_label()


## A ball entering a goal scores for the opposing side.
func _on_goal_entered(body: Node2D, scoring_side: String) -> void:
	if not (body is Ball):
		return

	if scoring_side == "left":
		score_left += 1
	else:
		score_right += 1

	score_changed.emit(score_left, score_right)
	_update_score_label()
	_reset_ball()


func _reset_ball() -> void:
	_ball.global_position = _ball_start
	_ball.velocity = Vector2.ZERO


func _update_score_label() -> void:
	_score_label.text = "%d  –  %d" % [score_left, score_right]
