extends Node2D

# Nodes
var global
var map_manager
var player_manager
var bomb_manager
var collectible_manager
var tilemap_destr
var tilemap_indestr

# Variables
var exploding_bombs = []

func map_to_world(var map_pos):
	return tilemap_destr.map_to_world(map_pos) + global.TILE_OFFSET

func world_to_map(var world_pos):
	return tilemap_destr.world_to_map(world_pos)

func _ready():
	global = get_node("/root/global")
	map_manager = self.get_node("MapManager")
	player_manager = self.get_node("PlayerManager")
	bomb_manager = self.get_node("BombManager")
	collectible_manager = self.get_node("CollectibleManager")
	tilemap_destr = map_manager.get_node("Destructible")
	tilemap_indestr = map_manager.get_node("Indestructible")
