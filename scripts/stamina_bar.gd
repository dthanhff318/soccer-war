class_name StaminaBar
extends Control

## HUD bar showing a player's stamina. Green when healthy, amber when low,
## red while exhausted (sprint locked until it recovers).

@export var low_threshold: float = 0.3
@export var color_full: Color = Color(0.3, 0.85, 0.35)
@export var color_low: Color = Color(0.95, 0.7, 0.2)
@export var color_exhausted: Color = Color(0.9, 0.25, 0.25)
@export var color_background: Color = Color(0, 0, 0, 0.45)

var _ratio: float = 1.0
var _exhausted: bool = false


## Connect this to Player.stamina_changed.
func set_stamina(current: float, maximum: float, exhausted: bool) -> void:
	_ratio = clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	_exhausted = exhausted
	queue_redraw()


func _draw() -> void:
	var full_rect := Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, color_background)

	var fill_color := color_full
	if _exhausted:
		fill_color = color_exhausted
	elif _ratio < low_threshold:
		fill_color = color_low
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)), fill_color)

	draw_rect(full_rect, Color(1, 1, 1, 0.8), false, 2.0)
