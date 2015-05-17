extends Control

# Nodes
var global

func new_game():
	var level = global.level_scene.instance()
	get_node("/root").get_node("Menu").queue_free()
	get_node("/root").add_child(level)
	OS.set_window_size(Vector2(960,832))
	global.initialise_level()
	
	var player
	for i in range(global.nb_players):
		player = global.player_scene.instance()
		player.id = i+1
		player.char = global.PLAYER_DATA[i].char
		player.set_pos(global.map_to_world(global.PLAYER_DATA[i].tile_pos))
		global.player_manager.add_child(player)

func quit():
	get_tree().quit()

func goto_screen(screen):
	set_pos(-get_node(screen).get_pos())

func goto_mainmenu():
	goto_screen("MainMenu")

func goto_settings():
	goto_screen("Settings")

func goto_controls():
	goto_screen("Controls")

func settings_set_players(value):
	global.nb_players = value
	get_node("Settings/NbPlayers/Label").set_text("Players: " + str(value))

func settings_set_lives(value):
	global.nb_lives = value
	get_node("Settings/NbLives/Label").set_text("Lives: " + str(value))

func _ready():
	global = get_node("/root/global")
	
	# Initialisations
	get_node("Settings/NbPlayers/Slider").set_value(global.nb_players)
	get_node("Settings/NbPlayers/Label").set_text("Players: " + str(global.nb_players))
	
	get_node("Settings/NbLives/Slider").set_value(global.nb_lives)
	get_node("Settings/NbLives/Label").set_text("Lives: " + str(global.nb_lives))
