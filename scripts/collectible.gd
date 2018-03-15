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

extends Area2D

### Variables ###

## Nodes
onready var level = get_node("/root/World/Level")

## Member variables
var effect = "bomb_increase" # Effect of this collectible object
var pickable = true # Can it be picked? Prevents picking multiple times

### Callbacks ###

func _ready():
	# Initalise texture based on the effect
	get_node("Sprite").set_texture(load("res://sprites/pickups/" + effect + ".png"))

func _on_body_enter(body):
	if pickable and body is global.player_script:
		# Apply effect
		if effect == "bomb_increase" and body.bomb_quota < global.MAX_BOMBS:
			body.bomb_quota += 1
		elif effect == "flame_increase" and body.bomb_range < global.MAX_FLAMERANGE:
			body.bomb_range += 1
		elif effect == "speed_increase" and body.speed < global.MAX_SPEED:
			body.speed += 1
		elif effect == "speed_decrease" and body.speed > 0:
			body.speed -= 1
		elif effect == "confusion":
			body.set_tmp_powerup("confusion", 10, "modulate")
		elif effect == "life_increase":
			body.lives += 1
		elif effect == "kick_skill":
			body.kick = true
		get_node("AnimationPlayer").play("pickup")
		level.get_node("Node").play("pickup")

func _on_AnimationPlayer_finished():
	self.queue_free()

### Functions ###

func destroy():
	# Make sure the effect won't be applied several times and play destroy animation
	pickable = false
	get_node("AnimationPlayer").play("destroy")

