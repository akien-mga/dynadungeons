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

### Callbacks ###

func _ready():
	# Initalize callbacks on gamestate signals
	gamestate.connect("connection_failed", self, "_on_connection_failed")
	gamestate.connect("connection_succeeded", self, "_on_connection_succeeded")
	gamestate.connect("player_list_changed", self, "refresh_lobby")
	gamestate.connect("game_ended", self, "_on_game_ended")
	gamestate.connect("game_error", self, "_on_game_error")

func _on_host_pressed():
	var name = get_node("Name").get_text()
	if name == "":
		get_node("ErrorLabel").set_text("Invalid name!")
		return

	var port = get_node("Server/Port").get_text()
	if not port.is_valid_integer():
		get_node("ErrorLabel").set_text("Invalid port!")
		return

	var max_players = get_node("Server/Players").get_text()
	if not max_players.is_valid_integer() or int(max_players) < 1 or int(max_players) > 4:
		get_node("ErrorLabel").set_text("Invalid number of players!")
		return

	get_node("ErrorLabel").set_text("")
	gamestate.host_game(int(port), int(max_players), name)

	refresh_lobby()
	get_parent().goto_screen("LobbyPlayers")

func _on_join_pressed():
	var name = get_node("Name").get_text()
	if name == "":
		get_node("ErrorLabel").set_text("Invalid name!")
		return

	var port = get_node("Client/Port").get_text()
	if not port.is_valid_integer():
		get_node("ErrorLabel").set_text("Invalid port!")
		return

	var ip = get_node("Client/IP").get_text()
	if not ip.is_valid_ip_address():
		get_node("ErrorLabel").set_text("Invalid IPv4 address!")
		return

	get_node("ErrorLabel").set_text("")

	gamestate.join_game(ip, int(port), name)

func _on_connection_succeeded():
	get_parent().goto_screen("LobbyPlayers")

func _on_connection_failed():
	get_node("ErrorLabel").set_text("Connection failed.")

func _on_start_pressed():
	gamestate.begin_game()

func _on_game_ended():
	# TODO
	print("GAME ENDED")
	pass
	#get_node("connect").show()
	#get_node("players").hide()
	#get_node("connect/host").set_disabled(false)
	#get_node("connect/join").set_disabled(false)

func _on_game_error(errtxt):
	print("GAME ERROR: ", errtxt)
	#get_node("error").set_text(errtxt)
	#get_node("error").popup_centered_minsize()
	pass

func refresh_lobby():
	var players = gamestate.get_player_list()
	players.sort()
	get_node("../LobbyPlayers/PlayersList").clear()
	get_node("../LobbyPlayers/PlayersList").add_item(gamestate.get_player_name() + " (You)")
	for p in players:
		get_node("../LobbyPlayers/PlayersList").add_item(p)

	get_node("../LobbyPlayers/Start").set_disabled(not get_tree().is_network_server())

func _on_leave_pressed():
	gamestate.end_game()
	get_parent().goto_lobby()
