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

extends Node

# Are we running in networked mode?
var networked = false

# Name for my player
var player_name = "BomberDude"

# Names for remote players in id:name format
var players = {}

# Signals to let lobby GUI know what's going on
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

# Callback from SceneTree
func _player_connected(id):
	# This is not used in this demo, because _connected_ok is called for clients
	# on success and will do the job.
	pass

# Callback from SceneTree
func _player_disconnected(id):
	if get_tree().is_network_server():
		if has_node("/root/World"): # Game is in progress
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
		else: # Game is not in progress
			# If we are the server, send to the new dude all the already registered players
			unregister_player(id)
			for p_id in players:
				# Erase in the server
				rpc_id(p_id, "unregister_player", id)

# Callback from SceneTree, only for clients (not server)
func _connected_ok():
	# Registration of a client beings here, tell everyone that we are here
	rpc("register_player", get_tree().get_network_unique_id(), player_name)
	emit_signal("connection_succeeded")

# Callback from SceneTree, only for clients (not server)
func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	end_game()

# Callback from SceneTree, only for clients (not server)
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

# Lobby management functions

remote func register_player(id, name):
	if get_tree().is_network_server():
		# If we are the server, let everyone know about the new player
		rpc_id(id, "register_player", 1, player_name) # Send myself to new dude
		for p_id in players: # Then, for each remote player
			rpc_id(id, "register_player", p_id, players[p_id]) # Send player to new dude
			rpc_id(p_id, "register_player", id, name) # Send new dude to player # FIXME: Not necessary since register_player was called in all peers already?

	players[id] = name
	emit_signal("player_list_changed")

remote func unregister_player(id):
	players.erase(id)
	emit_signal("player_list_changed")

remote func pre_start_game(player_ids):
	networked = true
	# Change scene
	var world = global.world_scene.instance()
	get_tree().get_root().add_child(world)
	get_node("/root/Menu").hide()
	var level = world.get_node("Level")

	var i = 0
	for p_id in player_ids:
		var player = global.player_scene.instance()
		player.id = i + 1 # For controls
		# Set sprite and position based on player number
		player.char = global.PLAYER_DATA[i].char
		player.set_pos(level.map_to_world(global.PLAYER_DATA[i].tile_pos))
		player.set_name(str(p_id)) # Use unique ID as node name

		if (p_id == get_tree().get_network_unique_id()):
			# If node for this peer id, set master
			player.set_network_mode(NETWORK_MODE_MASTER)
			#player.set_player_name(player_name)
		else:
			# Otherwise set slave
			player.set_network_mode(NETWORK_MODE_SLAVE)
			#player.set_player_name(players[p_id])

		level.player_manager.add_child(player)
		i += 1

	# Set up score
	#world.get_node("score").add_player(get_tree().get_network_unique_id(), player_name)
	#for pn in players:
	#	world.get_node("score").add_player(pn, players[pn])

	if (not get_tree().is_network_server()):
		# Tell server we are ready to start
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())
	elif players.size() == 0:
		post_start_game()

remote func post_start_game():
	get_tree().set_pause(false) # Unpause and unleash the game!

var players_ready = []

remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if (not id in players_ready):
		players_ready.append(id)

	if (players_ready.size() == players.size()):
		for p in players:
			rpc_id(p, "post_start_game")
		post_start_game()

func host_game(port, max_players, name):
	player_name = name
	var host = NetworkedMultiplayerENet.new()
	host.create_server(port, max_players)
	get_tree().set_network_peer(host)

func join_game(ip, port, name):
	player_name = name
	var host = NetworkedMultiplayerENet.new() # FIXME: Should be "peer" as var name?
	host.create_client(ip, port)
	get_tree().set_network_peer(host)

func get_player_list():
	return players.values()

func get_player_name():
	return player_name

func begin_game():
	assert(get_tree().is_network_server())

	var player_ids = [1] + players.keys()
	for p in players:
		rpc_id(p, "pre_start_game", player_ids)

	pre_start_game(player_ids)

func end_game():
	if has_node("/root/World"): # Game is in progress
		get_node("/root/World").queue_free()

	emit_signal("game_ended")
	players.clear()
	get_tree().set_network_peer(null) # End networking

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
