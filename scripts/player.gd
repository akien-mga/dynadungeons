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

extends KinematicBody2D

### Nodes
var global
var gameover
var level

### Member variables
export var id = 1
export var char = "goblin-brown"
var dead = false
var invincible = false

var active_bombs = []
var collision_exceptions = []

var old_motion = Vector2()
var anim = "down_idle"
var new_anim = ""

### Characteristics
var lives
var speed = 10
var bomb_quota = 3
var bomb_range = 2
var kick = false
var confusion = false
var tmp_powerup = null

### Helper functions

func get_cell_pos():
	return level.world_to_map(self.get_pos())

func set_tmp_powerup(powerup_type):
	# If another temporary powerup is active, disable it
	if (tmp_powerup != null):
		set(tmp_powerup, false)
	# Save the type name for later reference
	tmp_powerup = powerup_type
	# Enable the corresponding variable (same var name as the string content)
	set(tmp_powerup, true)
	# Start the timer that should disable the temporary powerup
	get_node("TimerPowerup").start()

### Actions

func place_bomb():
	var bomb = global.bomb_scene.instance()
	level.bomb_manager.add_child(bomb)
	bomb.set_pos_and_update(level.tile_center_pos(self.get_pos()))
	bomb.player = self
	bomb.bomb_range = self.bomb_range
	for player in level.player_manager.get_children():
		if (player.get_cell_pos() == bomb.get_cell_pos()):
			player.add_collision_exception_with(bomb.get_node("StaticBody2D"))
			player.collision_exceptions.append(bomb)
	active_bombs.append(bomb)
	level.get_node("SamplePlayer").play("bombdrop")

func die():
	set_fixed_process(false)
	get_node("CharSprite").hide()
	get_node("ActionAnimations").play("death")
	level.play_sound("death")
	lives -= 1
	if (lives == 0):
		for bomb in level.bomb_manager.get_children():
			bomb.player = null
		dead = true
		# If there are only two players when self dies, the other player wins
		var players = level.player_manager.get_children()
		if (players.size() == 2):
			var winner
			if (self != players[0]):
				winner = 0
			else:
				winner = 1
			gameover.get_node("Label").set_text("Player " + str(players[winner].id) + " wins!")
			gameover.show()
	else:
		get_node("TimerRespawn").start()

### Process

func process_movement(delta):
	var motion = Vector2(0,0)
	
	if (Input.is_action_pressed(str(id) + "_move_up")):
		motion += Vector2(0,-1)
	if (Input.is_action_pressed(str(id) + "_move_down")):
		motion += Vector2(0,1)
	if (Input.is_action_pressed(str(id) + "_move_left")):
		motion += Vector2(-1,0)
	if (Input.is_action_pressed(str(id) + "_move_right")):
		motion += Vector2(1,0)
	
	if (confusion):
		# Go in the opposite direction since the player is confused
		motion = -motion
	
	motion = motion.normalized()*speed*0.5*global.TILE_SIZE*delta
	move(motion)
	
	# Handle kicking of bombs
	if (kick and is_colliding() and get_collider().get_parent() in level.bomb_manager.get_children()):
		var bomb = get_collider().get_parent()
		# Check whether we are pushing a moving bomb in its current sliding direction
		# FIXME: Use Vector2.angle_to() when it's fixed https://github.com/okamstudio/godot/pull/2260
		if (motion.normalized() != bomb.slide_dir.normalized()):
			bomb.push_dir(bomb.get_cell_pos() - self.get_cell_pos())
	
	# Too many slide attempts provide "jumping" through tiles
	# TODO: Needs investigating as even with one attempt some unusual effects
	# can be seen when going diagonally against walls
	var slide_attempts = 1
	while(is_colliding() and slide_attempts > 0):
		motion = get_collision_normal().slide(motion)
		move(motion)
		slide_attempts -= 1
	
	if (old_motion != motion):
		if (motion == Vector2(0,0)):
			new_anim += "_idle"
		elif abs(motion.x) > 0:
			get_node("CharSprite").set_flip_h(motion.x < 0)
			new_anim = "side"
		elif motion.y > 0:
			new_anim = "down"
		elif motion.y < 0:
			new_anim = "up"
	
	old_motion = motion
	
	if (new_anim != anim):
		anim = new_anim
		get_node("ActionAnimations").play(anim)

func process_actions():
	# Drop a bomb on the player's tile
	if (Input.is_action_pressed(str(id) + "_drop_bomb") and active_bombs.size() < bomb_quota):
		for bomb in collision_exceptions:
			if (bomb.get_cell_pos() == self.get_cell_pos()):
				return
		place_bomb()

func process_explosions():
	for trigger_bomb in level.exploding_bombs:
		for bomb in [ trigger_bomb ] + trigger_bomb.chained_bombs:
			# Kill player if he's standing on the bomb
			if (self.get_cell_pos() == bomb.get_cell_pos()):
				self.die()
				return
			# FIXME: This flame_cells stuff is really getting messy
			for cell_dict in bomb.flame_cells:
				if (self.get_cell_pos() == cell_dict.pos):
					self.die()
					return

func _fixed_process(delta):
	process_movement(delta)
	process_actions()
	if (not invincible):
		process_explosions()
	
	for bomb in collision_exceptions:
		if (self.get_pos().x < (bomb.get_cell_pos().x - 0.5)*global.TILE_SIZE \
			or self.get_pos().x > (bomb.get_cell_pos().x + 1.5)*global.TILE_SIZE \
			or self.get_pos().y < (bomb.get_cell_pos().y - 0.5)*global.TILE_SIZE \
			or self.get_pos().y > (bomb.get_cell_pos().y + 1.5)*global.TILE_SIZE):
			remove_collision_exception_with(bomb.get_node("StaticBody2D"))
			collision_exceptions.erase(bomb)

### Signals

func _on_TimerPowerup_timeout():
	if (tmp_powerup == null):
		print("ERROR: empty tmp_powerup at end of timer")
	
	# Deactivate the current temporary powerup referenced by tmp_powerup
	set(tmp_powerup, false)
	tmp_powerup = null

func _on_TimerRespawn_timeout():
	if (not invincible):
		# Resurrect the player in its original spot as it still has lives
		set_pos(level.map_to_world(global.PLAYER_DATA[id - 1].tile_pos))
		get_node("CharSprite").show()
		set_fixed_process(true)
		level.play_sound("respawn" + str(randi() % 2 + 1))
		# Add collision exceptions with all bombs
		for bomb in level.bomb_manager.get_children():
			add_collision_exception_with(bomb.get_node("StaticBody2D"))
		# This variable makes the player invicible after respawning to prevent spawnkilling
		# The timer is then reused to remove this protection after a while
		invincible = true
		get_node("TimerRespawn").start()
		get_node("StatusAnimations").get_animation("blink").set_loop(true)
		get_node("StatusAnimations").play("blink")
	else:
		# Remove post-respawn protection
		invincible = false
		get_node("StatusAnimations").get_animation("blink").set_loop(false)

func _on_ActionAnimations_finished():
	if (dead):
		# Completely remove this player from the game
		self.queue_free()

### Initialisation

func _ready():
	global = get_node("/root/global")
	gameover = get_node("/root/World/Gameover")
	level = get_node("/root/World/Level")
	get_node("CharSprite").set_sprite_frames(load("res://sprites/" + char + ".xml"))
	lives = global.nb_lives
	
	set_fixed_process(true)

