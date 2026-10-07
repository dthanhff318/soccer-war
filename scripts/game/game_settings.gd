class_name GameSettings
extends RefCounted

## Player settings: master volume and whether the crowd bed ("music") plays.
## Applied to the audio buses and kept in a small config file between runs.

const DEFAULT_PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const DEFAULT_VOLUME := 0.8

static var volume: float = DEFAULT_VOLUME
static var music_on: bool = true
## Where save()/load_and_apply() read and write; tests point it elsewhere.
static var save_path: String = DEFAULT_PATH


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply()


static func set_music_on(on: bool) -> void:
	music_on = on
	apply()


## Pushes the settings onto the Master and Music buses.
static func apply() -> void:
	var music := ensure_music_bus()
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(music, not music_on)


## Index of the Music bus (feeding Master), created on first use.
static func ensure_music_bus() -> int:
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, MUSIC_BUS)
		AudioServer.set_bus_send(index, "Master")
	return index


static func save(path: String = save_path) -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "music_on", music_on)
	config.save(path)


static func load_and_apply(path: String = save_path) -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		volume = clampf(float(config.get_value("audio", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
		music_on = bool(config.get_value("audio", "music_on", true))
	apply()
