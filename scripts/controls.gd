extends Control

# Nodes
var global

# Member variables
var player_id
var action
var button

func wait_for_input(local_player_id, local_action):
	player_id = local_player_id
	action = local_action
	button = get_node("Player" + str(player_id)).get_node(action)
	get_node("ContextHelp").set_text("Press a key to assign to the '" + action + "' action.")
	set_process_input(true)

func change_key(player_id, action, event):
	var id_action = str(player_id) + "_" + str(action)
	for old_event in InputMap.get_action_list(id_action):
		InputMap.action_erase_event(id_action, old_event)
	InputMap.action_add_event(id_action, event)
	global.save_to_config("input", id_action, OS.get_scancode_string(event.scancode))

func _input(event):
	if (event.type == InputEvent.KEY):
		set_process_input(false)
		get_node("ContextHelp").set_text("Click a key binding to reassign it.")
		if (not event.is_action("ui_cancel")):
			button.set_text(OS.get_scancode_string(event.scancode))
			change_key(player_id, action, event)

func _ready():
	global = get_node("/root/global")
	
	for id in range(1,5):
		for action in global.inputmap_actions:
			var button = get_node("Player" + str(id)).get_node(action)
			button.connect("pressed", self, "wait_for_input", [ id, action ])
			button.set_text(OS.get_scancode_string(InputMap.get_action_list(str(id) + "_" + action)[0].scancode))
