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

extends Node2D

### Variables ###

## Nodes
onready var map_manager = get_node("MapManager")
onready var player_manager = get_node("PlayerManager")
onready var bomb_manager = get_node("BombManager")
onready var collectible_manager = get_node("CollectibleManager")
onready var tilemap_destr = map_manager.get_node("Destructible")
onready var tilemap_indestr = map_manager.get_node("Indestructible")

## Member variables
var exploding_bombs = [] # Array of bombs that are currently exploding

### Callbacks ###

func _ready():
	# Instance players
	var player
	for i in range(global.nb_players):
		player = global.player_scene.instance()
		player.id = i+1
		# Set sprite and position based on player number
		player.char = global.PLAYER_DATA[i].char
		player.set_position(map_to_world(global.PLAYER_DATA[i].tile_pos))
		player_manager.add_child(player)

	# Start music if enabled
	if global.music:
		get_node("AudioStreamPlayer").play()
	# Initialise volume levels as loaded from the config
	get_node("AudioStreamPlayer").set_volume(global.music_volume)
	get_node("Node").set_default_volume(global.sfx_volume)

	# Process input for the "cancel" quit that returns to the main menu
	set_process_input(true)

func _input(event):
	if Input.is_action_pressed("ui_cancel"):
		# Quit to main menu
		get_tree().change_scene_to(global.menu_scene)

### Helpers ###

func map_to_world(map_pos):
	"""Return absolute position of the center of the tile"""
	return tilemap_destr.map_to_world(map_pos) + global.TILE_OFFSET

func world_to_map(world_pos):
	"""Return tilemap position"""
	return tilemap_destr.world_to_map(world_pos)

func tile_center_position(absolute_pos):
	"""Give the absolute coordinates of the center of the nearest tile"""
	return map_to_world(world_to_map(absolute_pos))

func play_sound(sound):
	"""Play the requested sound if sound effects are enabled"""
	if global.sfx:
		get_node("Node").play(sound)

