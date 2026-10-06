class_name Scoreboard
extends Control

## Electronic stadium scoreboard: dark panel, team labels and glowing
## 7-segment LED digits. The scoring side blinks after a goal.

@export var font: Font
@export var home_name: String = "HOME"
@export var away_name: String = "AWAY"
@export var home_color: Color = Color(0.2, 0.35, 1.0)
@export var away_color: Color = Color(0.95, 0.25, 0.25)
@export var led_on: Color = Color(1.0, 0.62, 0.12)
@export var led_off: Color = Color(0.09, 0.05, 0.025)
@export var blink_duration: float = 1.6
@export var blink_interval: float = 0.15

## Digit geometry, in pixels.
const DIGIT_SIZE := Vector2(18, 28)
const SEGMENT_THICKNESS := 4.0
const SEGMENT_GAP := 1.2
const DIGIT_SPACING := 8.0
## Italic slant of the digits, as x offset per pixel of height.
const SKEW := 0.1
const LABEL_FONT_SIZE := 12
const LABEL_ROW_HEIGHT := 13.0

## Segments a..g lit for each digit 0-9.
const DIGIT_SEGMENTS := [
	"abcdef", "bc", "abdeg", "abcdg", "bcfg",
	"acdfg", "acdefg", "abc", "abcdefg", "abcdfg",
]

var _score_left: int = 0
var _score_right: int = 0
## "left", "right" or "" when nothing is blinking.
var _blink_side: String = ""
var _blink_left: float = 0.0


func set_score(left: int, right: int) -> void:
	if left != _score_left:
		_start_blink("left")
	elif right != _score_right:
		_start_blink("right")
	_score_left = left
	_score_right = right
	queue_redraw()


func _start_blink(side: String) -> void:
	_blink_side = side
	_blink_left = blink_duration


func _process(delta: float) -> void:
	if _blink_side == "":
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_side = ""
	queue_redraw()


func _draw() -> void:
	_draw_panel()

	var digits_width := DIGIT_SIZE.x * 2.0 + DIGIT_SPACING
	var window_padding := Vector2(10, 4)
	var window_size := Vector2(digits_width, DIGIT_SIZE.y) + window_padding * 2.0
	var row_top := LABEL_ROW_HEIGHT + 6.0
	var side_margin := 18.0

	var left_window := Rect2(Vector2(side_margin, row_top), window_size)
	var right_window := Rect2(Vector2(size.x - side_margin - window_size.x, row_top), window_size)

	_draw_team_label(home_name, home_color, left_window)
	_draw_team_label(away_name, away_color, right_window)

	_draw_score(_score_left, left_window, window_padding, _is_blanked("left"))
	_draw_score(_score_right, right_window, window_padding, _is_blanked("right"))
	_draw_separator(Vector2(size.x / 2.0, row_top + window_size.y / 2.0))


func _draw_panel() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.07, 0.09)
	panel.border_color = Color(0.38, 0.4, 0.45)
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(6)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 3)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	# Glass reflection across the top half.
	draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, size.y * 0.35)), Color(1, 1, 1, 0.04))


func _draw_team_label(text: String, color: Color, window: Rect2) -> void:
	var label_font := font if font else ThemeDB.fallback_font
	var text_width := label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var baseline := Vector2(window.get_center().x - text_width / 2.0, LABEL_ROW_HEIGHT)
	draw_string(label_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color(0.92, 0.92, 0.95))
	# Team colour strip just above the LED window.
	draw_rect(Rect2(Vector2(window.position.x, LABEL_ROW_HEIGHT + 3.0), Vector2(window.size.x, 3)), color)


func _draw_score(score: int, window: Rect2, padding: Vector2, blanked: bool) -> void:
	draw_rect(window, Color(0.015, 0.015, 0.02))
	var value := clampi(score, 0, 99)
	var origin := window.position + padding
	# Leading digit stays unlit below 10, like a real board.
	var tens := value / 10 if value >= 10 else -1
	_draw_digit(tens, origin, blanked)
	_draw_digit(value % 10, origin + Vector2(DIGIT_SIZE.x + DIGIT_SPACING, 0), blanked)


func _draw_separator(center: Vector2) -> void:
	for offset_y in [-8.0, 8.0]:
		var dot := Rect2(center + Vector2(-3, offset_y - 3), Vector2(6, 6))
		draw_rect(dot.grow(2), Color(led_on, 0.2))
		draw_rect(dot, led_on)


## Draws one digit; `digit` of -1 (or `blanked`) shows only unlit segments.
func _draw_digit(digit: int, origin: Vector2, blanked: bool) -> void:
	var lit: String = "" if digit < 0 or blanked else DIGIT_SEGMENTS[digit]
	for segment in "abcdefg":
		var ends := _segment_ends(segment)
		var p0 := _skewed(origin + ends[0], origin)
		var p1 := _skewed(origin + ends[1], origin)
		if segment in lit:
			# Soft glow first, then the bright segment on top.
			draw_colored_polygon(_segment_polygon(p0, p1, SEGMENT_THICKNESS * 2.2), Color(led_on, 0.18))
			draw_colored_polygon(_segment_polygon(p0, p1, SEGMENT_THICKNESS), led_on)
		else:
			draw_colored_polygon(_segment_polygon(p0, p1, SEGMENT_THICKNESS), led_off)


## End points of a segment within a digit cell (before skew).
func _segment_ends(segment: String) -> Array[Vector2]:
	var half := SEGMENT_THICKNESS / 2.0
	var w := DIGIT_SIZE.x
	var h := DIGIT_SIZE.y
	var tl := Vector2(half, half)
	var tr := Vector2(w - half, half)
	var ml := Vector2(half, h / 2.0)
	var mr := Vector2(w - half, h / 2.0)
	var bl := Vector2(half, h - half)
	var br := Vector2(w - half, h - half)
	match segment:
		"a": return [tl, tr]
		"b": return [tr, mr]
		"c": return [mr, br]
		"d": return [bl, br]
		"e": return [ml, bl]
		"f": return [tl, ml]
		_: return [ml, mr]


## Slants a point to the right the higher it sits in its digit cell.
func _skewed(point: Vector2, origin: Vector2) -> Vector2:
	return point + Vector2((origin.y + DIGIT_SIZE.y - point.y) * SKEW, 0)


## Hexagonal LED segment from p0 to p1 with pointed ends.
func _segment_polygon(p0: Vector2, p1: Vector2, thickness: float) -> PackedVector2Array:
	var dir := (p1 - p0).normalized()
	var normal := Vector2(-dir.y, dir.x) * thickness / 2.0
	var tip := dir * SEGMENT_GAP
	var shoulder := dir * (SEGMENT_GAP + thickness / 2.0)
	return PackedVector2Array([
		p0 + tip, p0 + shoulder + normal, p1 - shoulder + normal,
		p1 - tip, p1 - shoulder - normal, p0 + shoulder - normal,
	])


func _is_blanked(side: String) -> bool:
	if _blink_side != side:
		return false
	return int(_blink_left / blink_interval) % 2 == 0
