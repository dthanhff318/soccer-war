extends TestCase


func _init() -> void:
	GameSettings.save_path = "user://test_settings.cfg"

## Volume and music settings: applied to the audio buses and saved between runs.

const TEST_PATH := "user://test_settings.cfg"


func _reset() -> void:
	GameSettings.volume = GameSettings.DEFAULT_VOLUME
	GameSettings.music_on = true
	GameSettings.apply()


func test_volume_drives_the_master_bus() -> void:
	GameSettings.set_volume(0.5)
	var master := AudioServer.get_bus_index("Master")
	check_near(AudioServer.get_bus_volume_db(master), linear_to_db(0.5), 0.01, "half volume")
	check(not AudioServer.is_bus_mute(master), "audible")
	GameSettings.set_volume(0.0)
	check(AudioServer.is_bus_mute(master), "0 % mutes")
	_reset()


func test_music_toggle_mutes_only_the_music_bus() -> void:
	GameSettings.set_music_on(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.MUSIC_BUS)), "music muted")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "cheers still audible")
	GameSettings.set_music_on(true)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.MUSIC_BUS)), "music back")
	_reset()


func test_crowd_bed_plays_on_the_music_bus_and_the_cheer_does_not() -> void:
	var audio := MatchAudio.new()
	add_child(audio)
	check_eq(audio.crowd.bus, StringName(GameSettings.MUSIC_BUS), "crowd on music")
	check_eq(audio.cheer.bus, &"Master", "cheer on master")
	audio.queue_free()


func test_settings_survive_a_restart() -> void:
	GameSettings.volume = 0.3
	GameSettings.music_on = false
	GameSettings.save(TEST_PATH)
	GameSettings.volume = 1.0
	GameSettings.music_on = true
	GameSettings.load_and_apply(TEST_PATH)
	check_near(GameSettings.volume, 0.3, 0.001, "volume loaded")
	check(not GameSettings.music_on, "music loaded")
	DirAccess.remove_absolute(TEST_PATH)
	_reset()
