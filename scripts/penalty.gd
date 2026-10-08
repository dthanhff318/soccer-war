class_name PenaltyMatch
extends Node2D

## Practice penalty shootout against the AI, on the right goal only.
## Each kick: setup → 3-2-1 countdown (nobody moves) → live (the shooter gets
## one touch, the keeper slides along its goal line) → result banner. You
## shoot on blue's kicks and keep on red's; PenaltyRules decides the winner.

enum Phase { SETUP, COUNTDOWN, LIVE, RESULT, FINISHED }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/menu.tscn"
const SCOREBOARD_SCRIPT := preload("res://scripts/scoreboard.gd")
const KEEPER_ALLOWED_BITS := Protocol.IN_UP | Protocol.IN_DOWN | Protocol.IN_SPRINT
## Ball slower than this after the touch counts as stopped.
const STOPPED_SPEED := 5.0
## Keeper "touched" the ball when this close (body + ball radius + a little).
const KEEPER_TOUCH_DISTANCE := Player.BODY_RADIUS + 11.2 + 3.0
const DOT_SIZE := 14

@export var countdown_seconds: float = 3.0
## No touch within this long after the whistle = a miss.
@export var shot_timeout: float = 6.0
## After the touch, give the ball this long to go in before calling it.
@export var flight_timeout: float = 4.0
@export var result_seconds: float = 1.5

var phase: int = Phase.SETUP
var rules := PenaltyRules.new()
var blue: Player
var red: Player
var ball: Ball
## True once the shooter has touched the ball this kick.
var touched: bool = false
## Bits from the human; tests replace this.
var human_input: Callable = func() -> int: return Protocol.keyboard_bits(Input.is_action_just_pressed("pass"))
var countdown_label: Label
var banner: Label
var result_panel: Control
var result_title: Label

var _timer: float = 0.0
var _keeper_touched: bool = false
var _shooter_brain: PenaltyAI.ShooterBrain
var _keeper_brain: PenaltyAI.KeeperBrain
var _scoreboard: Scoreboard
var _dot_rows: Array[HBoxContainer] = []
var _round_label: Label
var _role_label: Label
var _leaving: bool = false
var _audio: MatchAudio
var _settings_button: Button
var _settings_panel: SettingsPanel


func _ready() -> void:
	add_child(preload("res://scenes/pitch.tscn").instantiate())
	ball = preload("res://scenes/ball.tscn").instantiate()
	ball.simulated = false
	add_child(ball)
	var character := Characters.by_id(CharactersScreen.practice_character_id)
	if character.is_empty():
		character = Characters.by_id(CharactersScreen.DEFAULT_CHARACTER)
	blue = _spawn(Roster.Team.LEFT, character.name)
	blue.is_local = true
	CharacterStats.apply(blue, character)
	red = _spawn(Roster.Team.RIGHT, "AI")
	_build_hud()
	_audio = MatchAudio.new()
	add_child(_audio)
	_build_settings(true)


func shooter() -> Player:
	return blue if rules.next_team() == Roster.Team.LEFT else red


func keeper() -> Player:
	return red if shooter() == blue else blue


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_settings()


func _quit_to_menu() -> void:
	_leave_to(MENU_SCENE)

## Settings button (top right) and overlay; Esc opens it too.
func _build_settings(pauses: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_settings_button = UiKit.button("Settings", _open_settings, UiKit.Style.GHOST)
	_settings_button.add_theme_font_size_override("font_size", 22)
	_settings_button.custom_minimum_size = Vector2(150, 36)
	_settings_button.position = Vector2(1116, 10)
	_settings_button.focus_mode = Control.FOCUS_NONE
	layer.add_child(_settings_button)
	_settings_panel = SettingsPanel.new()
	_settings_panel.configure(true, pauses)
	_settings_panel.quit_requested.connect(_quit_to_menu)
	layer.add_child(_settings_panel)


func _open_settings() -> void:
	if not _settings_panel.visible:
		_settings_panel.open()



func _physics_process(delta: float) -> void:
	match phase:
		Phase.SETUP:
			_setup_kick()
		Phase.COUNTDOWN:
			_timer -= delta
			countdown_label.text = str(ceili(maxf(_timer, 0.01)))
			if _timer <= 0.0:
				countdown_label.hide()
				phase = Phase.LIVE
				_timer = 0.0
		Phase.LIVE:
			_play(delta)
		Phase.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				banner.hide()
				if rules.is_over():
					finish()
				else:
					phase = Phase.SETUP


## Ball on the spot, shooter behind it, keeper centred on the line.
func _setup_kick() -> void:
	var kicker := shooter()
	var goalie := keeper()
	ball.reset(PenaltyRules.spot())
	for player in [kicker, goalie]:
		player.velocity = Vector2.ZERO
	kicker.position = PenaltyRules.shooter_start()
	kicker.is_goalkeeper = false
	goalie.position = PenaltyRules.keeper_start()
	goalie.is_goalkeeper = true
	_shooter_brain = PenaltyAI.ShooterBrain.new() if kicker == red else null
	_keeper_brain = PenaltyAI.KeeperBrain.new() if goalie == red else null
	touched = false
	_keeper_touched = false
	_round_label.text = "SUDDEN DEATH" if rules.is_sudden_death() else "ROUND %d" % rules.round_number()
	_role_label.text = "YOUR KICK  -  walk up, hold Space, release to shoot" if kicker == blue \
		else "YOU ARE IN GOAL  -  W / S or up / down to move along the line"
	countdown_label.show()
	_timer = countdown_seconds
	phase = Phase.COUNTDOWN


func _play(delta: float) -> void:
	_timer += delta
	var kicker := shooter()
	var goalie := keeper()
	var shooter_bits := 0
	if not touched:
		shooter_bits = human_input.call() if kicker == blue else _shooter_brain.bits(kicker.position, ball.position)
	var keeper_bits: int = human_input.call() if goalie == blue else _keeper_brain.bits(goalie.position, delta)
	kicker.simulate(shooter_bits, delta)
	goalie.simulate(keeper_bits & KEEPER_ALLOWED_BITS, delta)
	_lock_to_line(goalie)
	if not touched and ball.velocity.length() > 1.0:
		touched = true
		_timer = 0.0
		if _keeper_brain:
			_keeper_brain.on_shot(ball.position, ball.velocity)
	ball.step(delta)
	if ball.position.distance_to(goalie.position) <= KEEPER_TOUCH_DISTANCE:
		_keeper_touched = true

	if MatchRules.scoring_team(ball.position, ball.radius) == Roster.Team.LEFT:
		_resolve(true, "GOAL!")
	elif not touched and _timer > shot_timeout:
		_resolve(false, "MISSED!")
	elif touched and (ball.velocity.length() < STOPPED_SPEED or _timer > flight_timeout):
		_resolve(false, "SAVED!" if _keeper_touched else "MISSED!")


## The keeper may only slide along the goal line, between the posts.
func _lock_to_line(goalie: Player) -> void:
	goalie.position.x = PenaltyRules.KEEPER_X
	goalie.velocity.x = 0.0
	var clamped := clampf(goalie.position.y, PenaltyRules.KEEPER_Y_RANGE.x, PenaltyRules.KEEPER_Y_RANGE.y)
	if clamped != goalie.position.y:
		goalie.position.y = clamped
		goalie.velocity.y = 0.0


func _resolve(scored: bool, text: String) -> void:
	rules.record(shooter().team, scored)
	_refresh_score()
	if scored:
		_audio.play_goal()
	banner.text = text
	banner.add_theme_color_override("font_color", UiKit.GOLD if scored else UiKit.TEXT)
	banner.show()
	_timer = result_seconds
	phase = Phase.RESULT


## Shows the end screen once the shootout is decided.
func finish() -> void:
	phase = Phase.FINISHED
	_refresh_score()
	var won := rules.winner() == Roster.Team.LEFT
	result_title.text = "YOU WIN" if won else "YOU LOSE"
	result_title.add_theme_color_override("font_color", UiKit.GOLD if won else UiKit.RED)
	result_panel.get_node("%Score").text = "%d - %d" % [rules.goals(Roster.Team.LEFT), rules.goals(Roster.Team.RIGHT)]
	countdown_label.hide()
	banner.hide()
	result_panel.show()


func _spawn(team: int, label: String) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.team = team
	player.display_name = label
	add_child(player)
	return player


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_scoreboard = SCOREBOARD_SCRIPT.new()
	_scoreboard.font = UiKit.PIXEL_FONT
	_scoreboard.home_name = "YOU"
	_scoreboard.away_name = "AI"
	_scoreboard.position = Vector2(520, 2)
	_scoreboard.size = Vector2(240, 56)
	ui.add_child(_scoreboard)

	var top := VBoxContainer.new()
	top.position = Vector2(0, 640)
	top.size = Vector2(1280, 80)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(top)
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		top.add_child(row)
		_dot_rows.append(row)

	_round_label = UiKit.title("", 22, UiKit.GOLD)
	_round_label.position = Vector2(0, 62)
	_round_label.size = Vector2(1280, 30)
	ui.add_child(_round_label)
	_role_label = UiKit.label("", 15, UiKit.TEXT)
	_role_label.position = Vector2(0, 88)
	_role_label.size = Vector2(1280, 22)
	_role_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_role_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_role_label)

	countdown_label = UiKit.title("3", 140, UiKit.GOLD)
	countdown_label.size = Vector2(1280, 720)
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.hide()
	ui.add_child(countdown_label)
	banner = UiKit.title("", 96)
	banner.size = Vector2(1280, 720)
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.hide()
	ui.add_child(banner)

	result_panel = Control.new()
	result_panel.size = Vector2(1280, 720)
	result_panel.hide()
	ui.add_child(result_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(1280, 720)
	result_panel.add_child(shade)
	var center := CenterContainer.new()
	center.size = Vector2(1280, 720)
	result_panel.add_child(center)
	var card := UiKit.card(center, 420)
	result_title = UiKit.title("", 56)
	card.add_child(result_title)
	var score := UiKit.title("", 40)
	score.name = "Score"
	score.unique_name_in_owner = true
	card.add_child(score)
	score.owner = result_panel
	card.add_child(UiKit.button("Play again", _leave_to.bind(scene_file_path), UiKit.Style.ACCENT))
	card.add_child(UiKit.button("Menu", _leave_to.bind(MENU_SCENE), UiKit.Style.GHOST))
	_refresh_score()


## Scoreboard plus one dot per kick: green goal, red miss, grey still to take.
func _refresh_score() -> void:
	_scoreboard.set_score(rules.goals(Roster.Team.LEFT), rules.goals(Roster.Team.RIGHT))
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var row := _dot_rows[team]
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		var name_tag := UiKit.title("YOU" if team == Roster.Team.LEFT else "AI", 14, Teams.color_of(team))
		name_tag.custom_minimum_size.x = 48
		row.add_child(name_tag)
		var history := rules.history(team)
		var slots := maxi(PenaltyRules.REGULAR_KICKS, history.size())
		for i in slots:
			var color := Color(0.45, 0.47, 0.5)
			if i < history.size():
				color = Color(0.3, 0.85, 0.4) if history[i] else Color(0.9, 0.25, 0.2)
			var dot := TextureRect.new()
			dot.texture = UiKit.color_chip(color, DOT_SIZE)
			row.add_child(dot)


func _leave_to(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
