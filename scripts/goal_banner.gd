class_name GoalBanner
extends Label

## Big "GOALLL!!!" text: pops in, wobbles while flashing colors, then fades.

@export var flash_colors: Array[Color] = [Color(1, 0.9, 0.2), Color.WHITE]
@export var flash_interval: float = 0.12
@export var hold_time: float = 1.0

var _tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	hide()


func play() -> void:
	_stop_tweens()
	show()
	# Scale and rotate around the centre of the text, not the top-left corner.
	pivot_offset = size / 2.0
	scale = Vector2.ZERO
	rotation = 0.0
	modulate.a = 1.0

	_flash_tween = create_tween().set_loops()
	for color in flash_colors:
		_flash_tween.tween_property(self, "self_modulate", color, 0.0)
		_flash_tween.tween_interval(flash_interval)

	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.3, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	for angle in [0.08, -0.08, 0.05, -0.05, 0.0]:
		_tween.tween_property(self, "rotation", angle, 0.08)
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_stop_tweens()
	hide()


func _stop_tweens() -> void:
	for tween in [_tween, _flash_tween]:
		if tween and tween.is_valid():
			tween.kill()
