extends Control

# Nodes
var global

# Constants
var inputmap_actions = [ "move_up", "move_down", "move_left", "move_right", "drop_bomb" ]

# Member variables
var player_id
var action
var button
var key_pressed

func wait_for_input(local_player_id, local_action):
	player_id = local_player_id
	action = local_action
	button = get_node("Player" + str(player_id)).get_node(action)
	get_node("ContextHelp").set_text("Press a key, then press Escape to confirm.")
	set_process_input(true)

func change_key(player_id, action, key_pressed):
	var id_action = str(player_id) + "_" + str(action)
	InputMap.erase_action(id_action)
	InputMap.add_action(id_action)
	InputMap.action_add_event(id_action, key_pressed)

func _input(event):
	if (event.is_action("ui_cancel")):
		set_process_input(false)
		if (key_pressed != null):
			change_key(player_id, action, key_pressed)
		get_node("ContextHelp").set_text("Click a key binding to reassign it.")
	elif (event.type == InputEvent.KEY):
		key_pressed = event
		button.set_text(OS.get_scancode_string(event.scancode))

func _ready():
	global = get_node("/root/global")
	
	for id in range(1,5):
		for action in inputmap_actions:
			var button = get_node("Player" + str(id)).get_node(action)
			button.connect("pressed", self, "wait_for_input", [ id, action ])
			button.set_text("~")
