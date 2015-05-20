extends Node

# Constants
const TILE_SIZE = 32
const TILE_OFFSET = Vector2(0.5,0.5)*TILE_SIZE
const MAX_BOMBS = 8
const MAX_FLAMERANGE = 8
const MAX_SPEED = 20
const COLLECTIBLE_RATE = 15
const PLAYER_DATA = [ {'char': "goblin-blue", 'tile_pos': Vector2(1,1) },
                      {'char': "goblin-violet", 'tile_pos': Vector2(13,11) },
                      {'char': "goblin-brown", 'tile_pos': Vector2(1,11) },
                      {'char': "human-orange", 'tile_pos': Vector2(13,1) } ]

# Scenes
const menu_scene = preload("res://scenes/menu.xscn")
const level_scene = preload("res://scenes/level.xscn")
const player_scene = preload("res://scenes/player.xscn")
const bomb_scene = preload("res://scenes/bomb.xscn")
const collectible_scene = preload("res://scenes/collectible.xscn")

# Scripts
const player_script = preload("res://scripts/player.gd")

# Files
const settings_filename = "user://settings.cfg"
const inputmap_actions = [ "move_up", "move_down", "move_left", "move_right", "drop_bomb" ]

# Display parameters
var display_size = Vector2(960,832)
var fullscreen = false

# Audio parameters
var music = true
var sfx = false

# Gameplay parameters
var nb_players = 2
var nb_lives = 1
var collectibles = { 'types': [ "bomb_increase", "flame_increase", "speed_increase", "life_increase" ],
                     'freq': [ 100, 100, 70, 5*nb_lives ] }

func load_config():
	var config = ConfigFile.new()
	var err = config.load(settings_filename)
	if (err):
		# TODO: Better error handling
		# Config file does not exist, dump default settings in it
		
		# Display parameters
		config.set_value("display", "width", int(display_size.x))
		config.set_value("display", "height", int(display_size.y))
		config.set_value("display", "fullscreen", fullscreen)
		
		# Audio parameters
		config.set_value("audio", "music", music)
		config.set_value("audio", "sfx", sfx)
		
		# Gameplay parameters
		config.set_value("gameplay", "nb_players", nb_players)
		config.set_value("gameplay", "nb_lives", nb_lives)
		
		# Default inputs
		var action_name
		for i in range(1,5):
			for action in inputmap_actions:
				action_name = str(i) + "_" + action
				config.set_value("input", action_name, OS.get_scancode_string(InputMap.get_action_list(action_name)[0].scancode))
		
		config.save(settings_filename)
	else:
		# Display parameters
		display_size.x = set_from_cfg(config, "display", "width", display_size.x)
		display_size.y = set_from_cfg(config, "display", "height", display_size.y)
		fullscreen = set_from_cfg(config, "display", "fullscreen", fullscreen)
		
		# Audio parameters
		music = set_from_cfg(config, "audio", "music", music)
		sfx = set_from_cfg(config, "audio", "sfx", sfx)
		
		# Gameplay parameters
		nb_players = set_from_cfg(config, "gameplay", "nb_players", nb_players)
		nb_lives = set_from_cfg(config, "gameplay", "nb_lives", nb_lives)
		
		# User-defined input overrides
		var scancode
		var event
		for action in config.get_section_keys("input"):
			scancode = OS.find_scancode_from_string(config.get_value("input", action))
			event = InputEvent()
			event.type = InputEvent.KEY
			event.scancode = scancode
			# TODO: Handle multiple events per action in a better way
			InputMap.erase_action(action)
			InputMap.add_action(action)
			InputMap.action_add_event(action, event)

func set_from_cfg(config, section, key, fallback):
	if (config.has_section_key(section, key)):
		return config.get_value(section, key)
	else:
		print("Warning: '" + key + "' missing from '" + section + "'section in the config file, default value has been added.")
		save_to_config(section, key, fallback)
		return fallback

func save_to_config(section, key, value):
	var config = ConfigFile.new()
	var err = config.load(settings_filename)
	if (err):
		# TODO: Better error handling
		print("Error code when loading config file: ", err)
	else:
		config.set_value(section, key, value)
		config.save(settings_filename)

func _ready():
	randomize()
	
	load_config()
	
	# Handle display
	OS.set_window_size(display_size)
	OS.set_window_fullscreen(fullscreen)
	
	collectibles.sum_freq = 0
	for freq in collectibles.freq:
		collectibles.sum_freq += freq
