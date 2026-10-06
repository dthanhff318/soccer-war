extends Node2D

## Root game scene. Keeps score, plays the goal celebration and resets the
## ball after each goal.

signal score_changed(left: int, right: int)

## Goal geometry in screen space, matching the lines on field.png.
@export var goal_line_left: float = 263.2
@export var goal_line_right: float = 1016.8
@export var goal_mouth_top: float = 291.8
@export var goal_mouth_bottom: float = 428.4
## Seconds the ball stays in the net (celebration) before kickoff.
@export var celebration_time: float = 2.5

var score_left: int = 0
var score_right: int = 0

## True between a goal and the kickoff reset, so one goal can't count twice.
var _celebrating: bool = false
var _ball_start: Vector2

@onready var _ball: Ball = $Ball
@onready var _scoreboard: Scoreboard = $UI/Scoreboard
@onready var _player: Player = $Player
@onready var _stamina_bar: StaminaBar = $UI/StaminaBar
@onready var _goal_banner: GoalBanner = $UI/GoalBanner


func _ready() -> void:
	_ball_start = _ball.global_position
	_player.stamina_changed.connect(_stamina_bar.set_stamina)


func _physics_process(_delta: float) -> void:
	if not _celebrating:
		_check_goal()


## A goal counts only once the whole ball is past the goal line, inside the mouth.
func _check_goal() -> void:
	var pos := _ball.global_position
	if pos.y < goal_mouth_top or pos.y > goal_mouth_bottom:
		return
	if pos.x + _ball.radius < goal_line_left:
		_on_goal("right")
	elif pos.x - _ball.radius > goal_line_right:
		_on_goal("left")


## Scores for `scoring_side`, celebrates while the ball settles in the net,
## then resets for kickoff.
func _on_goal(scoring_side: String) -> void:
	_celebrating = true
	if scoring_side == "left":
		score_left += 1
	else:
		score_right += 1

	score_changed.emit(score_left, score_right)
	_scoreboard.set_score(score_left, score_right)
	_goal_banner.play()

	await get_tree().create_timer(celebration_time, false, true).timeout
	_reset_ball()
	_celebrating = false


func _reset_ball() -> void:
	_ball.global_position = _ball_start
	_ball.velocity = Vector2.ZERO

