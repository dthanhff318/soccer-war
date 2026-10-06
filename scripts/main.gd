extends Node2D

## Root game scene. Keeps score, plays the goal celebration and resets the
## ball after each goal.

var score: Array[int] = [0, 0]

## True between a goal and the kickoff reset, so one goal can't count twice.
var _celebrating: bool = false

@onready var _ball: Ball = $Ball
@onready var _scoreboard: Scoreboard = $UI/Scoreboard
@onready var _player: Player = $Player
@onready var _stamina_bar: StaminaBar = $UI/StaminaBar
@onready var _goal_banner: GoalBanner = $UI/GoalBanner


func _ready() -> void:
	_player.keyboard_control = true
	_player.stamina_changed.connect(_stamina_bar.set_stamina)


func _physics_process(_delta: float) -> void:
	if not _celebrating:
		var team := MatchRules.scoring_team(_ball.global_position, _ball.radius)
		if team >= 0:
			_on_goal(team)


## Scores for `team`, celebrates while the ball settles in the net, then
## resets for kickoff.
func _on_goal(team: int) -> void:
	_celebrating = true
	score[team] += 1
	_scoreboard.set_score(score[Roster.Team.LEFT], score[Roster.Team.RIGHT])
	_goal_banner.play()

	await get_tree().create_timer(MatchRules.CELEBRATION_SECONDS, false, true).timeout
	_ball.reset(MatchRules.CENTER)
	_celebrating = false
