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

extends Control

### Variables ###

## Member variables
var player_id
var action
var button

### Callbacks ###

func _ready():
	# Add signals based on player ID and action name for each key mapping button
	for id in range(1, 5):
		for action in global.INPUT_ACTIONS:
			var button = get_node("Player" + str(id)).get_node(action)
			button.connect("pressed", self, "wait_for_input", [id, action])
			# Initialise button text based on the current InputMap
			button.set_text(OS.get_scancode_string(InputMap.get_action_list(str(id) + "_" + action)[0].scancode))

func _input(event):
	if event.type == InputEvent.KEY:
		# Got a valid input, stop polling and reinitialise context help
		set_process_input(false)
		get_node("ContextHelp").set_text("Click a key binding to reassign it.")
		# Unless the input is a cancel key, display the typed key and change the binding
		if not event.is_action("ui_cancel"):
			button.set_text(OS.get_scancode_string(event.scancode))
			change_key(player_id, action, event)

### Functions ###

## Keybindings management

func wait_for_input(local_player_id, local_action):
	"""Waits for a user input to assign to the action corresponding to the pressed button
	This is done by activating input polling and processing it in _input
	"""
	# Save the parameters of the binding being remapped for use in _input
	player_id = local_player_id
	action = local_action
	button = get_node("Player" + str(player_id)).get_node(action)
	get_node("ContextHelp").set_text("Press a key to assign to the '" + action + "' action.")
	# Start polling the user input
	set_process_input(true)

func change_key(player_id, action, event):
	"""Do the actual key remapping in the InputMap, and save it in the config"""
	var id_action = str(player_id) + "_" + str(action)
	# Clean all previous bindings
	for old_event in InputMap.get_action_list(id_action):
		InputMap.action_erase_event(id_action, old_event)
	# Bind the new event to the chosen action
	InputMap.action_add_event(id_action, event)
	# Save the human-readable string in the config file
	global.save_to_config("input", id_action, OS.get_scancode_string(event.scancode))
