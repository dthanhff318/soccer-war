class_name SettingsPanel
extends Control

## Volume and music settings as an overlay. From the menu it only has Back;
## in a match it also offers Resume and Quit to menu, and can pause the game
## while open (practice only — an online match can't be paused).

signal quit_requested

var volume_slider: HSlider
var music_button: Button
var resume_button: Button
var quit_button: Button
var back_button: Button

var _volume_value: Label
var _pauses: bool = false


## `in_match` shows Resume / Quit instead of Back; `pauses` pauses the tree while open.
func configure(in_match: bool, pauses: bool) -> void:
	_pauses = pauses
	resume_button.visible = in_match
	quit_button.visible = in_match
	back_button.visible = not in_match


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UiKit.card(center, 460)
	card.add_child(UiKit.title("SETTINGS", 40, UiKit.GOLD))

	card.add_child(UiKit.caption("Volume"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	volume_slider = UiKit.slider(0, 100, 5)
	volume_slider.value_changed.connect(_on_volume_changed)
	row.add_child(volume_slider)
	_volume_value = UiKit.title("", 18)
	_volume_value.custom_minimum_size.x = 64
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_volume_value)
	card.add_child(row)

	music_button = UiKit.button("Music", _on_music_pressed, UiKit.Style.GHOST)
	card.add_child(music_button)
	resume_button = UiKit.button("Resume", close, UiKit.Style.PRIMARY)
	card.add_child(resume_button)
	quit_button = UiKit.button("Quit to menu", _on_quit_pressed, UiKit.Style.DANGER)
	card.add_child(quit_button)
	back_button = UiKit.button("Back", close, UiKit.Style.GHOST)
	card.add_child(back_button)
	configure(false, false)


func open() -> void:
	volume_slider.set_value_no_signal(roundf(GameSettings.volume * 100.0))
	_refresh_labels()
	show()
	if _pauses:
		get_tree().paused = true
	(resume_button if resume_button.visible else back_button).grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	GameSettings.save()
	if _pauses:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_volume_changed(value: float) -> void:
	GameSettings.set_volume(value / 100.0)
	_refresh_labels()


func _on_music_pressed() -> void:
	GameSettings.set_music_on(not GameSettings.music_on)
	_refresh_labels()


func _on_quit_pressed() -> void:
	GameSettings.save()
	get_tree().paused = false
	quit_requested.emit()


func _refresh_labels() -> void:
	_volume_value.text = "%d" % roundi(GameSettings.volume * 100.0)
	music_button.text = "MUSIC  ON" if GameSettings.music_on else "MUSIC  OFF"
