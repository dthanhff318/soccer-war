class_name MatchAudio
extends Node

## Stadium sound for a running match: a looping crowd bed under the play
## and a loud cheer whenever someone scores.

const CROWD := preload("res://assets/sound/crowd-cheering-reacting.mp3")
const CHEER := preload("res://assets/sound/crowd-cheering-loud.mp3")
## The bed sits under the action; the cheer rides on top of it.
const CROWD_VOLUME_DB := -12.0
const CHEER_VOLUME_DB := -2.0

var crowd := AudioStreamPlayer.new()
var cheer := AudioStreamPlayer.new()


func _init() -> void:
	name = "MatchAudio"
	crowd.stream = CROWD  # loops (set in its .import)
	crowd.volume_db = CROWD_VOLUME_DB
	cheer.stream = CHEER
	cheer.volume_db = CHEER_VOLUME_DB
	add_child(crowd)
	add_child(cheer)


func _ready() -> void:
	crowd.play()


func play_goal() -> void:
	cheer.play()
