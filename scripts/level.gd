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

func _input(event):
	if (Input.is_action_pressed("ui_cancel")):
		# Quit to main menu
		get_tree().change_scene_to(global.menu_scene)

func _ready():
	# Definitions
	global = get_node("/root/global")
	map_manager = self.get_node("MapManager")
	player_manager = self.get_node("PlayerManager")
	bomb_manager = self.get_node("BombManager")
	collectible_manager = self.get_node("CollectibleManager")
	tilemap_destr = map_manager.get_node("Destructible")
	tilemap_indestr = map_manager.get_node("Indestructible")
	
	# Instance players
	var player
	for i in range(global.nb_players):
		player = global.player_scene.instance()
		player.id = i+1
		player.char = global.PLAYER_DATA[i].char
		player.set_pos(map_to_world(global.PLAYER_DATA[i].tile_pos))
		player_manager.add_child(player)
	
	# Start music if enabled
	if (global.music):
		get_node("MusicManager").play()
	
	set_process_input(true)
