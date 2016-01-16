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

### Variables ###

## Nodes
onready var gameover = get_node("/root/World/Gameover")
onready var level = get_node("/root/World/Level")

## Member variables
export var id = 1 # Player ID, used to reference the scene
export var char = "goblin-brown" # Name of the char sprite
var dead = false # Is the player dead for good?

var active_bombs = [] # List of active bombs dropped by this player
var collision_exceptions = [] # List of collision exceptions (typically bomb just dropped)

var old_motion = Vector2() # Previous motion, to check anim changes
var anim = "down_idle" # Current movement animation

# Characteristics
var lives # Current number of lives
var speed = 10 # Current movement speed
var bomb_quota = 3 # Current max number of bombs
var bomb_range = 2 # Current range of bomb explosiosn
var kick = false # Can the play kick bomb away?
var invincible = false # Is the player invincible (typically at respawn)?
var confusion = false # Is the player confused (movement inverted)?
var tmp_powerup = null # Current temporary powerup affecting the player
var tmp_anim = null # Current temporary animation playing, linked to tmp_powerup

### Callbacks ###

func _ready():
	# Initialise character sprite
	get_node("CharSprite").set_sprite_frames(load("res://sprites/" + char + ".tres"))
	lives = global.nb_lives
	
	set_fixed_process(true)

func _fixed_process(delta):
	process_movement(delta)
	process_actions()
	if not invincible:
		process_explosions()
	process_gameover()
	
	# Check if the player is leaving the tile of a bomb in his collision exceptions
	# If so, remove the bomb from the exceptions
	for bomb in collision_exceptions:
		if (self.get_pos().x < (bomb.get_cell_pos().x - 0.5)*global.TILE_SIZE \
				or self.get_pos().x > (bomb.get_cell_pos().x + 1.5)*global.TILE_SIZE \
				or self.get_pos().y < (bomb.get_cell_pos().y - 0.5)*global.TILE_SIZE \
				or self.get_pos().y > (bomb.get_cell_pos().y + 1.5)*global.TILE_SIZE):
			remove_collision_exception_with(bomb.get_node("StaticBody2D"))
			collision_exceptions.erase(bomb)

### Functions ###

## Process

func process_movement(delta):
	"""Process movement input and act accordingly"""
	var motion = Vector2(0, 0)
	
	if Input.is_action_pressed(str(id) + "_move_up"):
		motion += Vector2(0, -1)
	if Input.is_action_pressed(str(id) + "_move_down"):
		motion += Vector2(0, 1)
	if Input.is_action_pressed(str(id) + "_move_left"):
		motion += Vector2(-1, 0)
	if Input.is_action_pressed(str(id) + "_move_right"):
		motion += Vector2(1, 0)
	
	if confusion:
		# Go in the opposite direction since the player is confused
		motion = -motion
	
	# Normalise motion vector and apply speed modifiers to get motion in px
	motion = motion.normalized()*speed*0.5*global.TILE_SIZE*delta
	# Actually move the player
	move(motion)
	
	# Handle kicking of bombs
	if kick and is_colliding() and get_collider().get_parent() in level.bomb_manager.get_children():
		var bomb = get_collider().get_parent()
		# Check whether we are pushing a moving bomb in its current sliding direction
		# FIXME: Use Vector2.angle_to() when it's fixed https://github.com/okamstudio/godot/pull/2260
		if motion.normalized() != bomb.slide_dir.normalized():
			bomb.push_dir(bomb.get_cell_pos() - self.get_cell_pos())
	
	# If the previous movement generated a collision, try to slide (e.g. along an edge)
	# Too many slide attempts provide "jumping" through tiles
	# TODO: Needs investigating as even with one attempt some unusual effects
	# can be seen when going diagonally against walls
	var slide_attempts = 1
	while is_colliding() and slide_attempts > 0:
		motion = get_collision_normal().slide(motion)
		move(motion)
		slide_attempts -= 1
	
	# If the motion doesn't change, don't try to change the animation
	if old_motion == motion:
		return
	
	old_motion = motion
	if motion == Vector2(0, 0):
		anim += "_idle"
	elif abs(motion.x) > 0:
		get_node("CharSprite").set_flip_h(motion.x < 0)
		anim = "side"
	elif motion.y > 0:
		anim = "down"
	elif motion.y < 0:
		anim = "up"
	
	get_node("ActionAnimations").play(anim)

func process_actions():
	"""Process actions input and act accordingly.
	Currently the only non-movement related action is dropping a bomb.
	"""
	# Drop a bomb on the player's tile
	if Input.is_action_pressed(str(id) + "_drop_bomb") and active_bombs.size() < bomb_quota:
		# Check for potential bombs already being on the same tile.
		# It should only happen if the player or an enemy already dropped a bomb on the tile,
		# so it would be in the player's collision_exceptions.
		for bomb in collision_exceptions:
			if bomb.get_cell_pos() == self.get_cell_pos():
				return
		place_bomb()

func process_explosions():
	"""Process all current bomb explosions to check if one of them is killing the player"""
	for trigger_bomb in level.exploding_bombs:
		for bomb in [trigger_bomb] + trigger_bomb.chained_bombs:
			# Kill player if he's standing on an exploding bomb
			if self.get_cell_pos() == bomb.get_cell_pos():
				self.die()
				return
			# FIXME: This flame_cells stuff is really getting messy
			# Check all cells currently "in flames" due to the bomb's explosion
			for cell_dict in bomb.flame_cells:
				if self.get_cell_pos() == cell_dict.pos:
					self.die()
					return

func process_gameover():
	if gameover.is_visible() and Input.is_action_pressed("ui_accept"):
		get_tree().change_scene_to(global.menu_scene)

## Actions

func place_bomb():
	"""Instance a bomb and place it on the tile where the player stands.
	Bombs are added as children to the bomb manager.
	"""
	var bomb = global.bomb_scene.instance()
	level.bomb_manager.add_child(bomb)
	# Define position and update the bomb's discrete tilemap pos member var
	bomb.set_pos_and_update(level.tile_center_pos(self.get_pos()))
	bomb.player = self
	bomb.bomb_range = self.bomb_range
	# Add a collision exception for any player currently standing on the tile
	for player in level.player_manager.get_children():
		if player.get_cell_pos() == bomb.get_cell_pos():
			player.add_collision_exception_with(bomb.get_node("StaticBody2D"))
			player.collision_exceptions.append(bomb)
	# List bomb as an active bomb of its dropper
	active_bombs.append(bomb)
	# Play bomb drop sound effect
	level.get_node("SamplePlayer").play("bombdrop")

func die():
	"""Handle the death of the player. If the player has more than one lives,
	a timer is started for respawn. Else, the player is marked as "dead" for good.
	"""
	# Stop processing input and possible explosions, the player is dead
	set_fixed_process(false)
	# Play death animation and remove a life
	get_node("CharSprite").hide()
	get_node("ActionAnimations").play("death")
	level.play_sound("death")
	lives -= 1
	if lives == 0:
		# The player is dead for good, make its bombs orphans since the scene will be freed
		for bomb in level.bomb_manager.get_children():
			bomb.player = null
		dead = true
		# If there are only two players when self dies, the other player wins
		var players = level.player_manager.get_children()
		if players.size() == 2:
			var winner
			if self != players[0]:
				winner = 0
			else:
				winner = 1
			# Show gameover screen
			gameover.get_node("Label").set_text("Player " + str(players[winner].id) + " wins!")
			gameover.show()
	else:
		# The player still has lives, start timer for respawn
		get_node("TimerRespawn").start()

## Signals

func _on_TimerPowerup_timeout():
	if tmp_powerup == null:
		print("ERROR: empty tmp_powerup at end of timer")
		return
	
	# Deactivate the current temprary powerup animation if any
	if tmp_anim != null:
		get_node("StatusAnimations").get_animation(tmp_anim).set_loop(false)
		tmp_anim = null
	# Deactivate the current temporary powerup referenced by tmp_powerup
	set(tmp_powerup, false)
	tmp_powerup = null

func _on_TimerRespawn_timeout():
	"""Handle timeout of the respawn timer to resurrect player in its original
	spot and make it temporarily invincible.
	"""
	# Resurrect the player in its original spot as it still has lives
	set_pos(level.map_to_world(global.PLAYER_DATA[id - 1].tile_pos))
	get_node("CharSprite").show()
	# Start processing input again
	set_fixed_process(true)
	# Play one of two respawn sound effects
	level.play_sound("respawn" + str(randi() % 2 + 1))
	# Add collision exceptions with all bombs to avoid blocking the player
	# if an enemy lined up a range of bombs at the spawn point
	for bomb in level.bomb_manager.get_children():
		add_collision_exception_with(bomb.get_node("StaticBody2D"))
	# Make the player invicible after respawning to prevent spawnkilling
	set_tmp_powerup("invincible", 3, "blink")

func _on_ActionAnimations_finished():
	if dead:
		# Completely remove this player from the game
		self.queue_free()

### Helpers ###

func get_cell_pos():
	"""Return tilemap position"""
	return level.world_to_map(self.get_pos())

func set_tmp_powerup(powerup_type, duration = 5, status_anim = null):
	"""Define a temporary powerup that affects the player, start corresponding timer
	with the specified duration and specified animation if any.
	"""
	# If another temporary powerup is active, disable it
	if tmp_powerup != null:
		set(tmp_powerup, false)
	# Save the type name for later reference
	tmp_powerup = powerup_type
	# Enable the corresponding variable (same var name as the string content)
	set(tmp_powerup, true)
	# Start the timer that should disable the temporary powerup
	get_node("TimerPowerup").set_wait_time(duration)
	get_node("TimerPowerup").start()
	
	# If a status animation is given, stop previous animation and start playing new one
	if status_anim != null and status_anim != tmp_anim:
		if tmp_anim != null:
			# Force stopping previous animation and reset it (to e.g. remove modulation)
			get_node("StatusAnimations").stop(true)
		get_node("StatusAnimations").get_animation(status_anim).set_loop(true)
		get_node("StatusAnimations").play(status_anim)
		tmp_anim = status_anim
