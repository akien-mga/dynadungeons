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

# Nodes
var level
var map_manager
var player_manager
var bomb_manager
var collectible_manager
var tilemap_destr
var tilemap_indestr

# Scenes
const level_scene = preload("res://scenes/level.xscn")
const player_scene = preload("res://scenes/player.xscn")
const bomb_scene = preload("res://scenes/bomb.xscn")
const collectible_scene = preload("res://scenes/collectible.xscn")

# Scripts
const player_script = preload("res://scripts/player.gd")

# Parameters
var nb_players = 2
var nb_lives = 1
var collectibles = { 'types': [ "bomb_increase", "flame_increase", "speed_increase" ],
                     'freq': [ 1, 1, 0.7 ] }

# Variables
var exploding_bombs = []


func map_to_world(var map_pos):
	return tilemap_destr.map_to_world(map_pos) + TILE_OFFSET

func world_to_map(var world_pos):
	return tilemap_destr.world_to_map(world_pos)

func initialise_level():
	level = get_node("/root").get_node("Level")
	map_manager = level.get_node("MapManager")
	player_manager = level.get_node("PlayerManager")
	bomb_manager = level.get_node("BombManager")
	collectible_manager = level.get_node("CollectibleManager")
	tilemap_destr = map_manager.get_node("Destructible")
	tilemap_indestr = map_manager.get_node("Indestructible")

func _ready():
	randomize()
