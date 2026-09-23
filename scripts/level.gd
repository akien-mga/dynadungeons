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
@onready var map_manager = get_node("MapManager")
@onready var player_manager = get_node("PlayerManager")
@onready var bomb_manager = get_node("BombManager")
@onready var collectible_manager = get_node("CollectibleManager")
@onready var tilemap_destr = map_manager.get_node("Destructible")
@onready var tilemap_indestr = map_manager.get_node("Indestructible")

## Member variables
var exploding_bombs = [] # Array of bombs that are currently exploding

### Callbacks ###

func _ready():
	# Instance players
	var player
	for i in range(global.nb_players):
		player = global.player_scene.instantiate()
		player.id = i+1
		# Set sprite and position based on player number
		player.charname = global.PLAYER_DATA[i].charname
		player.set_position(map_to_local(global.PLAYER_DATA[i].tile_pos))
		player_manager.add_child(player)

	# Start music if enabled
	if global.music:
		get_node("MusicPlayer").play()
	# Initialise volume levels as loaded from the config
	# FIXME: Disabled during 2 to 3 conversion
	#get_node("MusicPlayer").set_volume(global.music_volume)
	#get_node("SamplePlayer").set_default_volume(global.sfx_volume)

func _input(_event):
	if Input.is_action_pressed("ui_cancel"):
		# Quit to main menu
		get_tree().change_scene_to_packed(global.menu_scene)

### Helpers ###

func map_to_local(map_pos):
	"""Return absolute position of the center of the tile"""
	# Godot 3's map_to_world returned the cell's top left corner, so TILE_OFFSET was added to
	# reach the centre. Godot 4's map_to_local already returns the centre; adding it again put
	# every player, bomb and flame half a tile down and to the right.
	return tilemap_destr.map_to_local(Vector2i(map_pos))

func local_to_map(world_pos):
	"""Return tilemap position"""
	# Godot 3's world_to_map returned a Vector2, and the game does arithmetic on cell
	# coordinates against Vector2 direction vectors. Godot 4 returns Vector2i, which cannot be
	# added to a Vector2 at all - it aborted start_animation halfway, so bombs never exploded
	# and never cleaned themselves up, while every static check still passed.
	return Vector2(tilemap_destr.local_to_map(world_pos))

func tile_center_position(absolute_pos):
	"""Give the absolute coordinates of the center of the nearest tile"""
	return map_to_local(local_to_map(absolute_pos))

func set_tile(tilemap, pos, tile_id, xflip = false, yflip = false, transpose = false):
	"""Godot 3's TileMap.set_cell(x, y, id, xflip, yflip, transpose).

	Godot 4 addresses a cell as (source, atlas coords, alternative). This tileset gives every
	Godot 3 tile id its own source with a single tile at (0, 0), so the id carries over unchanged
	- which matters, because the game does arithmetic on tile ids. The flips are the alternative.
	"""
	var alt = 0
	if xflip:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if yflip:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if transpose:
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if tile_id < 0:
		tilemap.set_cell(0, Vector2i(pos), -1)
	else:
		tilemap.set_cell(0, Vector2i(pos), tile_id, Vector2i(0, 0), alt)

func get_tile(tilemap, pos):
	"""Godot 3's TileMap.get_cell(x, y), including its -1 for an empty cell."""
	return tilemap.get_cell_source_id(0, Vector2i(pos))
