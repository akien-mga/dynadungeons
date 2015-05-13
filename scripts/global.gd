extends Node

# Constants
const TILE_SIZE = 32
const TILE_OFFSET = Vector2(0.5,0.5)*TILE_SIZE
const MAX_BOMBS = 8
const MAX_FLAMERANGE = 8

# Nodes
var level
var map_manager
var player_manager
var bomb_manager
var collectible_manager
var tilemap_destr
var tilemap_indestr

# Scripts
const player_script = preload("res://scripts/player.gd")

func world_to_map(var world_pos):
	return tilemap_destr.world_to_map(world_pos)

func _ready():
	level = get_node("/root").get_node("Level")
	map_manager = level.get_node("MapManager")
	player_manager = level.get_node("PlayerManager")
	bomb_manager = level.get_node("BombManager")
	collectible_manager = level.get_node("CollectibleManager")
	tilemap_destr = map_manager.get_node("Destructible")
	tilemap_indestr = map_manager.get_node("Indestructible")
	
