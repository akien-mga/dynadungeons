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
	# Initialise settings widgets
	get_node("Settings/Fullscreen").set_pressed(global.fullscreen)
	get_node("Settings/Music").set_pressed(global.music)
	get_node("Settings/MusicVolume").set_value(global.music_volume)
	get_node("Settings/SFX").set_pressed(global.sfx)
	get_node("Settings/SFXVolume").set_value(global.sfx_volume)

	get_node("Settings/NbPlayers/Slider").set_value(global.nb_players)
	get_node("Settings/NbPlayers/Label").set_text("Players: " + str(global.nb_players))

	get_node("Settings/NbLives/Slider").set_value(global.nb_lives)
	get_node("Settings/NbLives/Label").set_text("Lives: " + str(global.nb_lives))

	# Set initial control focus on the "Local Game" button
	get_node("MainMenu/LocalGame").grab_focus()

### Functions ###

## Windows and scenes

func new_game():
	get_tree().change_scene_to(global.world_scene)

func quit():
	get_tree().quit()

func goto_screen(screen):
	# The sign is negative because the whole root is translated in the opposite direction
	# to the actual position that we want to have on focus (i.e. at 0,0)
	set_pos(-get_node(screen).get_pos())

func goto_mainmenu():
	goto_screen("MainMenu")
	get_node("MainMenu/LocalGame").grab_focus()

func goto_network():
	goto_screen("Network")

func goto_lobby():
	goto_screen("Lobby")

func goto_settings():
	goto_screen("Settings")

func goto_controls():
	goto_screen("Controls")

## Settings

# Display
func settings_toggle_fullscreen(pressed):
	global.fullscreen = pressed
	OS.set_window_fullscreen(global.fullscreen)
	global.save_to_config("display", "fullscreen", pressed)

# Audio
func settings_toggle_music(pressed):
	global.music = pressed
	global.save_to_config("audio", "music", pressed)

func settings_set_music_volume(value):
	global.music_volume = value
	global.save_to_config("audio", "music_volume", value)

func settings_toggle_sfx(pressed):
	global.sfx = pressed
	global.save_to_config("audio", "sfx", pressed)

func settings_set_sfx_volume(value):
	global.sfx_volume = value
	global.save_to_config("audio", "sfx_volume", value)

# Gameplay
func settings_set_players(value):
	global.nb_players = int(value)
	get_node("Settings/NbPlayers/Label").set_text("Players: " + str(value))
	global.save_to_config("gameplay", "nb_players", int(value))

func settings_set_lives(value):
	global.nb_lives = int(value)
	get_node("Settings/NbLives/Label").set_text("Lives: " + str(value))
	global.save_to_config("gameplay", "nb_lives", int(value))
