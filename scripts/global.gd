# This file is part of the DynaDungeons game
# Copyright (C) 2015  Rémi Verschelde and contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

extends Node

### Constants
const TILE_SIZE = 32				# Characteristic size of a square tile, in pixels
const TILE_OFFSET = Vector2(0.5,0.5)*TILE_SIZE # Vector2 of the offset to reach the center of a tile
const MAX_BOMBS = 8					# How many bombs can a player amass
const MAX_FLAMERANGE = 8			# How far can an exploding bomb's flame reach
const MAX_SPEED = 20				# How fast can a player walk
const COLLECTIBLE_RATE = 25			# How often (in %) will a destroyed object spawn a pickup
# Data for player intialisation: sprite and position
const PLAYER_DATA = [ {'char': "goblin-blue", 'tile_pos': Vector2(1,1) },
                      {'char': "goblin-violet", 'tile_pos': Vector2(13,11) },
                      {'char': "goblin-brown", 'tile_pos': Vector2(1,11) },
                      {'char': "human-orange", 'tile_pos': Vector2(13,1) } ]
# List of remappable actions
const INPUT_ACTIONS = [ "move_up", "move_down", "move_left", "move_right", "drop_bomb" ]

### Resources
const menu_scene = preload("res://scenes/menu.xscn")
const world_scene = preload("res://scenes/world.xscn")
const level_scene = preload("res://scenes/level.xscn")
const player_scene = preload("res://scenes/player.xscn")
const bomb_scene = preload("res://scenes/bomb.xscn")
const collectible_scene = preload("res://scenes/collectible.xscn")

const player_script = preload("res://scripts/player.gd")
const collectible_script = preload("res://scripts/collectible.gd")

const settings_filename = "user://settings.cfg"


### Parameters

## Display
var width = 960						# Display width
var height = 832					# Display height
var fullscreen = false				# Whether we run in fullscreen or not

## Audio
var music = true					# Should the music play
var music_volume = 1				# Volume of the music, between 0 and 1
var sfx = true						# Should sound effects play
var sfx_volume = 1					# Volume of sound effects, between 0 and 1

## Gameplay
var nb_players = 2					# How many players participate in a new game
var nb_lives = 1					# How many lives each player has
# Drop frequencies for each type of collectible. Frequencies should be in theory be
# between 0 and 100, though higher frequencies would also work.
var collectibles = { 'types': [ "bomb_increase", "flame_increase", "speed_increase", "speed_decrease", "confusion", "life_increase", "kick_skill" ],
                     'freq': [ 100, 100, 70, 50, 30, 5*nb_lives, 30 ] }

### Config management

func load_config():
	"""Load the user-defined settings from the default settings file. Create this file
	if it is missing and populate it with default values as defined in this class.
	"""
	var config = ConfigFile.new()
	var err = config.load(settings_filename)
	if (err):
		# TODO: Better error handling
		# Config file does not exist, dump default settings in it
		
		# Display parameters
		config.set_value("display", "width", width)
		config.set_value("display", "height", height)
		config.set_value("display", "fullscreen", fullscreen)
		
		# Audio parameters
		config.set_value("audio", "music", music)
		config.set_value("audio", "music_volume", music_volume)
		config.set_value("audio", "sfx", sfx)
		config.set_value("audio", "sfx_volume", sfx_volume)
		
		# Gameplay parameters
		config.set_value("gameplay", "nb_players", nb_players)
		config.set_value("gameplay", "nb_lives", nb_lives)
		
		# Default inputs
		var action_name
		for i in range(1,5):
			for action in INPUT_ACTIONS:
				action_name = str(i) + "_" + action
				config.set_value("input", action_name, OS.get_scancode_string(InputMap.get_action_list(action_name)[0].scancode))
		
		config.save(settings_filename)
	else:
		# Display parameters
		set_from_cfg(config, "display", "width")
		set_from_cfg(config, "display", "height")
		set_from_cfg(config, "display", "fullscreen")
		
		# Audio parameters
		set_from_cfg(config, "audio", "music")
		set_from_cfg(config, "audio", "music_volume")
		set_from_cfg(config, "audio", "sfx")
		set_from_cfg(config, "audio", "sfx_volume")
		
		# Gameplay parameters
		set_from_cfg(config, "gameplay", "nb_players")
		set_from_cfg(config, "gameplay", "nb_lives")
		
		# User-defined input overrides
		var scancode
		var event
		for action in config.get_section_keys("input"):
			# Get the key scancode corresponding to the saved human-readable string
			scancode = OS.find_scancode_from_string(config.get_value("input", action))
			# Create a new event object based on the saved scancode
			event = InputEvent()
			event.type = InputEvent.KEY
			event.scancode = scancode
			# Replace old actions by the new one - apparently erasing the old action
			# works better to get the control buttons properly initialised in the UI
			# TODO: Handle multiple events per action in a better way
			InputMap.erase_action(action)
			InputMap.add_action(action)
			InputMap.action_add_event(action, event)

func set_from_cfg(config, section, key):
	"""Retrieve the parameter from the config file, or restore it
	if it is missing from the config file.
	"""
	if (config.has_section_key(section, key)):
		set(key, config.get_value(section, key))
	else:
		print("Warning: '" + key + "' missing from '" + section + "' section in the config file, default value has been added.")
		save_to_config(section, key, get(key))

func save_to_config(section, key, value):
	"""Helper function to redefine a parameter in the settings file"""
	var config = ConfigFile.new()
	var err = config.load(settings_filename)
	if (err):
		# TODO: Better error handling
		print("Error code when loading config file: ", err)
	else:
		config.set_value(section, key, value)
		config.save(settings_filename)

func save_screen_size():
	"""Save the screen size as two separate parameters"""
	var screen_size = OS.get_window_size()
	width = int(screen_size.x)
	height = int(screen_size.y)
	save_to_config("display", "width", width)
	save_to_config("display", "height", height)

### Initialisation

func _ready():
	# Get a new seed to generate random numbers
	randomize()
	
	# Load parameters from the config file, overriding the default ones
	load_config()
	
	# Handle display
	OS.set_window_size(Vector2(width, height))
	OS.set_window_fullscreen(fullscreen)
	
	# Save window size if changed by the user
	get_tree().connect("screen_resized", self, "save_screen_size")
	
	# Calculate the sum of the frequencies of all collectibles, to be used
	# in calculations when a collectible has to be picked randomly
	collectibles.sum_freq = 0
	for freq in collectibles.freq:
		collectibles.sum_freq += freq
