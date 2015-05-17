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
const level_scene = preload("res://scenes/level.xscn")
const player_scene = preload("res://scenes/player.xscn")
const bomb_scene = preload("res://scenes/bomb.xscn")
const collectible_scene = preload("res://scenes/collectible.xscn")

# Scripts
const player_script = preload("res://scripts/player.gd")

# Parameters
var nb_players = 2
var nb_lives = 1
var collectibles = { 'types': [ "bomb_increase", "flame_increase", "speed_increase", "life_increase" ],
                     'freq': [ 100, 100, 70, 5*nb_lives ] }

func _ready():
	randomize()
	
	collectibles.sum_freq = 0
	for freq in collectibles.freq:
		collectibles.sum_freq += freq
