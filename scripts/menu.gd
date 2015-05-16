extends Control

var global

func new_game():
	var level_scene = load("res://scenes/level.xscn").instance()
	get_node("/root").get_node("MainMenu").queue_free()
	OS.set_window_size(Vector2(960,832))
	get_node("/root").add_child(level_scene)
	global.initialise_level()

func quit():
	get_tree().quit() # Exit the game

func _ready():
	global = get_node("/root/global")
